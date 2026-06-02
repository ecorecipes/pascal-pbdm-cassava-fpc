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

{$N+,E-}
Unit Gmite;
interface
uses globals,Modutils,rng;
Procedure Gmsetup(ncas:integer);
Procedure Greenmite(np:integer);
implementation
var
	gmrmort,FoodEaten : single;

Procedure Gmsetup(ncas:integer);
{Set species (class) variables for all populations of Green mite.}
var
	i,j,k:integer;
begin
	gmbase:= 14.65;
	delova:= 68.0;
	delgm:=  418.0; {eggs are in separate array}
	delkgm:= delgm/kgm; {******kGM =50*******}
	sexr:=   0.8; {*********************}

	{leaf age preferences}
	LeafAgePref[1]:=0.0; 
	LeafAgePref[2]:=0.2;
	LeafAgePref[3]:=0.25;
	LeafAgePref[4]:=0.25;
	LeafAgePref[5]:=0.15;
	LeafAgePref[6]:=0.07;
	LeafAgePref[7]:=0.02; 
	LeafAgePref[8]:=0.015;
	LeafAgePref[9]:=0.005;
	LeafAgePref[10]:=0.005;
	LeafAgePref[11]:=0.0;
	LeafAgePref[12]:=0.0;

{
 0          68                       154      166                          486
 |----eggs---|--------immatures--------|-preova-|--------adults ovip---------|

..... since eggs are in a separate array, the relative ages for older stages
..... within the gmn array are:....
             0                        86       98                          418
             |--------immatures--------|-preova-|--------adults ovip---------|
 vgmimm      11111111111111111111111111100000000000000000000000000000000000000
 vgmpre      00000000000000000000000000011111111100000000000000000000000000000
 vgmadlt     00000000000000000000000000000000000011111111111111111111111111111
}
	wdwvec(0.0,   86.0,  kgm, 418.0, vgmimm);
	wdwvec(86.0,  98.0,  kgm, 418.0, vgmpre);
	wdwvec(98.0, 418.0,  kgm, 418.0, vgmadlt);

(*
	Initialize default gm variables on all plants in simulation.
	(Also extra record number 101.)
*)

	for k:=1 to ncas do
	begin
		j:=deck[k];
		new(gmptrs[j]);
		
		with gmptrs[j]^ do
		begin
			gmfin:=false;
			gmgo:=false;
			for i:=1 to kova do gmova[i]:=0.0; {??????????????0.01?????????????????}
			for i:=1 to kgm do gmn[i]:=0.0;
		   	gmovnm:=0.0; gmimnm:=0.0; gmpreo:=0.0; gmadnm:=0.0; gmtot:=0.0;
		    gmdam:= 0.0; cumgmdam:=0.0;
			
			for i:=1 to 4 do gmnums[i]:=0.0;
			gdelt:=0.0; tgdelt:=0.0; cmbrmort:=0.0; gmdays:=0.0;
			npccon:=0.0; eggr:=0.0; deadleaf:=0.0; leafmass:=0.0;
	    	gmsd :=1.0; 
			goTaripo:=false;
			goTmanihoti:=false;
		end;{gmptrs[j]^}
	end; {for k=}

	{setup an extra record to store sampled means}
	if firstyear then 	new(gmptrs[101]);
	gmptrs[101]:=gmptrs[deck[1]];
end;

Procedure Gmcnt(np:integer);
var
	i:integer;
