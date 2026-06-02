{
  build_cassava_mask - Derive the cassava harvested-area mask / weather
  points-file from CROPGRIDS.

  FPC port of tools/build_cassava_mask.py.  Reproduces
  data/cropgrids/cassava_africa_mask_agmerra.csv: the AgMERRA 0.25-degree
  lattice cells over Africa where cassava is grown, which drives per-cell
  weather generation (tools/agmerra_to_pascal_weather).

  Pipeline:
    1. Read CROPGRIDS v1.08 cassava harvarea (0.05 deg, 7200x3600, ascending
       lon/lat, Ocean = -1) via libnetcdf.
    2. Aggregate to the AgMERRA 0.25 deg grid (exact 5x5 block sum, Ocean->0).
    3. Keep cells with harvarea > 0 whose centre falls inside an African country
       (Natural Earth 10m admin-0 point-in-polygon) and which have valid AgMERRA
       weather (all six drivers present for --agmerra-year).
    4. Emit  agmerra_<lonidx4>_<latidx3>_<ISO3>_<sub2>.txt  names.

  Build:
    fpc -Mdelphi \
        -Fi/opt/homebrew/include -Fl/opt/homebrew/lib \
        -k-L/opt/homebrew/lib -k-lnetcdf \
        build_cassava_mask.pas

  Usage:
    ./build_cassava_mask [--cropgrids-nc F] [--countries-file F] [--out F]
                         [--agmerra-cache DIR] [--agmerra-year Y] [--validate [F]]
}

program build_cassava_mask;

{$mode delphi}
{$H+}

uses
  SysUtils, Classes, Math, fpjson, jsonparser;

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
function nc_get_att_float(ncid: Integer; varid: Integer; name: PAnsiChar; fp: PSingle): Integer; cdecl; external NETCDF_LIB;
function nc_strerror(ncerr: Integer): PAnsiChar; cdecl; external NETCDF_LIB;

procedure NCCheck(rc: Integer; const context: string);
begin
  if rc <> NC_NOERR then
    raise Exception.CreateFmt('NetCDF error in %s: %s', [context, nc_strerror(rc)]);
end;

{ ---------- Constants ---------- }

const
  AGMERRA_RES = 0.25;
  CROPGRIDS_FACTOR = 5;
  AGM_NLAT = 720;
  AGM_NLON = 1440;

  AGM_VAR_NAMES: array[0..5] of string =
    ('tmax', 'tmin', 'srad', 'prate', 'rhstmax', 'wndspd');

  { country ISO3 -> UN M49 sub-region code used in the weather-file names. }
  SUBREGION_ISO: array[0..42] of string = (
    'AGO','BDI','BEN','BFA','BWA','CAF','CIV','CMR','COD','COG',
    'ERI','ETH','GAB','GHA','GIN','GMB','GNB','GNQ','KEN','LBR',
    'MDG','MLI','MOZ','MRT','MWI','NAM','NER','NGA','RWA','SDN',
    'SEN','SLE','SOL','SOM','SSD','STP','TCD','TGO','TZA','UGA',
    'ZAF','ZMB','ZWE');
  SUBREGION_SUB: array[0..42] of string = (
    'MA','EA','WA','WA','SA','MA','WA','MA','MA','MA',
    'EA','EA','MA','WA','WA','WA','WA','MA','EA','WA',
    'EA','WA','EA','WA','EA','SA','WA','WA','EA','NF',
    'WA','WA','EA','EA','EA','MA','MA','WA','EA','EA',
    'SA','EA','EA');

{ ---------- Geometry types ---------- }

type
  TPt = record x, y: Double; end;
  TRing = array of TPt;
  TPoly = record rings: array of TRing; end;
  TCountry = record
    iso: string;
    polys: array of TPoly;
    minLon, maxLon, minLat, maxLat: Double;
  end;

  TMaskRow = record
    Lon, Lat, Ha: Double;
    Name: string;
  end;

var
  Countries: array of TCountry;

  OptCropgridsNC: string;
  OptCountriesFile: string;
  OptOut: string;
  OptAgmerraCache: string;
  OptAgmerraYear: Integer;
  OptValidate: Boolean;
  OptValidateFile: string;

  Rows: array of TMaskRow;
  NumRows: Integer;

{ ---------- Subregion lookup / ISO remap ---------- }

