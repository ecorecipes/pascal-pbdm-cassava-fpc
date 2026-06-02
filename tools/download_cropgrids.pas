{
  download_cropgrids - Download the CROPGRIDS v1.08 cassava harvested-area grid.

  FPC port of tools/download_cropgrids.py.

  CROPGRIDS (Tang et al. 2024, Scientific Data, CC BY 4.0) is published on
  Figshare (doi:10.6084/m9.figshare.22491997).  The per-crop NetCDF maps are
  only distributed inside a single 806 MB archive (CROPGRIDSv1.08_NC_maps.zip).
  By default this tool performs a *partial* extraction: it uses HTTP range
  requests (via curl) to read only the ZIP central directory and then only the
  bytes of the cassava member, and inflates them locally with paszlib.  Pass
  --full-zip to download and extract the entire archive instead.

  Build:
    fpc -Mdelphi \
        -Fi/opt/homebrew/include \
        -Fl/opt/homebrew/lib \
        download_cropgrids.pas

  Usage:
    ./download_cropgrids [--out-dir DIR] [--natural-earth] [--full-zip] [--overwrite]

  Requires curl on PATH and libnetcdf for validation (brew install netcdf).
}

program download_cropgrids;

{$mode delphi}
{$H+}

uses
  SysUtils, Classes, zstream;

{ ---------- NetCDF C library bindings (validation only) ---------- }

const
  {$IFDEF DARWIN}
  NETCDF_LIB = 'libnetcdf.dylib';
  {$ELSE}
  NETCDF_LIB = 'libnetcdf.so';
  {$ENDIF}
  NC_NOWRITE = 0;
  NC_NOERR   = 0;

function nc_open(path: PAnsiChar; mode: Integer; var ncid: Integer): Integer; cdecl; external NETCDF_LIB;
function nc_close(ncid: Integer): Integer; cdecl; external NETCDF_LIB;
function nc_inq_varid(ncid: Integer; name: PAnsiChar; var varid: Integer): Integer; cdecl; external NETCDF_LIB;

{ ---------- Constants ---------- }

const
  { Figshare download endpoint for CROPGRIDSv1.08_NC_maps.zip (article 22491997).
    Hitting it 302-redirects to a short-lived signed S3 URL; the redirect (curl -L)
    preserves the Range header, so each ranged request gets a fresh signed URL. }
  ZIP_URL     = 'https://ndownloader.figshare.com/files/44950942';
  MEMBER_NAME = 'CROPGRIDSv1.08_NC_maps/CROPGRIDSv1.08_cassava.nc';
  OUTPUT_NAME = 'CROPGRIDSv1.08_cassava.nc';

  { Natural Earth 10m admin-0 country borders, used by build_cassava_mask. }
  NE_URL         = 'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/' +
                   'master/geojson/ne_10m_admin_0_countries.geojson';
  NE_OUTPUT_NAME = 'ne_10m_admin_0_countries.geojson';

var
  OptOutDir: string;
  OptNaturalEarth: Boolean;
  OptFullZip: Boolean;
  OptOverwrite: Boolean;

{ ---------- Little-endian byte helpers ---------- }

function ReadLE16(const b: TBytes; off: Integer): LongWord;
begin
  Result := LongWord(b[off]) or (LongWord(b[off+1]) shl 8);
end;

function ReadLE32(const b: TBytes; off: Integer): LongWord;
begin
  Result := LongWord(b[off]) or (LongWord(b[off+1]) shl 8) or
            (LongWord(b[off+2]) shl 16) or (LongWord(b[off+3]) shl 24);
end;

{ ---------- curl helpers ---------- }

function ShellQuote(const s: string): string;
begin
  Result := '"' + StringReplace(s, '"', '\"', [rfReplaceAll]) + '"';
end;

procedure RunCurl(const args: string);
var
  rc: Integer;
begin
  rc := ExecuteProcess('/bin/sh', ['-c', 'curl ' + args]);
  if rc <> 0 then
    raise Exception.CreateFmt('curl failed (exit %d): %s', [rc, args]);
end;

function FileSizeOf(const path: string): Int64;
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(path, fmOpenRead or fmShareDenyNone);
  try
    Result := fs.Size;
  finally
    fs.Free;
  end;
end;

{ Download bytes [start..fin] of url into a TBytes; parse the archive total size
  from the final Content-Range header.  Retries on transient failures. }
function CurlRange(const url: string; start, fin: Int64; out total: Int64;
  retries: Integer = 3): TBytes;
var
  bodyFile, hdrFile, hdr, line: string;
  ms: TMemoryStream;
  sl: TStringList;
  attempt, p: Integer;
