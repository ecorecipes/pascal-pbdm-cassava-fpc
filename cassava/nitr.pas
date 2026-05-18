{ Authors: 
- Andrew Paul Gutierrez (University of California, Berkeley / CASAS Global 
	(Center for Analysis of Sustainable Agriculture Systems) 
	<casas.kensington gmail.com>
- Luigi Ponti (ENEA - Agenzia nazionale per le nuove tecnologie, l'energia e 
	lo sviluppo economico sostenibile / CASAS Global) <quartese gmail.com>

Copyright: (C) CASAS Global (Center for the Analysis of Sustainable 
	Agricultural Systems)

SPDX-License-Identifier: GPL-3.0-or-later }

Unit Nitr;
interface
uses globals,Modutils,spatial;
Procedure Ndemand(var plant:plantrec; vty:varietyrec);
Procedure Nsupply(var plant:plantrec; var nuptkpot:single);
Procedure Nratio(var plant:plantrec;nuptkpot:single);
Procedure Nplant(var plant:plantrec;variet:varietyrec);
{Procedure Nresuptk(var plant:plantrec; var nuptk:single);}
Function Nav(plant:plantrec):single;
procedure nused(plant:plantrec);
Procedure orgnupd;

implementation

function nav(plant:plantrec):single;
{get n available from ncells overlapped with plant space}
{Each Ncell is 1/4 of a sq. meter.}
{Units: nav=g?  =g/m^2?}
var
	tota,ac:single;
	frac,ntot:single;
	i1,i2,j1,j2,i,j:integer;
begin
	with plant do
	begin
(*	sidel,sidea,sider,sideb        : single;{sides of plant area in field}*)
{Set i1.., j1.. , the indeces of Narray cells near this plant.}
{these must accord with dimensions of narray[22,22].}

{FEB 5 96.  ON LEFT AND TOP EDGES SIDEL AND SIDEA CAN BE <0.0.  TO MAP THEM INTO
 NARRAY INDECES TRUNCATION DOESN'T WORK.  TEST THEM FOR <0.0.}
		IF SIDEL<0.0 THEN i1:=1 ELSE	i1:=trunc(sidel*2)+2;
		i2:=minint(trunc(sider*2)+2, 22);
		IF SIDEA<0.0 THEN J1:=1 ELSE   	j1:=trunc(sidea*2)+2;
		j2:=minint(trunc(sideb*2)+2, 22);
		tota:=0.0;
		ntot:=0.0;
		for i:=i1 to i2 do
		for j:=j1 to j2 do
		begin
			ac:=0.01 {cellarea(i,j,sidel,sidea,sider,sideb)}; {overlap in cell(i,j)}
			frac:=ac/0.25; {fraction of cell area in overlap}
			ntot:=ntot+frac*narray[i,j];
			tota:=tota+ac;		
		end;
	end;
	nav:=ntot;
 end;


Procedure Ndemand(var plant:plantrec; vty:varietyrec);
var
    ndl : single;
begin
    with plant do
    begin
        ndl   :=vty.ndlmul*dl;
        nds   :=0.009*ds;
        ndr   :=0.007*dr;
        ndtube:=0.005*dmtuber;
        ndres :=0.1*ndl;
        ndlsr :=ndl+nds+ndr;
        ndtot :=(ndlsr+ndres+ndtube)*wsd;
    end;{with plant}
end;{ndemand}


Procedure Nsupply(var plant:plantrec; var nuptkpot:single);
var
   a,solni:single;
begin
	with plant do
	begin
		a:= 1.0-expo(-0.8047*lai);
		if (id='Cass')then
			if a<=0.01 then a:=0.01; {cas limit=0.01}
		if (id<>'Cass')then
			if a<=0.05 then a:=0.05; {corn,cowp limit=0.05}
		if a<prevanit then a:=prevanit;
		prevanit:=a;
		{get n available from ncells overlapped with plant space}
		solni:= a* nav(plant);
		nuptkpot:=0.0;
		if(ndtot > 0.0)then nuptkpot:=ndtot*(1.0-expo(-solni/ndtot));
		if nuptkpot<0.00001 then nuptkpot:=0.0;
	end;
end;


Procedure Nratio(var plant:plantrec;nuptkpot:single);
{   stem cutting: 0.95% n, 80% can be used }
{ If nuptkpot < ndtot uses some reserves.}
{        ndtot :=(ndlsr+ndres+ndtube)*wsd;}
{ Set nsdlsr.}
var
   nitro:single;
begin
	with plant do
	begin
		nsdlsr:=1.0;
		nitro:=nuptkpot;
		nresut:=0.0;
		if (nitro < ndtot)then
		begin {   use 10% of reserves }
			if (id='Cass')then    nresut:=min(0.1*nres,ndtot-nitro)
			else  nresut:=min(0.3*nres,ndtot-nitro);
			nitro:=nitro+nresut;
			nres:=nres-nresut;
		end;
		if(ndres+ndlsr+ndtube)>0.0000001 then
		nsdlsr:= min(nitro/(ndres+ndlsr+ndtube),1.0)
		else nsdlsr:=1.0;
		if nsdlsr<0.00001 then nsdlsr:=0.00001;
	end;{with plant}
end;


Procedure Nplant(var plant:plantrec;variet:varietyrec);
{   manage the allocation in the plant }
var
	ntotlf,ntotst,ntotrt,nintub,ninres:single;
	nincl,nincs,nincr:single;
        nlfex,nstex,nrtex:single;

begin

  with plant do
  with variet do
  begin
	{compute input increments }
	nincl :=folinmass *0.05 * nsdlsr*sdlsr ;
	nincs :=nds *sdlsr*nsdlsr;
	nincr :=ndr *sdlsr*nsdlsr;

	{ call delay for nitrogen in leaves,stems,roots }
	DelayNoPLR(nincl, nlfex, folnit,delfol,dda,kfol);
	DelayNoPLR(nincs, nstex, stnit ,delstem,dda,kstem);
	DelayNoPLR(nincr, nrtex, rtnit ,delroot,dda,kroot);

	ntlout:=ntlout+nlfex*delkfol;
	ntsout:=ntsout+nstex*delkstem;
	ntrout:=ntrout+nrtex*delkroot;
	{  total n in tissues }
	ntotlf:=sum(folnit,1,kfol)*delkfol +ntlout;
	ntotst:=sum(stnit,1,kstem)*delkstem +ntsout;
	ntotrt:=sum(rtnit,1,kroot)*delkroot +ntrout;

	nintub:=ndtube *sdlsr*nsdlsr;
	ninres:=ndres  *sdlsr*nsdlsr;
	ntuber:=ntuber+nintub;
	nres :=nres +ninres;
	nveg :=ntotlf+ntotst+ntotrt+ntuber+nres;

	nuptk:=nincl+nincs+nincr+nintub+ninres+ndwt-nresut;
	if ncas=1 then totnuptk:=totnuptk+nuptk;
  end; {with plant, variet}
end;


procedure nused(plant:plantrec);
{subtract n used from ncells overlapped with plant space}
{Each Ncell is 1/4 of a sq. meter.}
var
	ac:single;
	frac,navail,nincell,ndecr:single;
	i1,i2,j1,j2,i,j:integer;
begin
	navail:=nav(plant); {g/sqm?}
	with plant do
	begin
{Set i1.., j1.. , the indeces of Narray cells near this plant.}
		i1:=trunc(sidel*2)+2;
		i2:=minint(trunc(sider*2)+2, 22);
		j1:=trunc(sidea*2)+2;
		j2:=minint(trunc(sideb*2)+2, 22);
		{The i1.., j1.. are indeces of Narray cells.}
		for i:=i1 to i2 do
		for j:=j1 to j2 do
		begin
			ac:=0.01 {cellarea(i,j,sidel,sidea,sider,sideb)};
			frac:=ac/0.25; {fraction of cell area in overlap}
			nincell:=frac*narray[i,j]; {N in overlap area}

			ndecr:=0.0;
			if navail>0.0 then 
				ndecr:=nuptk*nincell/navail;{fraction of nuptk from cell i,j}
			narray[i,j]:=narray[i,j]-ndecr;
		end;
	end;
 end;


Procedure orgnupd;
{Called once daily to update org n in each cell of narray}
{ nappl := n fertilizer applied [g/m2], 50% become available for the plant }
{ org := organic matter (5%n) in the soil. 1% becomes available during a season }
var
	t1,t2,org,delorg,newn:single;
	ix,iy:integer;
begin
	t1:=oarray[10,10]+oarray[10,11]+oarray[11,10]+oarray[11,11]; //used when ncas=1

	for ix:=1 to 22 do for iy:=1 to 22 do 
   	begin
		org:=oarray[ix,iy];
		delorg:=org*0.000027; {decrements org by .001 over 366 days}
		org:=org-delorg;
		if org<0.0 then org:=0.0;
		oarray[ix,iy]:=org;
   		newn:=min(narray[ix,iy]+delorg*0.05,150.0); {.05 is N available.}
   		narray[ix,iy]:=newn;
   	end;
	if ncas=1 then
	begin
		t2:=oarray[10,10]+oarray[10,11]+oarray[11,10]+oarray[11,11];
		tdelorg:=t1-t2+tdelorg;	
	end;
end; 
end.