begin
	with gmptrs[np]^ do
	begin
		gmovnm := sum(gmova,1,kova )*delova/kova;
		gmimnm := dot(gmn,vgmimm,kgm )*delkgm;
		gmpreo := dot(gmn,vgmpre,kgm )*delkgm;
		gmadnm := dot(gmn,vgmadlt,kgm )*delkgm;
		gmtot  := gmovnm+gmimnm+gmadnm+gmpreo;

		{Check for gone after 200dd.}
		if ((tgdelt >200.0)and (gmtot <= 1.0))then
		begin
			for i:=1 to kgm do
			begin
				gmn[i]:=0.01;
				gmova[i]:=0.01;
			end;
			//gmovnm:=0.0;
			//gmimnm:=0.0;
			//gmpreo:=0.0;
			//gmadnm:=0.0;
			//gmtot :=0.0;
 			gmfin:=true;
 			with casPtrs[np]^ do gmthisplant:=false;
			tgdelt:=0.0;

		end;

		gmnums[1]:=gmovnm; gmnums[2]:=gmimnm; gmnums[3]:=gmpreo; gmnums[4]:=gmadnm;

		{Estimate the mass of 4 mite stages.  Assume ova wgt=0.1micro grams, adults=1.0, linear interpolate for
		 immatures with mean age>ova=43 and for preovs with mean age>ova=92.}
		gmWgt[1]:=gmovnm*0.1;
		gmwgt[2]:=gmimnm*(43.0/86.0); {They become adults 98 dd after ova.}
		gmwgt[3]:=gmpreo*(86.0/98.0);
		gmwgt[4]:=gmadnm;
		gmtotwgt:=0.0;
		for i:=1 to 4 do gmtotwgt:= gmtotwgt+gmwgt[i];
	end;
end; { Gmcnt }
        

Procedure Gmdem(np:integer);
(*
    gmage = array of transit times for each gm instar
              0                        86       98                          418
             |--------immatures--------|-preova-|--------adults ovip---------|
 Damage function for immatures increases linearly from 0 to damrat,
 then is constant for preovs and adults.

*)
var
	damrat,slope:single;
	i,k1,k2:byte;
begin
	{damage by immatures}
	with gmptrs[np]^ do
	begin
		damrat:= 0.0002; {******gm per dd -- june98 ????0.00002}
		gmdam:=  0.0;
	{
	 The immatures will be indexed by k1 to k2.
	 }
		k1:= 1;
		k2:= round(kgm*(154.0/ 418.0));

		slope:=damrat/(k2-k1);
		for i:=1 to kgm do
		begin
			gmdam:= gmdam + gmn[i]*(vgmimm[i]*slope*(i-1)+(vgmpre[i]+vgmadlt[i])*damrat);
		end;

		{total population demand rate per degree day}
		gmdam:=gmdam*delkgm;
		cumgmdam:=cumgmdam+gmdam;
	end;
end;

	
Procedure Gmdd(np:integer);
begin
	with gmptrs[np]^ do	
	begin
		Daydegrees(modelday,gmbase,gdelt,ddb);
		tgdelt:=tgdelt+gdelt;
	end;
end;

Procedure Gmsdr(np:integer);
{
 Update the s/d ratio.
}
	var dmtot:single;
begin
	with gmptrs[np]^ do
	begin
		gmsd:=1.0;
		dmtot:=gmdam*gdelt;
		if(dmtot > 0.0)then gmsd := min(FoodEaten/dmtot, 1.0);
	end;
end; {Gmsdr }

Procedure Gmmor(np:integer);
(*
 gmsim   create mortality vector - gmplr using gmsd stress and
 apply rain mortality using variable precip.
*)
var
   i,kadl:integer;
   rainPathlx,rain,muTemp,T2,T3,T4,T5:single;