function SubregionOf(const iso: string): string;
var i: Integer;
begin
  for i := 0 to High(SUBREGION_ISO) do
    if SUBREGION_ISO[i] = iso then Exit(SUBREGION_SUB[i]);
  Result := '';
end;

function RemapIso(const iso: string): string;
begin
  if iso = 'SDS' then Result := 'SSD'  { Natural Earth code for South Sudan }
  else Result := iso;
end;

{ ---------- CROPGRIDS aggregation ---------- }

procedure AggregateHarvarea(const ncPath: string;
  var agg: array of Double; var lonC, latC: array of Double);
var
  ncid, dimid, varid: Integer;
  nlonL, nlatL: size_t;
  nlon, nlat, i, j, ii, jj, idx: Integer;
  cgLon, cgLat: array of Single;
  ha: array of Single;
  v: Double;
begin
  NCCheck(nc_open(PAnsiChar(AnsiString(ncPath)), NC_NOWRITE, ncid), 'nc_open ' + ncPath);
  try
    NCCheck(nc_inq_dimid(ncid, 'lon', dimid), 'dimid lon');
    NCCheck(nc_inq_dimlen(ncid, dimid, nlonL), 'dimlen lon');
    NCCheck(nc_inq_dimid(ncid, 'lat', dimid), 'dimid lat');
    NCCheck(nc_inq_dimlen(ncid, dimid, nlatL), 'dimlen lat');
    nlon := nlonL; nlat := nlatL;
    if (nlon mod CROPGRIDS_FACTOR <> 0) or (nlat mod CROPGRIDS_FACTOR <> 0) then
      raise Exception.Create('CROPGRIDS grid is not an exact 5x multiple of AgMERRA');

    SetLength(cgLon, nlon); SetLength(cgLat, nlat);
    NCCheck(nc_inq_varid(ncid, 'lon', varid), 'varid lon');
    NCCheck(nc_get_var_float(ncid, varid, @cgLon[0]), 'get lon');
    NCCheck(nc_inq_varid(ncid, 'lat', varid), 'varid lat');
    NCCheck(nc_get_var_float(ncid, varid, @cgLat[0]), 'get lat');

    SetLength(ha, Int64(nlon) * nlat);
    NCCheck(nc_inq_varid(ncid, 'harvarea', varid), 'varid harvarea');
    NCCheck(nc_get_var_float(ncid, varid, @ha[0]), 'get harvarea');
  finally
    nc_close(ncid);
  end;

  for j := 0 to AGM_NLON - 1 do lonC[j] := cgLon[j * CROPGRIDS_FACTOR + 2];
  for i := 0 to AGM_NLAT - 1 do latC[i] := cgLat[i * CROPGRIDS_FACTOR + 2];
  for i := 0 to AGM_NLAT * AGM_NLON - 1 do agg[i] := 0;

  for i := 0 to nlat - 1 do
  begin
    ii := i div CROPGRIDS_FACTOR;
    for j := 0 to nlon - 1 do
    begin
      v := ha[Int64(i) * nlon + j];
      if v < 0 then v := 0;   { Ocean (-1) -> 0 }
      if v <> 0 then
      begin
        jj := j div CROPGRIDS_FACTOR;
        agg[ii * AGM_NLON + jj] := agg[ii * AGM_NLON + jj] + v;
      end;
    end;
  end;
end;

{ ---------- AgMERRA validity mask ---------- }

function LoadAgmerraValidMask(const cacheDir: string; year: Integer;
  var valid: array of Boolean): Boolean;
var
  v, i, ncid, varid, rc: Integer;
  path: string;
  startp, countp: array[0..2] of size_t;
  buf: array of Single;
  fillv: Single;
  thresh: Single;