begin
  total := -1;
  bodyFile := GetTempFileName('', 'cgbody');
  hdrFile := GetTempFileName('', 'cghdr');
  try
    for attempt := 1 to retries do
    begin
      try
        RunCurl(Format('-sS -f -L -r %d-%d -D %s -o %s %s',
          [start, fin, ShellQuote(hdrFile), ShellQuote(bodyFile), ShellQuote(url)]));
        Break;
      except
        on E: Exception do
        begin
          if attempt = retries then raise;
          WriteLn('  range request failed: ', E.Message, '; retrying...');
          Sleep(1000);
        end;
      end;
    end;

    ms := TMemoryStream.Create;
    try
      ms.LoadFromFile(bodyFile);
      SetLength(Result, ms.Size);
      if ms.Size > 0 then ms.ReadBuffer(Result[0], ms.Size);
    finally
      ms.Free;
    end;

    { Scan all redirect header blocks; keep the last Content-Range total. }
    sl := TStringList.Create;
    try
      sl.LoadFromFile(hdrFile);
      for line in sl do
      begin
        hdr := LowerCase(line);
        if Pos('content-range:', hdr) = 1 then
        begin
          p := Pos('/', line);
          if p > 0 then
            total := StrToInt64Def(Trim(Copy(line, p + 1, MaxInt)), total);
        end;
      end;
    finally
      sl.Free;
    end;
  finally
    if FileExists(bodyFile) then DeleteFile(bodyFile);
    if FileExists(hdrFile) then DeleteFile(hdrFile);
  end;
end;

{ ---------- Partial ZIP extraction ---------- }

procedure FindMember(const url: string; out lho: Int64; out method: LongWord;
  out compSize, uncompSize: Int64);
var
  total, tailStart, cdOff, cdSize: Int64;
  probe, tail, cdir: TBytes;
  i, pos, nlen, elen, clen: Integer;
  name: string;
  found: Boolean;