begin
{some convenient calculations} 
	T2:=Tmean*Tmean;
	T3:=T2*Tmean;
	T4:=T3*Tmean;
	
	with gmptrs[np]^ do
	begin
	{ rain and Temp mort (see yaninek's thesis) }
	{apply rain (fungus) and temp mortality directly outside of delay}
		rainPathlx:= 1.0;
		rain:=precip;
		if FMin then rainPathlx:= exp(-0.025*rain);  {*****was 0.025}
		muTemp:=zerone(0.000012*T4 - 0.001187*T3 + 0.042353*T2 - 0.666530*Tmean + 3.938533);
//writeln('FMin', fmin:10, tb, rainpathlx:25:12, tb, precip:10:4); readln;
		rain:=0.0;
	{ apply abiotic mortality to active stages}
		for i:=1 to kgm do gmn[i]:= gmn[i]*rainPathlx*(1.0-muTemp);
		
	{ apply abiotic egg mortality}
		for i:=1 to kova do gmova[i]:=gmova[i]*rainPathlx*(1.0-muTemp);

{loop to do sd mort, -- to move adlt mites from gmn array to gmimmigpoolb as f(gmsd). ke}

		kadl:=round((98.0/delgm)*kgm);
		for i:=1 to kgm do
		begin
			if ((immigmethod=2) and (i>=kadl)) then
				gmimmigpoolb:=gmimmigpoolb+gmn[i]*(1.0-gmsd);
			gmn[i]:=gmn[i]*gmsd;
		end;
	end;
end; {Gmmor }

Procedure Gmimmig(np:integer);
var
	meanin:single;
	kadl,i:integer;
begin
	with casPtrs[np]^ do
	begin
		if gmthisplant then
		begin
		{ 1 source unknown, 2 daily migrant pool }
			if immigmethod=1 then meanin:= gmins/delkgm;
			if immigmethod=2 then  meanin:= gmImmigpoola/ncas;
		end;

		if not(gmthisplant)then meanin:=gmins/delkgm;
		meanin:=meanin*ncas/100.0; {compensate for variation in plant density 12-03-97}

		if meanin>0.0 then
		begin
{			xin:=fran(meanin,gminspcnt);}
			gmthisplant:=true;
			kadl:=round((98.0/delgm)*kgm);

			with gmptrs[np]^ do for i:=kadl to kgm do
			begin
				gmn[i]:=gmn[i] + meanin/(kgm-kadl+1); {Distribute equal parts of immigs into adlt cells.}
			end;  
		end;
	end; {with casPtrs[np]^ do}
end;

Procedure Gmdyn(np:integer);

(*
 The following two functions implement the effect of nitrogen stress
 on fecundity and developmental time.
 Npc stands for N % consumed.
*)

Function Ffec(Npc:single):single;
{Assumes leaf Nitrogen % is from 0.0 to 5.0}
	begin 
		ffec:= min(1.1, (0.22*Npc)) { from Wermelinger et al.-- APG};
		ffec:=1.0; {**************************************************a}
	end;

Function Fdev(Npc:single):single;
{Assume Npc is from 0.0 to 5.0}
	begin	
		//fdev:=max(1.0, (1.63-0.13*Npc));
		fdev:=1.0; {not implimented }	
	end;
var
   a,bn1,ff,gmout,immin,nadlts,q,ovout:single;
	i,ii:integer;   
begin
	{ calculate temperature effects q -- left skewed - normalized 18-34C}
		ff:=max(0.0,(-0.0072*Tmean*Tmean*Tmean - 0.1295*Tmean*Tmean + 22.103*Tmean - 315.34)/45.4);

	with gmptrs[np]^ do
	begin
		{ new eggs}
		bn1:=0.0;
		nadlts:=0.0;
		ii:=0;
		for i:=1 to kgm do
		begin
			if vgmadlt[i] > 0.0 then {wvec for adults}
			begin
				ii:=ii+1;
				a:=ii + 0.5; {ii = kcmb= 11.75 -> 50}
		{ bn1 is eggs per day at 24C correct delk to day width }
				bn1:= bn1 + 0.5*7.1*a/(1+power(1.325,a))*(gmn[i]+ 0.001)*vgmadlt[i];
				nadlts:=nadlts + gmn[i]*vgmadlt[i]*delkgm;
		//writeln(i:10,tb,'a  =', a:10:3,tb,bn1:10:3,tb,nadlts:10:4); readln;
			end
			else bn1:=0.0;
		end;
 {eggs delay}
		bn1:=bn1 * ff * gmsd * sexr * delkgm {* ffec(npccon)}; {temp effect, sd, sexratio and nitrogen effect}
		DelayNoPLR(bn1,ovout,gmova,delova,gdelt,kova);
//		deltim :=gdelt/fdev(npccon);               			   {nitrogen effect} //????  not used?  05/10/06  ????????????
 {actives delay}
		immin:=ovout*delova/kova; {output of gmova becomes input of gmn}
		DelayNoPLR(immin,gmout,gmn,delgm,gdelt,kgm); 
	end;
end; {Gmdyn }

Procedure Gmsup(np:integer);
(*
 The source of food is cassava leaves in array folwgt.
 Array LeafMass6 represents the mass contained in  6 age categories
 of leaves.
 Array LeafAgePref has 12 values of preference corresponding to those
 12 age categories.
 Variable FoodAvail is the dot product of the leaf mass in LeafMass12 and
 the preferences in LeafAgePref (the weighted sum).

 LeafAgePref is initialised in Gmsetup.
*)
var
   k1,k2:integer;
   sumnit,sumwgt,kinc,FoodAvail,a,loss,mort: single;
   q : array[1..12] of single;
	folmort  : Single100;
	d1,d2,d3:double;
	i,j,k:integer;
begin
	with gmptrs[np]^ do with casPtrs[np]^ do	
	begin
		for i:=1 to kfol do folmort[i]:=0.0;
		for i:=1 to 12    do q[i]:=0.0;
		npccon:=0.0;

 		FoodAvail:=0.0;
		FoodEaten:=0.0;

	    for i:=1 to 12 do FoodAvail:= FoodAvail + LeafMass12[i]*LeafAgePref[i];
		if(FoodAvail > 1.0E-10)then
		begin
			{ q[i] is fraction of FoodAvail in ith age. }
			for i:=1 to 12 do 
			begin
				d1:=leafmass12[i];
				d2:=leafagepref[i];
				d3:=foodavail;
				q[i]:= d1*d2/d3; {avoid 205 crash}
			end;
			
		{ a = apparency rate}
			a := 0.6;
		{gmdam = mite damage (from gmdem) as rate g per degree day.}
			b := gmdam*gdelt;
			if b< 1.0E-20 then b:=0.0;
			if((b >0.0) and (gdelt>0.0))then
			begin
				FoodEaten := (1.0 - expo(-a*FoodAvail/b))*b;
				if(FoodEaten = 0.0) then fill(folmort,kfol,0.0);
				{
				 Fill the kfol cells of FolMort with 12 values of mort
				 corresponding to 12 ages, their preferences and
				 proportions of damage.
				 This is the negative feedback to the cassava plant.
				}

				k2:=0;
				kinc:=kfol/12;
				for j:=1 to 12 do
				begin
					mort:=0.0;
					loss:= q[j]*FoodEaten; 
					if(LeafMass12[j]>0.0)then mort:= loss/LeafMass12[j];
					k1:=k2+1;
					k2:=trunc(j*kinc)+1;
					if k2>kfol then k2:=kfol;
					for k:=k1 to k2 do folmort[k]:= mort;
				end;
				sumnit:=0.0;
				sumwgt:=0.0;
				for k:=1 to kfol do	
				begin
					if folmort[k] < 0.0 then folmort[k]:=0.0;
					gmfood[k]:=gmfood[k] + folwgt[k]*folmort[k]; {food++}
					sumnit   :=sumnit    + folnit[k]*folmort[k];
					sumwgt   :=sumwgt    + folwgt[k]*folmort[k];
					folwgt[k]:=folwgt[k] * (1.0-folmort[k]);     {fol--}
					{folnum[k]:=folnum[k] * (1.0-folmort[k]);}
					folnit[k]:=folnit[k] * (1.0-folmort[k]);
				end;
				{(% n consumed)}
				if sumwgt>0.0 then npccon:=(sumnit/sumwgt)*100.0 else npccon:=0.0;
			end; {if((b >0.0) and (gdelt>0.0))}
		end; { (FoodAvail > 0.0) }
		end;
{
 Food is also used as input to array gmfood which is a record of leaf mass
 consumed by gm.  Gmfood is aged in parallel with the cassava folwgt array 
 in subroutine nplant.  Each day the sum of the array is the amount of 
 mass missing from the existing leaves and is used to modify lai in nplant.
 }
end; {Gmsup}


Procedure Greenmite(np:integer);  
(*
  Green mite simulation called from Models once each day for each
  plant.
  Gm's food source is leaves generated by cassava.
  Gm affects cassava through leaf mass reduction;
*)
var 
	ran:single;
begin
{Choose randomly if this population gets immigrants.}
	ran:=random;
	if ran<=gmimmigprob then gmimmig(np);
	
	with casPtrs[np]^ do if gmthisplant then
	with gmptrs[np]^do
	begin
		gmdd(np);
		gmcnt(np);
		gmdem(np);
		gmsup(np);
		gmsdr(np);
		gmmor(np);
		if gdelt>0.0 then gmdyn(np);
		gmdays:=gmdays+gmadnm;
 	end;
end;
end.
