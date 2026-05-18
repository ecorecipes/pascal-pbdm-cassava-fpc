{ Authors: 
- Andrew Paul Gutierrez (University of California, Berkeley / CASAS Global 
	(Center for Analysis of Sustainable Agriculture Systems) 
	<casas.kensington gmail.com>
- Luigi Ponti (ENEA - Agenzia nazionale per le nuove tecnologie, l'energia e 
	lo sviluppo economico sostenibile / CASAS Global) <quartese gmail.com>

Copyright: (C) CASAS Global (Center for the Analysis of Sustainable 
	Agricultural Systems)

SPDX-License-Identifier: GPL-3.0-or-later }

Procedure Setsvar;
(*
Set limits on seasonal variation values for multi-season runs.
For example if Nseasonalvar = 75 that means that at the start of each
season the mean value of SoilN for the field will be set to the
initial SoilN  value from the setup file  +- 75%.

There may be further variation within the field during each season
since levels of SoilN in each part of the field grid will be set relative
to the SoilN chosen at the start of the season.

Insect immigrations: If a plant receives immigrants I call that an
immigration event.  There are variables controlling the probability of
an immigration event for each plant each day.  There are other variables
that control the number of adults in such an event.
(There will be an alternative to this method when we implement the source
of immigrants as the pool of former emigrants.  7/4/96)

*)

begin
	NPlantsseasonalvar:=100; {Number of plants each season}
	Nseasonalvar:=		75;  {SoilN}
	Oseasonalvar:=		75;  {Org : soil organic N}
	Phseasonalvar:=		75;  {phosphate} {currently not used 7/4/96}
	Wseasonalvar:=		75;  {soil water}
	Plseasonalvar:=		15;  {plant spacing} {using 75 allows too much crowding?}
	Roseasonalvar:=		5;   {row spacing}
	CMBstartseasonalvar:=0;  {cmb start +- 30 days}
	CMBnm1seasonalvar:=	75;  {number of initial cmb}
	CMBprobseasonalvar:=75;  {prob. of immigr. event for each plant each day}
	CMBimmseasonalvar:=	75;  {number immigrating to a plant}
	EDstartseasonalvar:=20;  {Epi. divers. start +- 20 days}
	EDprobseasonalvar:=	75;  {prob. of immigr. event for each plant each day}
	EDimmseasonalvar:=	75;  {number of e.d. immigrants each day}
	ELstartseasonalvar:=20;  {Epi. lopezi start +- 20 days}
	ELprobseasonalvar:=	75;  {prob. of immigr. event for each plant each day}
	ELimmseasonalvar:=	75;  {number of e.l. immigrants each day}
	GMstartseasonalvar:=20;  {green mite start +- 20 days}
	GMprobseasonalvar:=	75;  {prob. of immigr. event for each plant each day}
	Taripoprobseasonalvar:=	75;  {prob. of immigr. event for each plant each day}
	Tmanihotiprobseasonalvar:=75;{prob. of immigr. event for each plant each day}
	Taripoalphavar:=	75;  {alpha of Pred1}
	Tmanihotialphavar:=	75;  {alpha of Pred2}
end;