begin
  Result := False;
  for v := 0 to High(AGM_VAR_NAMES) do
  begin
    path := IncludeTrailingPathDelimiter(cacheDir) +
            Format('AgMERRA_%d_%s.nc4', [year, AGM_VAR_NAMES[v]]);
    if not FileExists(path) then Exit(False);
  end;

  for i := 0 to AGM_NLAT * AGM_NLON - 1 do valid[i] := True;
  SetLength(buf, AGM_NLAT * AGM_NLON);

  for v := 0 to High(AGM_VAR_NAMES) do
  begin
    path := IncludeTrailingPathDelimiter(cacheDir) +
            Format('AgMERRA_%d_%s.nc4', [year, AGM_VAR_NAMES[v]]);
    NCCheck(nc_open(PAnsiChar(AnsiString(path)), NC_NOWRITE, ncid), 'nc_open ' + path);
    try
      NCCheck(nc_inq_varid(ncid, PAnsiChar(AnsiString(AGM_VAR_NAMES[v])), varid),
        'varid ' + AGM_VAR_NAMES[v]);
      startp[0] := 0; startp[1] := 0; startp[2] := 0;
      countp[0] := 1; countp[1] := AGM_NLAT; countp[2] := AGM_NLON;
      NCCheck(nc_get_vara_float(ncid, varid, @startp[0], @countp[0], @buf[0]),
        'get_vara ' + AGM_VAR_NAMES[v]);
      rc := nc_get_att_float(ncid, varid, '_FillValue', @fillv);
      if rc <> NC_NOERR then fillv := 1e20;
    finally
      nc_close(ncid);
    end;
    thresh := Min(Single(fillv) * 0.999, 1e15);
    for i := 0 to AGM_NLAT * AGM_NLON - 1 do
      if (buf[i] >= thresh) or IsNan(buf[i]) then valid[i] := False;
  end;
  Result := True;
end;

function AgmerraCellValid(const valid: array of Boolean; hasMask: Boolean;
  lonE, lat: Double): Boolean;
var i, j: Integer;
begin
  if not hasMask then Exit(True);
  j := Round((lonE - 0.125) / AGMERRA_RES);
  i := Round((89.875 - lat) / AGMERRA_RES);
  if (i >= 0) and (i < AGM_NLAT) and (j >= 0) and (j < AGM_NLON) then
    Result := valid[i * AGM_NLON + j]
  else
    Result := False;
end;

{ ---------- Country polygons (GeoJSON) ---------- }

procedure ParsePolygon(jpoly: TJSONArray; var poly: TPoly);
var r, k: Integer; jring, jpt: TJSONArray;
begin
  SetLength(poly.rings, jpoly.Count);
  for r := 0 to jpoly.Count - 1 do
  begin
    jring := jpoly.Arrays[r];
    SetLength(poly.rings[r], jring.Count);
    for k := 0 to jring.Count - 1 do
    begin
      jpt := jring.Arrays[k];
      poly.rings[r][k].x := jpt.Floats[0];
      poly.rings[r][k].y := jpt.Floats[1];
    end;
  end;
end;

procedure UpdateCountryBBox(var c: TCountry);
var p, r, k: Integer; pt: TPt;
begin
  c.minLon := 1e30; c.maxLon := -1e30; c.minLat := 1e30; c.maxLat := -1e30;
  for p := 0 to High(c.polys) do
    for r := 0 to High(c.polys[p].rings) do
      for k := 0 to High(c.polys[p].rings[r]) do
      begin
        pt := c.polys[p].rings[r][k];
        if pt.x < c.minLon then c.minLon := pt.x;
        if pt.x > c.maxLon then c.maxLon := pt.x;
        if pt.y < c.minLat then c.minLat := pt.y;
        if pt.y > c.maxLat then c.maxLat := pt.y;
      end;
end;

procedure LoadCountries(const path: string);
var
  fs: TFileStream;
  root: TJSONData;
  feats: TJSONArray;
  feat, props, geom: TJSONObject;
  iso, gtype: string;
  coords: TJSONArray;
  i, p, n: Integer;
begin
  fs := TFileStream.Create(path, fmOpenRead);
  root := GetJSON(fs, True);
  try
    feats := TJSONObject(root).Arrays['features'];
    SetLength(Countries, feats.Count);
    n := 0;
    for i := 0 to feats.Count - 1 do
    begin
      feat := feats.Objects[i];
      props := feat.Objects['properties'];
      iso := props.Get('ADM0_A3', '');
      if iso = '' then iso := props.Get('ISO_A3', '');
      if iso = '' then iso := props.Get('SOV_A3', '');
      iso := RemapIso(iso);
      geom := feat.Objects['geometry'];
      gtype := geom.Get('type', '');
      coords := geom.Arrays['coordinates'];

      Countries[n].iso := iso;
      if gtype = 'Polygon' then
      begin
        SetLength(Countries[n].polys, 1);
        ParsePolygon(coords, Countries[n].polys[0]);
      end
      else if gtype = 'MultiPolygon' then
      begin
        SetLength(Countries[n].polys, coords.Count);
        for p := 0 to coords.Count - 1 do
          ParsePolygon(coords.Arrays[p], Countries[n].polys[p]);
      end
      else
        Continue;
      UpdateCountryBBox(Countries[n]);
      Inc(n);
    end;
    SetLength(Countries, n);
  finally
    root.Free;
  end;
