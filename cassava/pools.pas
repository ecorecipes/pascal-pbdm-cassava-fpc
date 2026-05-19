{
  Authors:
  - Andrew Paul Gutierrez (University of California, Berkeley / CASAS Global -
    Center for Analysis of Sustainable Agriculture Systems) 
    <casas.kensington@gmail.com>
  - Luigi Ponti (ENEA - Agenzia nazionale per le nuove tecnologie, l'energia e
    lo sviluppo economico sostenibile / CASAS Global) <quartese@gmail.com>

  Copyright (C) 1999 CASAS Global (Center for the Analysis of Sustainable
  Agricultural Systems)

  SPDX-License-Identifier: GPL-3.0-or-later
}

Procedure ZeroPools;
{
	Called to zero all pools at start of season.
}
begin
	mbimmigpoola:=0.0;
	mbimmigpoolb:=0.0;
	elfimmigpoola:=0.0;
	elmimmigpoola:=0.0;
	elfimmigpoolb:=0.0;
	elmimmigpoolb:=0.0;
	edfimmigpoola:=0.0;
	edmimmigpoola:=0.0;
	edfimmigpoolb:=0.0;
	edmimmigpoolb:=0.0;
	gmimmigpoola :=0.0;
	gmimmigpoolb :=0.0;
	Taripoimmigpoola:=0.0;
	Tmanihotiimmigpoola:=0.0;
	Taripoimmigpoolb:=0.0;
	Tmanihotiimmigpoolb:=0.0;
	hjimmigpoola :=0.0;
	hjimmigpoolb :=0.0;
end;

Procedure ResetPools;
{
	Called when immigmethod=2 to update pools at end of each day.
	 	*poola=yesterday's pool = source of today's immigrants
		*poolb=today's pool = target of today's emigrants
		poola is set to poolb, poolb is set to 0.
}
begin
	mbimmigpoola:=mbimmigpoolb*0.1;
	mbimmigpoolb:=0.0;

	elfimmigpoola:=elfimmigpoolb*0.75;
	elfimmigpoolb:=0.0;

	elmimmigpoola:=elmimmigpoolb*0.75;
	elmimmigpoolb:=0.0;

	edfimmigpoola:=edfimmigpoolb*0.5;
	edfimmigpoolb:=0.0;

	edmimmigpoola:=edmimmigpoolb*0.5;
	edmimmigpoolb:=0.0;

	gmimmigpoola:=gmimmigpoolb*0.1;
	gmimmigpoolb:=0.0;

	Taripoimmigpoola:=Taripoimmigpoolb*0.25;
	Taripoimmigpoolb:=0.0;

	Tmanihotiimmigpoola:=Tmanihotiimmigpoolb*0.25;
	Tmanihotiimmigpoolb:=0.0;

	hjimmigpoola:=hjimmigpoolb*0.1;
	hjimmigpoolb:=0.0;
end;

