{ Authors: 
- Andrew Paul Gutierrez (University of California, Berkeley / CASAS Global 
	(Center for Analysis of Sustainable Agriculture Systems) 
	<casas.kensington gmail.com>
- Luigi Ponti (ENEA - Agenzia nazionale per le nuove tecnologie, l'energia e 
	lo sviluppo economico sostenibile / CASAS Global) <quartese gmail.com>

Copyright: (C) CASAS Global (Center for the Analysis of Sustainable 
	Agricultural Systems)

SPDX-License-Identifier: GPL-3.0-or-later }

procedure harvest(var itrue:boolean;var plantray : plantptrarray;
	variety:varietyrec;ModelDate:single;np:integer);
begin
	with plantray[np]^ do
	if ModelDate>=harvestdate then
	if(not done) then
	begin
		
		done:=true;
(*
		itrue:=false;
		reserves:=0.0;
		totall:=0.0;
		totalf:=0.0;
		totals:=0.0;
		tuber:=0.0;
		lai:=0.0;
		wdemand:=0.01;
		sdlsr:=1.0;
		if id<>'cas' then fill(fruwgt,variety.kfru,0.0);
*)
	end;
end;