end;

function PointInRing(const r: TRing; x, y: Double): Boolean;
var i, j, n: Integer;
begin
  Result := False;
  n := Length(r);
  j := n - 1;
  for i := 0 to n - 1 do
  begin
    if ((r[i].y > y) <> (r[j].y > y)) and
       (x < (r[j].x - r[i].x) * (y - r[i].y) / (r[j].y - r[i].y) + r[i].x) then
      Result := not Result;
    j := i;
  end;
end;

function PointInPoly(const poly: TPoly; x, y: Double): Boolean;
var r: Integer;
begin
  if Length(poly.rings) = 0 then Exit(False);
  if not PointInRing(poly.rings[0], x, y) then Exit(False);
  for r := 1 to High(poly.rings) do
    if PointInRing(poly.rings[r], x, y) then Exit(False);  { inside a hole }
  Result := True;
end;

function AssignCountry(lon, lat: Double): string;
var
  c, p: Integer;
  bestC: Integer;
  bestD, d, cx, cy: Double;
begin
  for c := 0 to High(Countries) do
  begin
    if (lon < Countries[c].minLon) or (lon > Countries[c].maxLon) or
       (lat < Countries[c].minLat) or (lat > Countries[c].maxLat) then Continue;
    for p := 0 to High(Countries[c].polys) do
      if PointInPoly(Countries[c].polys[p], lon, lat) then Exit(Countries[c].iso);
  end;
  { fall back to nearest country by bounding-box centre (rare coastal cells) }
  bestC := -1; bestD := 1e30;
  for c := 0 to High(Countries) do
  begin
    cx := (Countries[c].minLon + Countries[c].maxLon) / 2;
    cy := (Countries[c].minLat + Countries[c].maxLat) / 2;
    d := Sqr(cx - lon) + Sqr(cy - lat);
    if d < bestD then begin bestD := d; bestC := c; end;
  end;
  if bestC >= 0 then Result := Countries[bestC].iso else Result := '';
end;

{ ---------- Index helpers ---------- }

function LonIndex(lonE: Double): Integer;
begin
  Result := Round((FMod(lonE, 360.0) - 0.125) / AGMERRA_RES) + 1;
end;

function LatIndex(lat: Double): Integer;
begin
  Result := Round((89.875 - lat) / AGMERRA_RES) + 1;
end;

{ ---------- Build rows ---------- }

procedure AddRow(lon, lat, ha: Double; const name: string);
begin
  if NumRows >= Length(Rows) then SetLength(Rows, (NumRows + 1) * 2);
  Rows[NumRows].Lon := lon;
  Rows[NumRows].Lat := lat;
  Rows[NumRows].Ha := ha;
  Rows[NumRows].Name := name;
  Inc(NumRows);
end;

function RowCompare(const a, b: TMaskRow): Integer;
begin
  Result := CompareStr(a.Name, b.Name);
end;

procedure QSortRows(lo, hi: Integer);
var
  i, j: Integer;
  pivot: string;
  tmp: TMaskRow;
begin
  i := lo; j := hi; pivot := Rows[(lo + hi) div 2].Name;
  repeat
    while CompareStr(Rows[i].Name, pivot) < 0 do Inc(i);
    while CompareStr(Rows[j].Name, pivot) > 0 do Dec(j);
    if i <= j then
    begin
      tmp := Rows[i]; Rows[i] := Rows[j]; Rows[j] := tmp;
      Inc(i); Dec(j);
    end;
  until i > j;
  if lo < j then QSortRows(lo, j);
  if i < hi then QSortRows(i, hi);
end;

procedure SortRows;
begin
  if NumRows > 1 then QSortRows(0, NumRows - 1);
end;

procedure BuildRows(const bboxLonMin, bboxLonMax, bboxLatMin, bboxLatMax: Double;
  hasMask: Boolean; const validMask: array of Boolean);
var
  agg: array of Double;
  lonC, latC: array of Double;
  ii, jj: Integer;
  lon, lat, ha, lonE: Double;
  iso, sub, name: string;
