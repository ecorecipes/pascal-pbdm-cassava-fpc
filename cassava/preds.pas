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

Unit preds;
interface
uses globals,Modutils;
Procedure predsetup;
Procedure greenpreds(np:integer);

implementation
var
pa,PreyFound:single;

function G(age:real):real;
{ converts green mite prey older than eggs to 'egg equivalents'.}
	begin 	
	G:=power(10.0,(0.00496*age)); 
	end;

Procedure predsetup;
{Set species parameters for 2 mite predators.}
{	Tariporec,Tmanihotirec : predvarietyrec;}
var
	i,j,k:integer;
begin
(* change logic so the initialization code is written only once and this
routine is parameterized with (var prec:predvarietyrec;var pptrs: predarray);
and called : Taripoinfield then predsetup(Tariporec,Taripoptrs);
*)
(* T. aripo 
 0    20.4   33.4   50.65    66.13  116.7    226                   260.6
 |-ova-|-larv-|-proto-|-deuto-|-preov-|--ovip--|--------adults -----|
*)

	if Taripoinfield then
	with Tariporec do
	begin
		predbase := 11.4;
		tpeak:=12.0; {confirms feeding experiments of MUTISYA et al. 2014}
		delpred:=260.6;
		predage[1]:=20.4;  {egg}
		predage[2]:=33.41; {larva}
		predage[3]:=50.65; {protonymph}
		predage[4]:=66.13; {deutonymph}
		predage[5]:=116.7; {preovip}
		predage[6]:=226.11;{ovips}
		predage[7]:=260.6; {max age}
{ growth 
		{preddem units are (prey egg equivalents)/dd.}
		preddem[1]:=0.0;
		preddem[2]:=0.16; {micrograms per dd  but it is 9.4 eggs over the laval stage at 25C}
		preddem[3]:=0.20; { 15.6 eggs over protonymph at 25C}
		preddem[4]:=0.37; { 25 eggs over duteronymph at  25C}
		preddem[5]:=0.36; { 89 eggs overpreoviposition fem adult at 25C}
		preddem[6]:=0.39; {191 eggs over fem adult in ovip period at 25C}
		preddem[7]:=0.3;  { 95 eggs over fem adult in post-oviposition at 25C} 
		predfec:= 2*0.105 {0.058 ??????????????2??????????????????????????????????}; 
		predsexr1:=0.66; {2 fems:1.0 males}
		rhlim:= 20.0;
		sdmin:= 0.4; {for pollen effect on survival and reproducction}
		delkpred:=delpred/kpred;
		predalphain:= 1.2;
		predalpha:= 1.0;
		wdwvec(0.0,       predage[1],kpred,predage[7], veggs);
		wdwvec(predage[1],predage[2],kpred,predage[7], vlarva);
		wdwvec(predage[2],predage[3],kpred,predage[7], vproto);
		wdwvec(predage[3],predage[4],kpred,predage[7], vdeuto);
		wdwvec(predage[4],predage[5],kpred,predage[7], vpreov);
		wdwvec(predage[5],predage[6],kpred,predage[7], vovipad);
		wdwvec(predage[6],predage[7],kpred,predage[7], vadult);
		wdwvec(predage[1],predage[7],kpred,predage[7], vreport);

	end;
	

(* T. manihoti
  0    28.9    44.1   63.34   82.44   136   290.82          342.05
  |-ova-|-larv-|-proto-|-deuto-|-preov-|--ovip--|-------adults --|
predage 1      2       3       4       5        6                7
*)
	if Tmanihotiinfield then
	with Tmanihotirec do
	begin
		predbase := 6.64;
		tpeak:=13.2;
 		delpred:= 342.05;
		predage[1]:=28.9;   {egg}
		predage[2]:=44.1;   {larva}
		predage[3]:=63.34;  {protonymph}
		predage[4]:=82.44;  {deutonymph}
		predage[5]:=136.05; {preovip}
		predage[6]:=290.82; {ovips}
		predage[7]:=342.05; {max age }
		{preddem units are prey (eggs+larvae)/dd (may attack own also).}
		preddem[1]:=0.0;
		preddem[2]:=0.22; {micrograms per dd}{ 16.0 over laval stage at 25C}
		preddem[3]:=0.21;  { 18 eggs over protonymph stage at 25C}
		preddem[4]:=0.26;  { 23 eggs over duteronymph stage at  25C}
		preddem[5]:=0.41;  { 98 eggs over preoviposition at 25C}
		preddem[6]:=0.37;  {257 over ovip period at 25C}
		preddem[7]:=0.27;  { 63 over post-oviposition at 25C} 
		predfec:= 2* 0.064 {??????????2???????????}; 

		predsexr1:=0.66; {2 fems:1.0 males}
		rhlim:= 40.0;
		sdmin:= 0.0; {no pollen effect for Tmanihoti}
		delkpred:=delpred/kpred;
		predalphain:=1.0;
		predalpha:=1.0;
		wdwvec(0.0       ,predage[1],kpred,predage[7], veggs);
		wdwvec(predage[1],predage[2],kpred,predage[7], vlarva);
		wdwvec(predage[2],predage[3],kpred,predage[7], vproto);
		wdwvec(predage[3],predage[4],kpred,predage[7], vdeuto);
		wdwvec(predage[4],predage[5],kpred,predage[7], vpreov);
		wdwvec(predage[5],predage[6],kpred,predage[7], vovipad);
		wdwvec(predage[6],predage[7],kpred,predage[7], vadult);
		wdwvec(predage[1],predage[7],kpred,predage[7], vreport);
	end;

(*
	Initialize default pred variables on all plants in simulation.
	(Also extra record number 101.)
*)
                                                                                                                                                          
	if Taripoinfield then
	begin	
		for k:=1 to ncas do
		begin
			j:=deck[k];
			new(Taripoptrs[j]);
			with Taripoptrs[j]^ do with Tariporec do
			begin
				fill(prednums,kpred ,0.0);
				predov:=0.0;
				predlarv:=0.0;
				predproto:=0.0;
				preddeuto:=0.0;
				predpreovip:=0.0;
				predovipad:=0.0;
				predad:=0.0;
				for i:=1 to 7 do predn[i]:=0.0;
				predsd:=0.0;
				preddd:=0.0;
				tpreddd:=0.0;
				predsfin:=false;
				predsexr:=predsexr1;
				predreport:=0.0;
			end;{predarray[j]^}
		end; {for k=}

		{setup an extra record in slot 101 to store sampled means}
		if firstyear then new(Taripoptrs[101]);
		j:=deck[ncas];
		Taripoptrs[101]:=Taripoptrs[j];
	end;

	if Tmanihotiinfield then
	begin
		for k:=1 to ncas do
		begin
			j:=deck[k];

			new(Tmanihotiptrs[j]);
			with Tmanihotiptrs[j]^ do with Tmanihotirec do
			begin
				fill(prednums,kpred ,0.0);
				predov:=0.0;
				predlarv:=0.0;
				predproto:=0.0;
				preddeuto:=0.0;
				predpreovip:=0.0;
				predovipad:=0.0;
				predad:=0.0;
				for i:=1 to 7 do predn[i]:=0.0;
				predsd:=0.0;
				preddd:=0.0;
				tpreddd:=0.0;
				predsfin:=false;
				predsexr:=predsexr1;
				predreport:=0.0;
			end;{predarray[j]^}
		end; {for k=}

		{setup an extra record in slot 101 to store sampled means}
		if firstyear then new(Tmanihotiptrs[101]);
		j:=deck[ncas];
		Tmanihotiptrs[101]:= Tmanihotiptrs[j];
	end;
end;

Procedure predcount(predvar:predvarietyrec;var pptr: predptr);
begin
	with pptr^ do with predvar do
	begin
		predn[1]:=	dot(prednums,veggs,  kpred)*delkpred;
		predn[2]:=	dot(prednums,vlarva, kpred)*delkpred;
		predn[3]:=	dot(prednums,vproto, kpred)*delkpred;
		predn[4]:=	dot(prednums,vdeuto, kpred)*delkpred;
		predn[5]:=	dot(prednums,vpreov, kpred)*delkpred;
		predn[6]:=	dot(prednums,vovipad,kpred)*delkpred;
		predn[7]:=	dot(prednums,vadult, kpred)*delkpred;
		predreport:=dot(prednums,vreport,kpred)*delkpred;
	end;
end; { predcount }

Procedure preddemand(predvar:predvarietyrec;
 pptr: predptr;
 var demtot:single);
 var
	 i:byte;
begin
	with pptr^ do with predvar do
	begin
		demtot:=0.0;
		for i:=1 to 7 do demtot:= demtot + predn[i]*preddem[i];
		demtot:= demtot*preddd;  
	end;
end;

Procedure predsdr(var pptr:predptr;gmmort,Pa,demtot:single);
{
 S/D ratio
 Pa=egg equivalents of mites killed
 }
begin

	with pptr^ do
	begin
		predsd:=0.0;
		if(demtot > 0.0)then predsd := min((gmmort*Pa)/demtot,1.0);
	end;
end; {predsdr }

Procedure Gmavail(np:integer;var PA:single);
{
How many gm available as prey on plant np.
Return the egg equivalents as PA= prey available.
}
var
	age:extended;
	i:integer;
begin
	PA:=0.0;
	with gmptrs[np]^ do
	begin
		{
		Sums the mass of prey available in ages > egg as egg equivalents using function G:
		}
		PA:=0.0;
		for i:=1 to kgm do
		begin
			age:=i*delkgm; 					{age > egg stage}
			if age > 98.0 then age:= 98.0; 	{gm same size after age 98}
			PA:=PA+gmn[i]*G(age);
		end;
		PA:=PA*delkgm;
		for i:=1 to kova do PA:=PA+gmova[i]*delova/kova;
	end;
end;

Procedure MiteMort(np:integer;MiteSurv:single);
{
Apply mort of one or both preds.
}
var
	i:integer;
begin
{PA=prey avail = total mass of gm}
	with gmptrs[np]^do
	begin

		for i:=1 to kgm do  gmn[i]:= gmn[i]*MiteSurv;
	
		for i:=1 to kova do gmova[i]:= gmova[i]*MiteSurv;
		
	end; {with gmptrs[}
end;


procedure PredMort(predvar:predvarietyrec; var pptr:predptr);
{
Mortality due to  rel humidity.
}
var
	lx:single;
	i:word;
begin
	with predvar do with pptr^ do
	begin
		if (rhmean<=rhlim) then lx:=0.1
		else
		lx:=max(0.0, exp(-2.0/(rhmean-rhlim)));
		for i:=1 to kpred do prednums[i]:= prednums[i]*lx;	
	end;

end;


Procedure preddyn(predvar:predvarietyrec; var pptr: predptr);
{
This can be called for pred 1 or 2.
}
var
	bn1,oldout,f,sd:single;
begin
	with pptr^ do with predvar do
	begin
		f:= ffdd(preddd,tpeak);
		sd:= max(predsd,sdmin);		{allows 0.4 min sd for T. aripo - pollen effect}
		bn1:= f*predn[6]*predsexr*predfec*preddd*sd;

		DelayNoPLR(bn1,oldout,prednums,predage[7],preddd,kpred);
//writeln(f:10:3,tb,predn[6]:10:3,tb,predsexr:10:3,tb,predfec:10:3,tb,preddd:10:3,tb,sd:10:3); readln
	end;
end; {preddyn }

Procedure predsup(demtot:single;
                 var pptr: predptr;predvar:predvarietyrec;
		 PA:single;	 var PreyFound:single);
(*
 0          68                       154      166                          486
 |----eggs---|--------immatures--------|-preova-|--------adults ovip---------|

..... since eggs are in a separate array, the relative ages for older stages
..... within the gmn array are:....
             0                        86       98                          388
             |--------immatures--------|-preova-|--------adults ovip---------|
 vgmimm      11111111111111111111111111100000000000000000000000000000000000000
 vgmpre      00000000000000000000000000011111111100000000000000000000000000000
 vgmadlt     00000000000000000000000000000000000011111111111111111111111111111

The function g(age) converts prey older than eggs to 'egg equivalents' so
that variable prey=total number of egg equivalents available.
*)
var
	a,b: single;
begin
	{
	Use Gutierrez- Baumgaertner model
	}
	with pptr^ do
	begin
		a := predvar.predalpha;
		b := demtot; {demand by preds}
		If b<0.0000001 then b:=0.0;
		if b=0.0 then PreyFound:=0.0;
		if(b>0.0)then PreyFound := b*(1.0- expo(-a*PA/b));
	end;

end; {predsup}

Procedure Predsdone(np:integer;var pptr: predptr;
				  var predpresent:boolean); {plantrec boolean}
(*				
Check for all preds gone from plant np.
Pptr is a pointer to a predator record.
Predpresent is a variable in the plant record.
*)
var
	s:single;
	i:word;
begin
	s:=0.0;
	with pptr^ do
	begin
		for i:=1 to 7 do s:=s+predn[i];
		if s<0.01 then
		begin
			predsfin:=true;
			predpresent:=false;

		end;
	end;
end;

Procedure predmodpart1(np:integer; {plant index}
				  predvar:predvarietyrec; {species parameters}
				  var pptr: predptr;  {ptr to a pred popl.}
				  var demtot,gmmort:single); 
(*
  Called by both predator1 and predator2.
  Green mite predator. Part 1 of the model.
  Here we compute daydegrees, count the numbers in age groups, compute total
  supply and demand and potential green mite mortalities for each predator.
  Before today's sd can be computed we must check to see if more than one
  predator is active.  If more than one are active then the actual number of
  prey for each predator is reduced because some prey may be attacked by more
  than one predator. 
*)
begin
	with predvar do
	begin
		with pptr^ do
		begin
			Daydegrees(modelday,predbase,preddd,ddb);
			tpreddd:=tpreddd+preddd;
		end;
		predcount(predvar,pptr);
		preddemand(predvar,pptr,demtot);
		predsup(demtot,pptr,predvar,PA,PreyFound);
		if PA>0.0 then gmmort:=Preyfound/Pa;
	end;
end;

procedure overlap(var mort1,mort2:single);
{
to get the corrected mortality when there is an overlap.
 o = overlap = prey attacked by both preds
 mort1/(mort1+mort2) = fraction of overlap to count as part of mort1.
ke. 10oct95
}

var
	o,t1,t2:single;
begin
	if (mort1+mort2)>0.0 then
	begin
		o:=mort1*mort2;
		t1 := mort1 - o*(mort2/(mort1+mort2));
		t2 := mort2 - o*(mort1/(mort1+mort2));
		mort1:=t1;
		mort2:=t2;
	end;
end;
 	
Procedure predmodpart2(np:integer; {plant index}
				  predvar:predvarietyrec; {species parameters}
				  var pptr: predptr;  {ptr to a pred popl.}
				  gmmort,demtot:single; 
				  var predpresent:boolean); {plantrec boolean}
{
After predmodpart1 and Overlap the effect of multiple predator overlap
has now been included if need be to correct the actual gmite mortalities
and the actual amount of supply to pred (RealSup).
}
begin
	with pptr^ do
	begin
		predsdr(pptr,gmmort,Pa,demtot);
		preddyn(predvar,pptr);
		PredMort(predvar,pptr);{need to redo the function of rhmean  ???????????????????///}
		predsdone(np,pptr,predpresent);
	end;
end;

Procedure Taripoimmig(np:integer);
var
	k:integer;
	xin:single;
begin
	with gmptrs[np]^ do with Tariporec do
	begin
		xin:=0.0;
		if Taripothisplant then
		begin
			if immigmethod=1 then xin:=0.05/delkpred;
			if immigmethod=2 then xin:=Taripoimmigpoola/ncas;
		end;
		if not(Taripothisplant) then xin:=0.05/Tariporec.delkpred; 
		
		xin:=xin*ncas/100.0;{compensate for plant density and food availability.}

		with Taripoptrs[np]^ do {with Tariporec do} {TaripoREC NEEDED?}
		begin
			k:=round((predage[6]/predage[7])*kpred);
			prednums[k]:=prednums[k]+xin;
			Taripothisplant:=true;
		end; {with Taripoptrs[np]^do with Tariporec }
	end;
end;

Procedure Tmanihotiimmig(np:integer);
var
	k:integer;
	xin:single;
begin
	with gmptrs[np]^ do with Tmanihotirec do
	begin
		xin:=0.0;
		if Tmanihotithisplant then
		begin
			if immigmethod=1 then xin:=0.05/delkpred;
			if immigmethod=2 then xin:=Tmanihotiimmigpoola/ncas;
		end;
		if not(Tmanihotithisplant) then xin:=0.05/delkpred; 
		
		xin:=xin*ncas/100.0;{compensate for plant density and food availability.}
		with Tmanihotiptrs[np]^ do{ with Tmanihotirec do} {TmanihotiREC NEEDED?}
		begin
			k:=round((predage[6]/predage[7])*kpred);
			prednums[k]:=prednums[k]+xin;
			Tmanihotithisplant:=true;
		end; {with Tmanihotiptrs[np]^do with Tmanihotirec }
	end;
end;

Procedure greenpreds(np:integer);
var
	demtot1,demtot2:single;
	mort1,mort2:single;
	sd,MiteSurv,s:single;
	i:word;
begin
	mort1:=0.0; mort2:=0.0;
	with casPtrs[np]^ do with gmptrs[np]^ do
	begin
		Gmavail(np,pa); {How many gm available as prey on plant np}
		begin
			{This handles background immigration and pooled immigration.}
			{Choose randomly if this population gets immigrants.}
			if (goTaripo and (random<=Taripoimmigprob)) then Taripoimmig(np);
			if (goTmanihoti and (random<=Tmanihotiimmigprob)) then Tmanihotiimmig(np);
			if Taripothisplant then predmodpart1(np,Tariporec,Taripoptrs[np],demtot1,mort1);
			if Tmanihotithisplant then predmodpart1(np,Tmanihotirec,Tmanihotiptrs[np],demtot2,mort2);
		end; 
  
		MiteSurv:=(1.0-mort1)*(1.0-mort2);
		MiteMort(np,MiteSurv);

		if (Taripothisplant and Tmanihotithisplant)then overlap(mort1,mort2);

		if Taripothisplant then
		begin
			predmodpart2(np,Tariporec,Taripoptrs[np],mort1,demtot1,Taripothisplant);
			{SD mort and emigration}
			{This has to be done separately for Taripo and Tmanihoti since the
			Taripopool and the Tmanihoti pool are across all plants.}
			with Taripoptrs[np]^do with Tariporec do
			begin
				sd:=max(predsd,sdmin); {allows min sd for Taripo - pollen effect} //?????? sd not used ?????????
				for i:=1 to kpred do
				begin
					if immigmethod=2 then
					Taripoimmigpoolb:=Taripoimmigpoolb+prednums[i]*(1.0 - predsd);
					prednums[i]:=prednums[i]*predsd;
				end;
			end;
			Taripodays:=Taripodays+Taripoptrs[np]^.predreport;
			{Check for gone}
			s:=0.0;
			with Taripoptrs[np]^ do
			begin
				if tpreddd>200.0 then
				begin
					for i:=1 to 7 do s:=s+prednums[i];
					if s<0.0001 then 
					begin
						Taripothisplant:=false;
						for i:=1 to kpred do prednums[i]:= 0.0;
					end;
				end;
			end;
		end; {if Taripothisplant}

		if Tmanihotithisplant then
		begin
			predmodpart2(np,Tmanihotirec,Tmanihotiptrs[np],mort2,demtot2,Tmanihotithisplant);
			{SD mort and emigration}
			{This has to be done separately for Taripo and Tmanihoti since the
			Taripopool and the Tmanihoti pool are across all plants.}
			with Tmanihotiptrs[np]^do with Tmanihotirec do
			for i:=1 to kpred do
			begin
				if immigmethod=2 then
				Tmanihotiimmigpoolb:=Tmanihotiimmigpoolb+prednums[i]*(1.0-predsd);
				prednums[i]:=prednums[i]*predsd;
			end;
			Tmanihotidays:=Tmanihotidays+Tmanihotiptrs[np]^.predreport;

			{Check for gone}
			s:=0.0;
			with Tmanihotiptrs[np]^ do
			begin
				if tpreddd>200.0 then
				begin
					for i:=1 to 7 do s:=s+prednums[i];
					if s<0.0001 then 
					begin
						Tmanihotithisplant:=false;
						for i:=1 to kpred do prednums[i]:=0.0;
					end;
				end;
			end;
		end; {if Tmanihotihisplant}
	end; {with casPtrs}
end;

end.
