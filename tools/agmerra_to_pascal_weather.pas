{
  agmerra_to_pascal_weather - Convert NASA GISS AgMERRA NetCDF4 data to
  CASAS Pascal weather text files.

  FPC port of tools/agmerra_to_pascal_weather.py. Links against libnetcdf
  (install via: brew install netcdf).

  Build:
    fpc -Mdelphi \
        -Fi/opt/homebrew/include \
        -Fl/opt/homebrew/lib \
        -k-L/opt/homebrew/lib -k-lnetcdf \
        agmerra_to_pascal_weather.pas

  Usage:
    ./agmerra_to_pascal_weather \
        --points-file ../casas-gis/casas_gis_old/testfiles/africa_Plants_14Jan23_Avg.txt \
        --start-year 1980 --end-year 2010 \
        --cache-dir ../data/agmerra-cache \
        --out-dir ../data/agmerra-pascal-weather-africa-1980-2010

  Requires libnetcdf to be installed. On macOS:  brew install netcdf
  On Debian/Ubuntu:  apt install libnetcdf-dev
}
program agmerra_to_pascal_weather;

{$mode delphi}
{$H+}

uses
  SysUtils, Classes, Math;

{ ---------- NetCDF C library bindings ---------- }

const
  {$IFDEF DARWIN}
  NETCDF_LIB = 'libnetcdf.dylib';
  {$ELSE}
  NETCDF_LIB = 'libnetcdf.so';
  {$ENDIF}

  NC_NOWRITE = 0;
  NC_NOERR   = 0;

type
  size_t = PtrUInt;
  psize_t = ^size_t;

function nc_open(path: PAnsiChar; mode: Integer; var ncid: Integer): Integer; cdecl; external NETCDF_LIB;
function nc_close(ncid: Integer): Integer; cdecl; external NETCDF_LIB;
function nc_inq_dimid(ncid: Integer; name: PAnsiChar; var dimid: Integer): Integer; cdecl; external NETCDF_LIB;
function nc_inq_dimlen(ncid: Integer; dimid: Integer; var len: size_t): Integer; cdecl; external NETCDF_LIB;
function nc_inq_varid(ncid: Integer; name: PAnsiChar; var varid: Integer): Integer; cdecl; external NETCDF_LIB;
function nc_get_var_float(ncid: Integer; varid: Integer; ip: PSingle): Integer; cdecl; external NETCDF_LIB;
function nc_get_vara_float(ncid: Integer; varid: Integer; startp: psize_t; countp: psize_t; ip: PSingle): Integer; cdecl; external NETCDF_LIB;
function nc_strerror(ncerr: Integer): PAnsiChar; cdecl; external NETCDF_LIB;

procedure NCCheck(rc: Integer; const context: string);
begin
  if rc <> NC_NOERR then
  begin
    WriteLn(StdErr, 'NetCDF error in ', context, ': ', nc_strerror(rc));
    Halt(1);
  end;
end;

{ ---------- Types ---------- }

type
  TWeatherPoint = record
    OutputName: string;
    Lon, Lat: Double;
  end;

  TIndexedPoint = record
    Point: TWeatherPoint;
    LatIdx, LonIdx: Integer;
  end;

const
  NUM_VARS = 6;
  VAR_NAMES: array[0..NUM_VARS-1] of string =
    ('tmax', 'tmin', 'srad', 'prate', 'rhstmax', 'wndspd');
  MJ_M2_DAY_TO_W_M2 = 1000000.0 / 86400.0;

var
  Points: array of TWeatherPoint;
  Indexed: array of TIndexedPoint;
  NumPoints: Integer;

  OptPointsFile: string;
  OptStartYear, OptEndYear: Integer;
  OptCacheDir: string;
  OptOutDir: string;
  OptLimit: Integer;
  OptOverwrite: Boolean;
  OptResume: Boolean;
  OptDownloadOnly: Boolean;

{ ---------- Utility ---------- }

function ExtractFileBaseName(const path: string): string;
var
  fname: string;
  p: Integer;
begin
  fname := ExtractFileName(path);
  p := Pos('.', fname);
  if p > 0 then
    Result := Copy(fname, 1, p - 1)
  else
    Result := fname;
end;

function DaysInYear(year: Integer): Integer;
begin
  if IsLeapYear(year) then
    Result := 366
  else
    Result := 365;
