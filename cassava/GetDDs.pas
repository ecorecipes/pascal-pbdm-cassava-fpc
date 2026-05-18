{ Authors: 
- Andrew Paul Gutierrez (University of California, Berkeley / CASAS Global 
	(Center for Analysis of Sustainable Agriculture Systems) 
	<casas.kensington gmail.com>
- Luigi Ponti (ENEA - Agenzia nazionale per le nuove tecnologie, l'energia e 
	lo sviluppo economico sostenibile / CASAS Global) <quartese gmail.com>

Copyright: (C) CASAS Global (Center for the Analysis of Sustainable 
	Agricultural Systems)

SPDX-License-Identifier: GPL-3.0-or-later }

procedure getdds( modelday:integer;rday:single;
	var variety:varietyrec;var ray:plantptrarray;np:integer);
var
	i:integer;
{Get today's dda for each plant.}
{ray = array of pointers to plant records}
begin
	with variety do	 {same dda for all varieties addumed}
	dda:=max(0.0, 106.8*(0.0095*(Tmean-14.85)/(1 +power(1.6,(Tmean-33.55)))/1.209)); 
	//daydegrees(modelday,base,dda,ddb);
	for i:=1 to np do with ray[deck[i]]^ do 
	if plantdate<=rday then tdda:=tdda+variety.dda;
end;