begin
  { A tiny probe yields the archive total size from Content-Range. }
  probe := CurlRange(url, 0, 1, total);
  if total <= 0 then
    raise Exception.Create('Could not determine archive size (no Content-Range)');

  tailStart := total - 66000;
  if tailStart < 0 then tailStart := 0;
  tail := CurlRange(url, tailStart, total - 1, total);

  { Find End Of Central Directory signature  PK#05#06 . }
  i := High(tail) - 21;
  while i >= 0 do
  begin
    if (tail[i] = $50) and (tail[i+1] = $4B) and (tail[i+2] = $05) and (tail[i+3] = $06) then
      Break;
    Dec(i);
  end;
  if i < 0 then
    raise Exception.Create('Could not find ZIP end-of-central-directory record');

  cdSize := ReadLE32(tail, i + 12);
  cdOff := ReadLE32(tail, i + 16);
  cdir := CurlRange(url, cdOff, cdOff + cdSize - 1, total);

  found := False;
  pos := 0;
  while (pos + 46 <= Length(cdir)) and
        (cdir[pos] = $50) and (cdir[pos+1] = $4B) and (cdir[pos+2] = $01) and (cdir[pos+3] = $02) do
  begin
    method := ReadLE16(cdir, pos + 10);
    compSize := ReadLE32(cdir, pos + 20);
    uncompSize := ReadLE32(cdir, pos + 24);
    nlen := ReadLE16(cdir, pos + 28);
    elen := ReadLE16(cdir, pos + 30);
    clen := ReadLE16(cdir, pos + 32);
    lho := ReadLE32(cdir, pos + 42);
    SetLength(name, nlen);
    if nlen > 0 then Move(cdir[pos + 46], name[1], nlen);
    if (name = MEMBER_NAME) or
       (Copy(name, Length(name) - Length(OUTPUT_NAME) + 1, MaxInt) = OUTPUT_NAME) then
    begin
      found := True;
      Break;
    end;
    Inc(pos, 46 + nlen + elen + clen);
  end;
  if not found then
    raise Exception.CreateFmt('Member %s not found in archive central directory', [MEMBER_NAME]);
end;

procedure InflateRaw(const src: TBytes; out dst: TBytes; expected: Int64);
var
  srcStream: TMemoryStream;
  ds: TDecompressionStream;
  total, n: Integer;
begin
  srcStream := TMemoryStream.Create;
  try
    if Length(src) > 0 then srcStream.WriteBuffer(src[0], Length(src));
    srcStream.Position := 0;
    SetLength(dst, expected);
    ds := TDecompressionStream.Create(srcStream, True { raw deflate });
    try
      total := 0;
      repeat
        n := ds.Read(dst[total], Integer(expected) - total);
        Inc(total, n);
      until (n = 0) or (total >= expected);
    finally
      ds.Free;
    end;
    if total <> expected then
      raise Exception.CreateFmt('Inflated size %d <> expected %d; download corrupt',
        [total, Int64(expected)]);
  finally
    srcStream.Free;
  end;
end;

procedure ExtractMember(const url, dest: string);
var
  lho, compSize, uncompSize, dataStart, total: Int64;
  method, nlen, elen: LongWord;
  header, raw, data: TBytes;
  fs: TFileStream;
begin
  FindMember(url, lho, method, compSize, uncompSize);
  header := CurlRange(url, lho, lho + 30 - 1, total);
  if not ((header[0] = $50) and (header[1] = $4B) and (header[2] = $03) and (header[3] = $04)) then
    raise Exception.Create('Local file header signature mismatch');
  nlen := ReadLE16(header, 26);
  elen := ReadLE16(header, 28);
  dataStart := lho + 30 + nlen + elen;
  WriteLn(Format('Extracting %s (%.1f MB compressed, %.1f MB) via range requests',
    [OUTPUT_NAME, compSize / 1e6, uncompSize / 1e6]));
  raw := CurlRange(url, dataStart, dataStart + compSize - 1, total);
  if method = 0 then
    data := raw
  else if method = 8 then
    InflateRaw(raw, data, uncompSize)
  else
    raise Exception.CreateFmt('Unsupported ZIP compression method %d', [method]);

  fs := TFileStream.Create(dest, fmCreate);
  try
    if Length(data) > 0 then fs.WriteBuffer(data[0], Length(data));
  finally
    fs.Free;
  end;
end;

procedure ExtractFullZip(const url, dest: string);
var
  zipPath, member, cmd: string;
  rc: Integer;
begin
  zipPath := ExtractFilePath(dest) + 'CROPGRIDSv1.08_NC_maps.zip';
  WriteLn('Downloading full archive to ', zipPath, ' (~806 MB)...');
  RunCurl(Format('-sS -f -L -o %s %s', [ShellQuote(zipPath), ShellQuote(url)]));
  { Extract the single member with the system unzip. }
  member := MEMBER_NAME;
  cmd := Format('unzip -p %s %s > %s',
    [ShellQuote(zipPath), ShellQuote(member), ShellQuote(dest)]);
  rc := ExecuteProcess('/bin/sh', ['-c', cmd]);
  if rc <> 0 then
    raise Exception.CreateFmt('unzip failed (exit %d)', [rc]);
  WriteLn('Extracted ', member, ' -> ', dest);
end;

{ ---------- Validation ---------- }

procedure ValidateNetCDF(const path: string);
var
  ncid, varid, rc: Integer;
begin
  rc := nc_open(PAnsiChar(AnsiString(path)), NC_NOWRITE, ncid);
  if rc <> NC_NOERR then
    raise Exception.CreateFmt('%s is not a valid NetCDF file', [path]);
  rc := nc_inq_varid(ncid, 'harvarea', varid);
  nc_close(ncid);
  if rc <> NC_NOERR then
    raise Exception.CreateFmt('%s is missing the expected ''harvarea'' variable', [path]);
end;

function IsValidNetCDF(const path: string): Boolean;
begin
  Result := True;
  try
    ValidateNetCDF(path);
  except
    Result := False;
  end;
end;

{ ---------- CLI ---------- }

procedure ParseArgs;
var
  i: Integer;
  arg: string;
begin
  OptOutDir := 'data/cropgrids';
  OptNaturalEarth := False;
  OptFullZip := False;
  OptOverwrite := False;
  i := 1;
  while i <= ParamCount do
  begin
    arg := ParamStr(i);
    if arg = '--out-dir' then begin Inc(i); OptOutDir := ParamStr(i); end
    else if arg = '--natural-earth' then OptNaturalEarth := True
    else if arg = '--full-zip' then OptFullZip := True
    else if arg = '--overwrite' then OptOverwrite := True
    else if (arg = '-h') or (arg = '--help') then
    begin
      WriteLn('Usage: download_cropgrids [--out-dir DIR] [--natural-earth] [--full-zip] [--overwrite]');
      Halt(0);
    end
    else
    begin
      WriteLn(StdErr, 'Unknown argument: ', arg);
      Halt(2);
    end;
    Inc(i);
  end;
end;

var
  dest, neDest: string;
begin
  ParseArgs;
  ForceDirectories(OptOutDir);

  if OptNaturalEarth then
  begin
    neDest := IncludeTrailingPathDelimiter(OptOutDir) + NE_OUTPUT_NAME;
    if FileExists(neDest) and not OptOverwrite then
      WriteLn(neDest, ' already present; use --overwrite to replace.')
    else
    begin
      WriteLn('Downloading Natural Earth borders -> ', neDest);
      RunCurl(Format('-sS -f -L -o %s %s', [ShellQuote(neDest), ShellQuote(NE_URL)]));
      WriteLn(Format('Wrote %s (%.1f MB)', [neDest, FileSizeOf(neDest) / 1e6]));
    end;
  end;

  dest := IncludeTrailingPathDelimiter(OptOutDir) + OUTPUT_NAME;
  if FileExists(dest) and not OptOverwrite then
  begin
    if IsValidNetCDF(dest) then
    begin
      WriteLn(dest, ' already present and valid; use --overwrite to replace.');
      Halt(0);
    end;
    WriteLn(dest, ' present but invalid; re-downloading.');
  end;

  if OptFullZip then
    ExtractFullZip(ZIP_URL, dest)
  else
    ExtractMember(ZIP_URL, dest);
  ValidateNetCDF(dest);
  WriteLn(Format('Wrote %s (%.1f MB)', [dest, FileSizeOf(dest) / 1e6]));
end.