end;

function DayOfYear(d: TDateTime): Integer;
var
  y, m, day: Word;
begin
  DecodeDate(d, y, m, day);
  Result := Trunc(d - EncodeDate(y, 1, 1)) + 1;
end;

{ ---------- Points file parsing ---------- }

function SplitTSVLine(const line: string; delimiter: Char): TStringList;
begin
  Result := TStringList.Create;
  Result.Delimiter := delimiter;
  Result.StrictDelimiter := True;
  Result.DelimitedText := line;
end;

procedure ParsePointsFile(const filename: string);
var
  f: TextFile;
  line: string;
  fields: TStringList;
  headers: TStringList;
  wxIdx, lonIdx, latIdx, nameIdx: Integer;
  i: Integer;
  delim: Char;
  rawName: string;
  p: Integer;
  count: Integer;
begin
  AssignFile(f, filename);
  Reset(f);

  ReadLn(f, line);
  if Pos(#9, line) > 0 then
    delim := #9
  else
    delim := ',';

  headers := SplitTSVLine(line, delim);
  try
    wxIdx := headers.IndexOf('WxFile');
    lonIdx := headers.IndexOf('Long');
    latIdx := headers.IndexOf('Lat');
    nameIdx := headers.IndexOf('output_name');

    if (wxIdx < 0) and (nameIdx < 0) then
    begin
      WriteLn(StdErr, 'Points file must have WxFile or output_name column');
      Halt(1);
    end;
    if wxIdx >= 0 then
    begin
      if lonIdx < 0 then lonIdx := headers.IndexOf('lon');
      if latIdx < 0 then latIdx := headers.IndexOf('lat');
    end
    else
    begin
      lonIdx := headers.IndexOf('lon');
      latIdx := headers.IndexOf('lat');
    end;
  finally
    headers.Free;
  end;

  count := 0;
  SetLength(Points, 1024);
  while not Eof(f) do
  begin
    ReadLn(f, line);
    if Trim(line) = '' then Continue;
    fields := SplitTSVLine(line, delim);
    try
      if count >= Length(Points) then
        SetLength(Points, Length(Points) * 2);

      if wxIdx >= 0 then
      begin
        rawName := fields[wxIdx];
        rawName := StringReplace(rawName, '\', '/', [rfReplaceAll]);
        p := LastDelimiter('/', rawName);
        if p > 0 then
          rawName := Copy(rawName, p + 1, MaxInt);
        Points[count].OutputName := rawName;
        Points[count].Lon := StrToFloat(fields[lonIdx]);
        Points[count].Lat := StrToFloat(fields[latIdx]);
      end
      else
      begin
        Points[count].OutputName := fields[nameIdx];
        Points[count].Lon := StrToFloat(fields[lonIdx]);
        Points[count].Lat := StrToFloat(fields[latIdx]);
      end;
      Inc(count);
    finally
      fields.Free;
    end;
  end;
  CloseFile(f);

  SetLength(Points, count);
  NumPoints := count;

  { Deduplicate by output name }
  // Points from legacy GIS files can have duplicates; keep first occurrence
  // We use a simple O(n) approach since the file is sorted
  i := 1;
  count := 1;
  while i < NumPoints do
  begin
    if Points[i].OutputName <> Points[i-1].OutputName then
    begin
      if count <> i then
        Points[count] := Points[i];
      Inc(count);
    end;
    Inc(i);
  end;
  if NumPoints > 0 then
  begin
    SetLength(Points, count);
    NumPoints := count;
  end;
end;

{ ---------- NetCDF helpers ---------- }

function AgMERRAPath(const cacheDir: string; year: Integer; const varName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(cacheDir) +
            Format('AgMERRA_%d_%s.nc4', [year, varName]);
end;

procedure DownloadFile(const url, dest: string);
var
  cmd: string;
  rc: Integer;
begin
  { Use curl which is available on macOS and most Linux }
  cmd := Format('curl -sS -f -L -o "%s" "%s"', [dest, url]);
  rc := ExecuteProcess('/bin/sh', '-c ' + cmd);
  if rc <> 0 then
  begin
    if FileExists(dest) then
      DeleteFile(dest);
    raise Exception.CreateFmt('Download failed (exit %d): %s', [rc, url]);
  end;
end;

function EnsureAgMERRAFile(const cacheDir: string; year: Integer; const varName: string; retries: Integer = 3): string;
var
  path, url: string;
  ncid, attempt, rc: Integer;
begin
  ForceDirectories(cacheDir);
  path := AgMERRAPath(cacheDir, year, varName);
  Result := path;

  if FileExists(path) then
  begin
    rc := nc_open(PAnsiChar(AnsiString(path)), NC_NOWRITE, ncid);
    if rc = NC_NOERR then
    begin
      nc_close(ncid);
      Exit;
    end;
    WriteLn('Removing corrupt/incomplete ', ExtractFileName(path));
    DeleteFile(path);
  end;

  url := Format('https://data.giss.nasa.gov/impacts/agmipcf/agmerra/AgMERRA_%d_%s.nc4',
                [year, varName]);

  for attempt := 1 to retries do
  begin
    try
      if attempt > 1 then
        Write(Format('Downloading %s (attempt %d)...', [url, attempt]))
      else
        Write(Format('Downloading %s...', [url]));
      Flush(Output);
      DownloadFile(url, path);
      WriteLn(' done');
      Exit;
    except
      on E: Exception do
      begin
        if FileExists(path) then
          DeleteFile(path);
        if attempt = retries then
          raise;
        WriteLn(Format(' failed: %s; retrying...', [E.Message]));
      end;
    end;
  end;
end;

{ ---------- Grid reading ---------- }

type
  TNCDataset = record
    NCID: Integer;
    VarIDs: array[0..NUM_VARS-1] of Integer;
    NLat, NLon, NTime: Integer;
  end;

function OpenYear(const cacheDir: string; year: Integer): TNCDataset;
var
  path: string;
  dimid: Integer;
  dimlen: size_t;
  i: Integer;
begin
  { Open first variable file to get dimensions }
  path := EnsureAgMERRAFile(cacheDir, year, VAR_NAMES[0]);
  NCCheck(nc_open(PAnsiChar(AnsiString(path)), NC_NOWRITE, Result.NCID), 'nc_open ' + path);

  NCCheck(nc_inq_dimid(Result.NCID, 'latitude', dimid), 'inq latitude dim');
  NCCheck(nc_inq_dimlen(Result.NCID, dimid, dimlen), 'inq latitude len');
  Result.NLat := dimlen;

  NCCheck(nc_inq_dimid(Result.NCID, 'longitude', dimid), 'inq longitude dim');
  NCCheck(nc_inq_dimlen(Result.NCID, dimid, dimlen), 'inq longitude len');
  Result.NLon := dimlen;

  NCCheck(nc_inq_dimid(Result.NCID, 'time', dimid), 'inq time dim');
  NCCheck(nc_inq_dimlen(Result.NCID, dimid, dimlen), 'inq time len');
  Result.NTime := dimlen;

  NCCheck(nc_inq_varid(Result.NCID, PAnsiChar(AnsiString(VAR_NAMES[0])), Result.VarIDs[0]),
          'inq varid ' + VAR_NAMES[0]);
  nc_close(Result.NCID);

  { Now we know the grid shape. We'll open files per-variable during read. }
  for i := 0 to NUM_VARS - 1 do
    Result.VarIDs[i] := -1; { will be populated during read }
end;

procedure ReadLatLon(const cacheDir: string; year: Integer;
                     var latArr: array of Single; var lonArr: array of Single;
                     nlat, nlon: Integer);
var
  ncid, varid: Integer;
  path: string;
begin
  path := AgMERRAPath(cacheDir, year, VAR_NAMES[0]);
  NCCheck(nc_open(PAnsiChar(AnsiString(path)), NC_NOWRITE, ncid), 'nc_open for coords');
  NCCheck(nc_inq_varid(ncid, 'latitude', varid), 'inq latitude varid');
  NCCheck(nc_get_var_float(ncid, varid, @latArr[0]), 'get latitude');
  NCCheck(nc_inq_varid(ncid, 'longitude', varid), 'inq longitude varid');
  NCCheck(nc_get_var_float(ncid, varid, @lonArr[0]), 'get longitude');
  nc_close(ncid);
end;

function NearestIndex(const values: array of Single; target: Single; n: Integer): Integer;
var
  i: Integer;
  delta, bestDelta: Single;
begin
  Result := 0;
  bestDelta := Abs(values[0] - target);
  for i := 1 to n - 1 do
  begin
    delta := Abs(values[i] - target);
    if delta < bestDelta then
    begin
      Result := i;
      bestDelta := delta;
    end;
  end;
end;

{ ---------- Output file management ---------- }

procedure PrepareOutputFiles(const outDir: string);
var
  i: Integer;
  f: TextFile;
  path, baseName: string;
begin
  ForceDirectories(outDir);
  for i := 0 to NumPoints - 1 do
  begin
    path := IncludeTrailingPathDelimiter(outDir) + Points[i].OutputName;
    baseName := ExtractFileBaseName(Points[i].OutputName);
    AssignFile(f, path);
    Rewrite(f);
    WriteLn(f, baseName, #9, 'generated from NASA GISS AgMERRA NetCDF4');
    WriteLn(f, Format('%.4f %.4f', [Points[i].Lon, Points[i].Lat]));
    WriteLn(f, 'month day year tmax tmin solar rain rh wind');
    CloseFile(f);
  end;
end;

procedure BuildIndex(const cacheDir: string; year: Integer; nlat, nlon: Integer);
var
  latArr: array of Single;
  lonArr: array of Single;
  i: Integer;
  lonTarget: Double;
begin
  SetLength(latArr, nlat);
  SetLength(lonArr, nlon);
  ReadLatLon(cacheDir, year, latArr, lonArr, nlat, nlon);

  SetLength(Indexed, NumPoints);
  for i := 0 to NumPoints - 1 do
  begin
    Indexed[i].Point := Points[i];
    Indexed[i].LatIdx := NearestIndex(latArr, Points[i].Lat, nlat);
    lonTarget := Points[i].Lon;
    while lonTarget < 0 do lonTarget := lonTarget + 360.0;
    while lonTarget >= 360.0 do lonTarget := lonTarget - 360.0;
    Indexed[i].LonIdx := NearestIndex(lonArr, lonTarget, nlon);
  end;
end;

{ ---------- Year writing (batch mode) ---------- }

procedure WriteYearForPoints(year: Integer; const cacheDir, outDir: string;
                             nlat, nlon: Integer);
var
  v, ti, i: Integer;
  ncid, varid: Integer;
  path: string;
  ndays: Integer;
  start: array[0..2] of size_t;  { time, lat, lon }
  count: array[0..2] of size_t;
  grid: array of Single;  { one lat×lon slice }
  dayValues: array[0..NUM_VARS-1] of array of Single;  { per-point values }
  buffers: TStringList;
  outPath: string;
  f: TextFile;
  d: TDateTime;
  yr, mo, da: Word;
  gridSize: Integer;
begin
  ndays := DaysInYear(year);
  gridSize := nlat * nlon;
  SetLength(grid, gridSize);

  for v := 0 to NUM_VARS - 1 do
    SetLength(dayValues[v], NumPoints);

  { Build string buffers for each point }
  buffers := TStringList.Create;
  try
    buffers.Capacity := NumPoints;
    for i := 0 to NumPoints - 1 do
      buffers.Add('');

    for ti := 0 to ndays - 1 do
    begin
      d := EncodeDate(year, 1, 1) + ti;
      DecodeDate(d, yr, mo, da);

      { Read one daily slice per variable }
      for v := 0 to NUM_VARS - 1 do
      begin
        path := AgMERRAPath(cacheDir, year, VAR_NAMES[v]);
        NCCheck(nc_open(PAnsiChar(AnsiString(path)), NC_NOWRITE, ncid), 'nc_open ' + path);
        NCCheck(nc_inq_varid(ncid, PAnsiChar(AnsiString(VAR_NAMES[v])), varid), 'inq varid');

        start[0] := ti; start[1] := 0; start[2] := 0;
        count[0] := 1; count[1] := nlat; count[2] := nlon;
        NCCheck(nc_get_vara_float(ncid, varid, @start[0], @count[0], @grid[0]),
                Format('get_vara %s day %d', [VAR_NAMES[v], ti]));
        nc_close(ncid);

        { Extract values for all points from the grid }
        for i := 0 to NumPoints - 1 do
        begin
          dayValues[v][i] := grid[Indexed[i].LatIdx * nlon + Indexed[i].LonIdx];
          if v = 2 then { srad: MJ/m2/day -> W/m2 }
            dayValues[v][i] := dayValues[v][i] * MJ_M2_DAY_TO_W_M2;
        end;
      end;

      { Append formatted line to each point's buffer }
      for i := 0 to NumPoints - 1 do
        buffers[i] := buffers[i] +
          Format('%d %d %d %.3f %.3f %.3f %.3f %.3f %.3f'#10,
            [mo, da, yr,
             dayValues[0][i], dayValues[1][i], dayValues[2][i],
             dayValues[3][i], dayValues[4][i], dayValues[5][i]]);
    end;

    { Flush buffers to files }
    for i := 0 to NumPoints - 1 do
    begin
      outPath := IncludeTrailingPathDelimiter(outDir) + Points[i].OutputName;
      AssignFile(f, outPath);
      Append(f);
      Write(f, buffers[i]);
      CloseFile(f);
    end;
  finally
    buffers.Free;
  end;
end;

{ ---------- Resume detection ---------- }

function DetectCompletedYears(const outDir: string; startYear: Integer): Integer;
var
  i, n, idx, lastYear, minLastYear: Integer;
  path, line: string;
  f: TextFile;
  parts: TStringList;
  y: Integer;
  step: Integer;
  checked: Integer;
begin
  Result := startYear;
  if NumPoints = 0 then Exit;

  { Sample up to 10 files spread across the point list }
  n := Min(10, NumPoints);
  if n <= 0 then Exit;
  step := NumPoints div n;
  if step < 1 then step := 1;

  minLastYear := MaxInt;
  checked := 0;

  for i := 0 to n - 1 do
  begin
    idx := i * step;
    if idx >= NumPoints then Break;
    path := IncludeTrailingPathDelimiter(outDir) + Points[idx].OutputName;
    if not FileExists(path) then Exit;

    lastYear := 0;
    AssignFile(f, path);
    Reset(f);
    while not Eof(f) do
    begin
      ReadLn(f, line);
      parts := TStringList.Create;
      try
        parts.Delimiter := ' ';
        parts.StrictDelimiter := True;
        parts.DelimitedText := line;
        if parts.Count >= 3 then
        begin
          Val(parts[2], y, idx);
          if (idx = 0) and (y > 1900) and (y < 2100) then
            lastYear := y;
        end;
      finally
        parts.Free;
      end;
    end;
    CloseFile(f);

    if lastYear = 0 then Exit;
    if lastYear < minLastYear then
      minLastYear := lastYear;
    Inc(checked);
  end;

  if (checked > 0) and (minLastYear < MaxInt) then
    Result := minLastYear + 1;
end;

{ ---------- Manifest ---------- }

procedure WriteManifest(const outDir: string);
var
  f: TextFile;
  i: Integer;
begin
  AssignFile(f, IncludeTrailingPathDelimiter(outDir) + '_manifest.tsv');
  Rewrite(f);
  WriteLn(f, 'output_name'#9'lon'#9'lat'#9'lat_index_0'#9'lon_index_0');
  for i := 0 to NumPoints - 1 do
    WriteLn(f, Format('%s'#9'%.4f'#9'%.4f'#9'%d'#9'%d',
      [Indexed[i].Point.OutputName, Indexed[i].Point.Lon,
       Indexed[i].Point.Lat, Indexed[i].LatIdx, Indexed[i].LonIdx]));
  CloseFile(f);
end;

{ ---------- Command-line parsing ---------- }

procedure PrintUsage;
begin
  WriteLn('Usage: agmerra_to_pascal_weather [options]');
  WriteLn('  --points-file FILE   Legacy GIS output with WxFile/Long/Lat or TSV');
  WriteLn('  --start-year YEAR    First year to convert');
  WriteLn('  --end-year YEAR      Last year to convert');
  WriteLn('  --cache-dir DIR      Directory for downloaded NetCDF4 files');
  WriteLn('  --out-dir DIR        Output directory for weather text files');
  WriteLn('  --limit N            Limit number of points (for testing)');
  WriteLn('  --overwrite          Replace existing output files');
  WriteLn('  --resume             Resume from last completed year');
  WriteLn('  --download-only      Only download NetCDF4 source files');
  WriteLn('  --help               Show this help');
end;

procedure ParseArgs;
var
  i: Integer;
  arg: string;
begin
  OptPointsFile := '';
  OptStartYear := 0;
  OptEndYear := 0;
  OptCacheDir := ExpandFileName('~/.cache/pbdm-agmerra');
  OptOutDir := 'data/agmerra-pascal-weather';
  OptLimit := 0;
  OptOverwrite := False;
  OptResume := False;
  OptDownloadOnly := False;

  i := 1;
  while i <= ParamCount do
  begin
    arg := ParamStr(i);
    if (arg = '--help') or (arg = '-h') then
    begin
      PrintUsage;
      Halt(0);
    end
    else if arg = '--points-file' then begin Inc(i); OptPointsFile := ParamStr(i); end
    else if arg = '--start-year' then begin Inc(i); OptStartYear := StrToInt(ParamStr(i)); end
    else if arg = '--end-year' then begin Inc(i); OptEndYear := StrToInt(ParamStr(i)); end
    else if arg = '--cache-dir' then begin Inc(i); OptCacheDir := ParamStr(i); end
    else if arg = '--out-dir' then begin Inc(i); OptOutDir := ParamStr(i); end
    else if arg = '--limit' then begin Inc(i); OptLimit := StrToInt(ParamStr(i)); end
    else if arg = '--overwrite' then OptOverwrite := True
    else if arg = '--resume' then OptResume := True
    else if arg = '--download-only' then OptDownloadOnly := True
    else begin
      WriteLn(StdErr, 'Unknown argument: ', arg);
      PrintUsage;
      Halt(1);
    end;
    Inc(i);
  end;

  if OptPointsFile = '' then begin WriteLn(StdErr, '--points-file is required'); Halt(1); end;
  if OptStartYear = 0 then begin WriteLn(StdErr, '--start-year is required'); Halt(1); end;
  if OptEndYear = 0 then begin WriteLn(StdErr, '--end-year is required'); Halt(1); end;
end;

{ ---------- Main ---------- }

var
  ds: TNCDataset;
  actualStart, year, v: Integer;

begin
  ParseArgs;

  WriteLn(Format('Parsing points from %s...', [OptPointsFile]));
  ParsePointsFile(OptPointsFile);
  if OptLimit > 0 then
  begin
    if OptLimit < NumPoints then
    begin
      NumPoints := OptLimit;
      SetLength(Points, NumPoints);
    end;
  end;
  WriteLn(Format('Found %d unique points', [NumPoints]));

  if OptDownloadOnly then
  begin
    for year := OptStartYear to OptEndYear do
      for v := 0 to NUM_VARS - 1 do
        EnsureAgMERRAFile(OptCacheDir, year, VAR_NAMES[v]);
    WriteLn('Download complete.');
    Halt(0);
  end;

  { Get grid dimensions from first year }
  ds := OpenYear(OptCacheDir, OptStartYear);
  WriteLn(Format('Grid: %d lat x %d lon, %d time steps', [ds.NLat, ds.NLon, ds.NTime]));

  { Build spatial index }
  BuildIndex(OptCacheDir, OptStartYear, ds.NLat, ds.NLon);

  { Handle resume }
  actualStart := OptStartYear;
  if OptResume and (not OptOverwrite) then
  begin
    actualStart := DetectCompletedYears(OptOutDir, OptStartYear);
    if actualStart > OptEndYear then
    begin
      WriteLn(Format('All years %d-%d already present, nothing to do.', [OptStartYear, OptEndYear]));
      Halt(0);
    end;
    if actualStart > OptStartYear then
      WriteLn(Format('Resuming from %d (years %d-%d already written)',
                     [actualStart, OptStartYear, actualStart - 1]));
  end;

  { Create/overwrite output files if starting fresh }
  if (not OptResume) or (actualStart = OptStartYear) then
    PrepareOutputFiles(OptOutDir);

  WriteManifest(OptOutDir);

  { Convert year by year }
  for year := actualStart to OptEndYear do
  begin
    WriteLn(Format('Writing year %d for %d points', [year, NumPoints]));
    Flush(Output);
    WriteYearForPoints(year, OptCacheDir, OptOutDir, ds.NLat, ds.NLon);
  end;

  WriteLn('Done.');
end.