begin
  SetLength(agg, AGM_NLAT * AGM_NLON);
  SetLength(lonC, AGM_NLON);
  SetLength(latC, AGM_NLAT);
  AggregateHarvarea(OptCropgridsNC, agg, lonC, latC);

  NumRows := 0;
  for ii := 0 to AGM_NLAT - 1 do
  begin
    lat := latC[ii];
    if (lat < bboxLatMin) or (lat > bboxLatMax) then Continue;
    for jj := 0 to AGM_NLON - 1 do
    begin
      lon := lonC[jj];
      if (lon < bboxLonMin) or (lon > bboxLonMax) then Continue;
      ha := agg[ii * AGM_NLON + jj];
      if ha <= 0 then Continue;
      lonE := FMod(lon, 360.0); if lonE < 0 then lonE := lonE + 360.0;
      if not AgmerraCellValid(validMask, hasMask, lonE, lat) then Continue;
      iso := AssignCountry(lon, lat);
      sub := SubregionOf(iso);
      if sub = '' then Continue;
      name := Format('agmerra_%.4d_%.3d_%s_%s.txt', [LonIndex(lonE), LatIndex(lat), iso, sub]);
      AddRow(lon, lat, ha, name);
    end;
  end;
  SortRows;
end;

{ ---------- Output / validation ---------- }

procedure WriteCSV(const outPath: string);
var
  f: TextFile;
  i: Integer;
begin
  ForceDirectories(ExtractFilePath(ExpandFileName(outPath)));
  AssignFile(f, outPath);
  Rewrite(f);
  WriteLn(f, 'lon,lat,wxfile,harvarea_ha');
  for i := 0 to NumRows - 1 do
    WriteLn(f, Format('%.4f,%.4f,%s,%.2f', [Rows[i].Lon, Rows[i].Lat, Rows[i].Name, Rows[i].Ha]));
  CloseFile(f);
end;

function KeyOf(lon, lat: Double): string;
begin
  Result := Format('%.3f|%.3f', [lon, lat]);
end;

function Validate(const reference: string): Integer;
var
  refKeys, genKeys: TStringList;
  f: TextFile;
  line, key, wx: string;
  parts: TStringArray;
  i, idx, shared, onlyRef, onlyGen, nameMatch, haMatch, nameShown: Integer;
  refHa, genHa: Double;
  refName: string;
  obj: TStringList;
begin
  refKeys := TStringList.Create;
  refKeys.Sorted := True;
  refKeys.Duplicates := dupIgnore;
  try
    AssignFile(f, reference);
    Reset(f);
    ReadLn(f, line);  { header }
    while not Eof(f) do
    begin
      ReadLn(f, line);
      if Trim(line) = '' then Continue;
      parts := line.Split([',']);
      if Length(parts) < 4 then Continue;
      key := KeyOf(StrToFloat(parts[0]), StrToFloat(parts[1]));
      obj := TStringList.Create;
      obj.Add(parts[2]);              { wxfile }
      obj.Add(parts[3]);              { harvarea }
      refKeys.AddObject(key, obj);
    end;
    CloseFile(f);

    genKeys := TStringList.Create;
    genKeys.Sorted := True;
    try
      for i := 0 to NumRows - 1 do
        genKeys.Add(KeyOf(Rows[i].Lon, Rows[i].Lat));

      shared := 0; onlyGen := 0; nameMatch := 0; haMatch := 0; nameShown := 0;
      WriteLn('Validating generated mask against ', reference);
      for i := 0 to NumRows - 1 do
      begin
        key := KeyOf(Rows[i].Lon, Rows[i].Lat);
        idx := refKeys.IndexOf(key);
        if idx >= 0 then
        begin
          Inc(shared);
          obj := TStringList(refKeys.Objects[idx]);
          refName := obj[0];
          refHa := StrToFloat(obj[1]);
          genHa := Rows[i].Ha;
          if refName = Rows[i].Name then Inc(nameMatch)
          else if nameShown < 10 then
          begin
            WriteLn('  name diff: ref=', refName, ' gen=', Rows[i].Name);
            Inc(nameShown);
          end;
          if Abs(refHa - genHa) < 0.01 then Inc(haMatch);
        end
        else
          Inc(onlyGen);
      end;
      onlyRef := refKeys.Count - shared;

      WriteLn(Format('reference cells : %d', [refKeys.Count]));
      WriteLn(Format('generated cells : %d', [NumRows]));
      WriteLn(Format('shared cells    : %d', [shared]));
      WriteLn(Format('only in ref     : %d', [onlyRef]));
      WriteLn(Format('only in gen     : %d', [onlyGen]));
      if shared > 0 then
      begin
        WriteLn(Format('wxfile match    : %d/%d = %.2f%%', [nameMatch, shared, nameMatch / shared * 100]));
        WriteLn(Format('harvarea match  : %d/%d = %.2f%%', [haMatch, shared, haMatch / shared * 100]));
      end;
      if (onlyRef = 0) and (onlyGen = 0) and (nameMatch = shared) and (haMatch = shared) then
        Result := 0
      else
        Result := 1;
    finally
      genKeys.Free;
    end;
  finally
    for i := 0 to refKeys.Count - 1 do refKeys.Objects[i].Free;
    refKeys.Free;
  end;
