{
  Pluggable random number generator unit for PBDM models.

  Provides two RNG backends selectable at startup:
    rkDelphi - Delphi-compatible LCG (default, for output comparison)
    rkFPC    - FPC native Mersenne Twister

  Functions shadow System.Random and System.Randomize so existing
  call sites work unchanged — just add 'rng' as the LAST unit in
  each uses clause.

  Delphi LCG algorithm from:
    https://wiki.freepascal.org/Delphi_compatible_LCG_Random
  Multiplier 134775813 ($08088405), increment 1.

  Both backends use System.RandSeed as their state variable, so
  the existing readln(setfile, randseed) in init.pas works for
  both modes without modification.
}
unit rng;

{$mode delphi}

interface

type
  TRNGKind = (rkDelphi, rkFPC);

var
  RNGKind: TRNGKind = rkDelphi;

function Random: Extended; overload;
function Random(Range: LongInt): LongInt; overload;
procedure Randomize;

implementation

{ Delphi LCG: advance RandSeed and return raw state }
function DelphiIM: Cardinal; inline;
begin
  System.RandSeed := System.RandSeed * 134775813 + 1;
  Result := Cardinal(System.RandSeed);
end;

function Random: Extended;
begin
  case RNGKind of
    rkDelphi: Result := DelphiIM * 2.32830643653870e-10;
    rkFPC:    Result := System.Random;
  end;
end;

function Random(Range: LongInt): LongInt;
begin
  case RNGKind of
    rkDelphi: Result := Int64(Cardinal(DelphiIM)) * Int64(Range) shr 32;
    rkFPC:    Result := System.Random(Range);
  end;
end;

procedure Randomize;
begin
  System.Randomize;
end;

end.