end;

{ ---------- CLI ---------- }

procedure ParseArgs;
var i: Integer; arg: string;
begin
  OptCropgridsNC := 'data/cropgrids/CROPGRIDSv1.08_cassava.nc';
  OptCountriesFile := 'data/cropgrids/ne_10m_admin_0_countries.geojson';
  OptOut := 'data/cropgrids/cassava_africa_mask_agmerra.csv';
  OptAgmerraCache := 'data/agmerra-cache';
  OptAgmerraYear := 1980;
  OptValidate := False;
  OptValidateFile := '';
  i := 1;
  while i <= ParamCount do
  begin
    arg := ParamStr(i);
    if arg = '--cropgrids-nc' then begin Inc(i); OptCropgridsNC := ParamStr(i); end
    else if arg = '--countries-file' then begin Inc(i); OptCountriesFile := ParamStr(i); end
    else if arg = '--out' then begin Inc(i); OptOut := ParamStr(i); end
    else if arg = '--agmerra-cache' then begin Inc(i); OptAgmerraCache := ParamStr(i); end
    else if arg = '--agmerra-year' then begin Inc(i); OptAgmerraYear := StrToInt(ParamStr(i)); end
    else if arg = '--validate' then
    begin
      OptValidate := True;
      if (i < ParamCount) and (Copy(ParamStr(i + 1), 1, 2) <> '--') then
      begin Inc(i); OptValidateFile := ParamStr(i); end;
    end
    else if (arg = '-h') or (arg = '--help') then
    begin
      WriteLn('Usage: build_cassava_mask [--cropgrids-nc F] [--countries-file F] [--out F]');
      WriteLn('                          [--agmerra-cache DIR] [--agmerra-year Y] [--validate [F]]');
      Halt(0);
    end
    else begin WriteLn(StdErr, 'Unknown argument: ', arg); Halt(2); end;
    Inc(i);
  end;
end;

var
  validMask: array of Boolean;
  hasMask: Boolean;
  reference: string;
begin
  DefaultFormatSettings.DecimalSeparator := '.';
  ParseArgs;

  if not FileExists(OptCropgridsNC) then
  begin
    WriteLn(StdErr, OptCropgridsNC, ' not found. Run tools/download_cropgrids first.');
    Halt(1);
  end;
  if not FileExists(OptCountriesFile) then
  begin
    WriteLn(StdErr, OptCountriesFile, ' not found. Download Natural Earth 10m admin-0 with');
    WriteLn(StdErr, '  ./download_cropgrids --natural-earth');
    Halt(1);
  end;

  LoadCountries(OptCountriesFile);

  SetLength(validMask, AGM_NLAT * AGM_NLON);
  hasMask := LoadAgmerraValidMask(OptAgmerraCache, OptAgmerraYear, validMask);
  if not hasMask then
    WriteLn('Note: AgMERRA cache ', OptAgmerraCache, ' not found; emitting all cassava ',
            'cells without a weather-availability filter.');

  BuildRows(-20.0, 52.0, -36.0, 38.0, hasMask, validMask);

  if OptValidate then
  begin
    if OptValidateFile <> '' then reference := OptValidateFile else reference := OptOut;
    Halt(Validate(reference));
  end;

  WriteCSV(OptOut);
  WriteLn(Format('Wrote %s (%d cells)', [OptOut, NumRows]));
end.
