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

Unit Hj97;
interface
uses globals,Modutils;
Procedure Hjmod(np:integer);
Procedure Hjsetup(ncas:integer);

implementation
var cmbtot:single;


Procedure hjimmigrate(np:integer);
{
Allow immigration randomly for a plant based on hjimmigprob.
Immigrating adults will be evenly distributed by age.

ncells = nr cells in adult range

There are two methods of immigration:
	In method 1 (original method) the number immigrating is specified
	as a number. Male and female arrays get the same number.
	Fran returns a number randomly near the original value of HJins.
	Division by Hjdelk transforms to a rate.

	In method 2 the migrants are rate values from the adult pools.
}

var
	i,kimm,ncells:integer;
        incr,xinm:single;
begin
{changed this to match form of cmbimmigrate 2/26/2002}

	kimm:=round((HJage[4]/HJage[5])*kHJ)+1;
	xinm:=0.0;
	if (casPtrs[np]^.hjthisplant) then
	begin
		if immigmethod=1 then xinm:=HJins/Hjdelk; 
		if immigmethod=2 then xinm:=HJimmigpoola/ncas;
	end;

	if not(casPtrs[np]^.hjthisplant) then xinm:=HJins/Hjdelk; 

	if xinm>0.0 then
	begin
		xinm:=fran(xinm,Hjinspcnt);
		casPtrs[np]^.Hjthisplant:=true;	

		{introduce into the appropriate age classes}
		ncells:=khj-kimm+1;
		incr:=xinm/ncells;

		with HJPtrs[np]^ do
		begin 
			for i:=kimm to khj do
			begin
				HJnm[i] :=HJnm[i] + incr;
				HJwt[i] :=HJwt[i] + incr * 0.98;
				hjdmres := hjdmres + 0.10 * incr * Hjdelk; 
			end;
		end;
	end; {actual immigrants>0.0}

end; {hjimmigrate}


Procedure Hjsetup(ncas:integer);
{
Set variables for all populations of HJ.
 hjage[1]          zero to hjage[2]          egg transit time
 hjage[3]          mean transit time of larvae
 hjage[4]          mean to time of reproduction (including pupal time)
 hjage(5]          maximum age
 rateem        rate of embryo production  embryos/dd
 hjshedmin,hjshedmax min and max absorption age for emryos
 hjbase          day degree threshold
}
var
	i,j,k:integer;
begin
	hjbase := 14.0;
	hjage[1] :=  0.0;
	hjage[2] :=  58.42;
	hjage[3] := 163.9;
	hjage[4] := 262.0;
	hjage[5] := 1224.0;
	

	delemhj:=109.0;
	delkemhj:=delemhj/khj;
	hjdelk:=hjage[5]/khj;
	wdwvec(0.0,     hjage[2],  khj,hjage[5], vhjeggs);
	wdwvec(hjage[2],hjage[3],  khj,hjage[5], vhjimm);
	wdwvec(hjage[3],hjage[4],  khj,hjage[5], vhjpupa);
	wdwvec(hjage[4],hjage[5],  khj,hjage[5], vhjadlt);
	hjshedmin := 0.0;
	hjshedmax := 54.0;
	wdwvec(hjshedmin,hjshedmax,khj,delemhj, vshedhjem);
	betahj := 0.260;
        hjsexr:=0.55;
	rateem:= 0.41;
{
Initial default values on all populations in run (and record #101).
}
	for k:=1 to ncas do
	begin
		j:=deck[k];
		new(hjPtrs[j]);
		with hjPtrs[j]^ do
		begin
			hjfin:=false;
			with mbPtrs[j]^ do goHj:=false;
			for i:=1 to khj do
			begin
				hjnm[i]:=0.0;
				hjwt[i]:=0.0;
				hjembnum[i]:=0.0;
				hjembwgt[i]:=0.0;
			end;
			for i:=1 to 10 do hjstack[i]:=1.0;
			hjadnm:=0.0;
			hjegnm  := 0.0;
			hjlarn  := 0.0;
			hjpupnm:=0.0;
			hjemnm:=0.0;
			hjpupwt := 0.0;
			hjegwt  := 0.0;
			hjlarwt := 0.0;
			hjtdelt:=0.0;
			lxed1:=1.0;
			lxel1:=1.0;
			toplai:=0.0;
			nexthj:=0;
			hjreserve:=0.0;
			food:=0.0;
		end;
	end;
	if firstyear then new(hjPtrs[101]);
end;
	
			

Procedure Hjinit(np:integer);
begin

	hjimmigrate(np);
	with hjPtrs[np]^ do
	begin
		hjadnm  := hj1;
		hjadwt := 2.5*hj1;
		hjreserve   := 0.5;
		hjtotn:=sum(hjnm,1,khj)*hjdelk;
	end;
end; {Hjinit}

Procedure hjheat(np:integer);
(*
hyperaspis jucunda de casava 7/21/86
c get today's weather data
c jday     current julian day - continues cross years
*)
begin
	with hjPtrs[np]^ do
	begin
		daydegrees(modelday,hjbase, hjdelt,ddb);
		hjtdelt := hjtdelt + hjdelt;
	end;
end;


Procedure hjdem(np:integer);
(*
c   per capita growth rates for embryos and viviparae
c	calories per calorie per degree day
c	  vector of age arrays  
c vhjeggs hjage(1) to hjage(2)  developmental time of eggs 
c vhjimm  hjage(2) to hjage(3)  immatures (larvae)	   
c vhjadlt hjage(3) to hjage(4) (pupal stage + prepupa)
c vpost hjage(4) to hjage(5) adults
c
c    0.       58           163       262.                 1224.
c    |  eggs   |  larvae    |  pupae   |      adults          |
c 
c hyperaspis jucunda demand rates
*)
var
	dmv,ge,sume,sumv,rate,dmemb,ex: single;
	i,j,kj : integer;
begin
	with hjPtrs[np]^ do
	begin
		{ immatures }
		j:= trunc(khj*(hjage[2]/hjage[5]));
		kj := trunc(khj*(hjage[3]/hjage[5]));

		dmv:=0.0;
		for i:=j to kj do
		begin
			if(vhjimm[i] > 0.0)then
			begin
		 	  gr := 0.003065*exp(0.03065*(i+1-j)*hjdelk);
{2/15/01}			  dmv:= dmv + gr * hjdelt * hjnm[i] * hjdelk * vhjimm[i] ;
     			end;
		end; {for i}
		dmres := 0.15*dmv;

		{embryos}
		ge := 0.0009;
		dmemb := 0.0;
		for i:=1 to khj do
			dmemb := dmemb + hjembnum[i] * ge;
	
		dmemb :=  dmemb * hjdelt * delkemhj;
		dmgro := dmv +dmemb;
{2/15/01 SCALE VERSION DOESN'T INCLUDE DMEMB IN DMGRO}
		{
		 cost of maintenance respiration (temperature dep. function of active wgt)
		 sums below are numbers for mass --not rates
		 }

		sume := sum(hjembwgt,1,khj) *delkemhj;
		sumv := hjlarwt+hjadwt;
	{**following function goes from*** 0.0 to 0.2 for hjdelt of 0.0 to 30.0}
		ex:=0.1*(hjdelt+6);
		rate := 0.008 * power(2.0,ex);
		dmresphj := rate * (sumv + sume);
		bhj :=  (dmgro + dmres + dmresphj)/(1.0-betahj);
{2/15/01}	{bhj := bhj/hjdelt;}
	end;
end; { hjdem }

Procedure hjrsv(np:integer);
(*
c at this point food is negative.  take something from hjreserve.
*)
begin
	with hjPtrs[np]^ do
	begin
		hjreserve := food + hjreserve;
		food := 0.0;
		if(hjreserve < 0.0)then  {not enough in hjreserve}
		begin
			hjreserve:=0.0;
(* THIS CODE COMMENTED OUT AS IN SCALE   {2/15/01}
			for i:=1 to khj do
			begin
				hjnm[i]:=hjnm[i]*(1.0-(vhjimm[i]+vhjadlt[i]) );
				hjwt[i]:=hjwt[i]*(1.0-(vhjimm[i]+vhjadlt[i]) );
				hjembnum[i]:=0.0;
				hjembwgt[i]:=0.0;
			end;
			hjlx:=1.0;
			lxed1:=1.0;
			lxel1:=1.0;
*)
		end; {hjreserve<0}
	end;
end; {hjrsv}


Procedure hjsup(np:integer);
(*
c hjmod de casava 7/21/86
c calculate the supply of metabolite material
c cmbtot := total mass of cmb := food supply for hj
*)
var
	a,avail : single;
	arg:single;
begin
	with hjPtrs[np]^ do
	begin
		hjlx :=1.0;
		lxed1:=1.0;
		lxel1:=1.0;
		food := 0.0;
		if(bhj > 0.00001)then
		begin
(*
 THIS CODE REPLACED BY ARG:=-0.025*(cmbtot); 02/15/01
			{ Frazer Gilbert proportion of area searched}
		   	if (casPtrs[np]^.lai<0.01) then aa:=1.0 else
			begin
				arg:=-0.1*casPtrs[np]^.lai;
				aa :=expo(arg);
			end;
			if hjlarn<0.0001 then hjlarn:=0.0;
			if hjadnm<0.0001 then hjadnm:=0.0;

			arg:=-0.0575*aa*(hjlarn+hjadnm);
*)
			ARG:=-0.025*(cmbtot);
		   	a := 1.0 - expo(arg);

			{ el and ed nums represent 1 mg each in avail:}
			avail := cmbtot;
			with mbPtrs[np]^ do
			begin
{*********use numbers but Hj eats mass, hence 0.07 is mass of large scale *****************}{YYY 02/15/01}
				if elthisplant then avail:=avail + elPtrs[np]^.elnum[1]*0.07;
				if edthisplant then avail:=avail + edPtrs[np]^.ednum[1]*0.07;
			end;
{
			if elin then avail:=avail + elPtrs[np]^.elnum[1]; 
			if edin then avail:=avail + edPtrs[np]^.ednum[1];
}

(* followin 2 lines changed as in scale
			if(avail > 0.0001)then food := bhj * hjdelt*(1.0-expo(-a*avail/(bhj*hjdelt)));
			if(avail > 0.0001)then hjlx :=1.0-(food/avail);
*)
                        if(avail > 0.0000001)then
				food := bhj*(1.0-expo(-a*avail/bhj));
                        if(avail > 0.0000001)then 	
				hjlx :=1.0-(food/avail); 
         
			lxel1:=hjlx;
			lxed1:=hjlx;
			hjegest := food * betahj;
			food := food*(1.0-betahj) - dmresphj;
			{c check metabolite pool for exhaustion}
			if(food <  0.0)then  hjrsv(np);
		end; {bhj>0.0}
	end;
end; {hjsup}


Procedure hjrati(np:integer);
(*
c update the metabolite pool and the supply/demand ratios 

c       dmres   -       reserve demand
c       dmv     -       hj growth demands
c       sde     -       s/d for embryos
c       sdv     -       s/d for hj adult females

*)
var
	dmtot : single;
begin
	with hjPtrs[np]^ do
	begin
		sdv   := 1.0;
		sde   := 1.0;

		{ growth supply demand ratio}
		dmtot  := dmgro + dmres ;
		if(dmtot > 0.0)then sdv := zerone(food/dmtot);
		sde:=sdv;
		food := 0.0;
	end;
end; {hjrati}

Procedure hjmort(np:integer);
(*
c hjmod de casava  7/21/86
c combine independent mortalities into final mortalities
c    ndelayhj          number of days from stress to shed
c    delt            today's degree days
c    hjshedmin,grap ndelay
   min and max shed age for embryos
c    hjstack  is an array storing ndelayhj+1 most recent sdv values
*)
var
	i,j,k,kx,kj:integer;
	sd : single;
begin

	with hjPtrs[np]^ do
	begin
	{
	 Put today's sdv in hjstack array using 'circular' indexing.
	 After 3 days hjstack will contain the most recent 3 days' sdv values.
	}
		inc(nexthj);
		if(nexthj > 3)then nexthj:=1;
		hjstack[nexthj]:=sdv;

		{Compute an sdv value from 3 days running avg }
		kx:=nexthj-ndelayhj;
		if(kx < 1)then kx:=kx+3;
{02/15/01		sd:=hjstack[kx];}
		sd:=(hjstack[1]+hjstack[2]+hjstack[3])/3.0;

		{apply attrition rates }
		hjreserve := (hjreserve + dmres*sdv) *sd;
{6/04/97 added the following loop to do sd mort, i.e., to move adults from
hjnm array to hjimmigpoolb as f(sd). Assume standard ratios between
adults in poolb , their weight, their embryos.  Apply same sd mort to
hjwt,hjembnum, and hjembwgt arrays.  ke}
 		k:= trunc(khj*(hjage[4]/hjage[5]));  
		if immigmethod=2 then for i := k to khj do
			hjimmigpoolb:=hjimmigpoolb+hjnm[i]*(1.0-sd)*vhjadlt[i];

{ Remove larvae because of S/D}
		j:= trunc(khj*(hjage[2]/hjage[5]));
		kj:= trunc(khj*(hjage[3]/hjage[5]));
        	if sd<1.0 then
		for i := j to kj do 
		begin
			hjwt[i]:=hjwt[i]-hjwt[i]*(1.0-sd) * vhjimm[i];
			hjnm[i]:=hjnm[i]-hjnm[i]*(1.0-sd) * vhjimm[i];
		end;
{ Remove adults because of S/D}
		j:= trunc(khj*(hjage[4]/hjage[5]));
        	if sd<1.0 then
		for i := j to khj do 
		begin
			hjwt[i]:=hjwt[i]-hjwt[i]*(1.0-sd) * vhjadlt[i];
			hjnm[i]:=hjnm[i]-hjnm[i]*(1.0-sd) * vhjadlt[i];
		end;

	end;
end; { hjmort }

Procedure hjgrow(np:integer);
(*
c    hjdelt	    today's degree days
c    rateem	rate embryo production

*)
var
	i,j,kj : integer;
	dlw,dq,delwgt,dw,hjbn1,b1,wgtemb,outnum,outwgt : single;
begin
	with hjPtrs[np]^ do
	begin
{02/15/01 emb growth not in scale version}
		if(hjadnm > 0.0)then    { growth of embryos }
		begin
			dq:=0.0009;
			dlw:=0.0;
			for i := 1 to khj do
		 	  if(hjembnum[i] > 0.00001)then
			  begin
			    delwgt :=  hjembnum[i]*dq*sde*hjdelt;
			    hjembwgt[i] := hjembwgt[i] +delwgt;
			    dlw:=dlw+delwgt;
			  end;
		end; { hjadnm>0 }

		if(hjlarn > 0.0)then    { growth of larvae }
		begin
			j:= trunc(khj*(hjage[2]/hjage[5]));
			kj := trunc(khj*(hjage[3]/hjage[5]));
			for i := j to kj do
			begin
				if(vhjimm[i] > 0.0)then
				begin
					gr := 0.003065*exp(0.03065*(i+1-j)*hjdelk);
					dw:=vhjimm[i]*gr*sdv*hjdelt*hjnm[i];
				    	hjwt[i]:=hjwt[i] + dw;
				    end;
			end;
		end; { growth of larvae }		  

		{  aging of embryo arrays }
		hjsexr := 0.55;
		hjbn1 := rateem * sde * hjadnm *hjsexr * hjdelt;
		wgtemb:=0.1*hjbn1;
		{ numbers }
		DelayNoPLR(hjbn1,outnum,hjembnum,delemhj,hjdelt,khj);
		{ mass }
		DelayNoPLR(wgtemb,outwgt,hjembwgt,delemhj,hjdelt,khj);
{02/15/01 inputs to hjnm, hjwt are outputs of emb arrays. not so in scale}
		{ adult, pupae and larvae array numbers }
		b1:=outnum*delkemhj;
		DelayNoPLR(b1,outnum,hjnm,hjage[5],hjdelt,khj);

		{ mass }
		b1:=outwgt*delkemhj;
		DelayNoPLR(b1,outwgt,hjwt,hjage[5],hjdelt,khj);

		{ summarize }
		bornhj:=0.0;
		if((hjadnm*hjsexr) > 0.0)then bornhj:=hjbn1/(hjadnm*hjsexr);

	end;

end; { hjgrow }

Procedure HjCount(np:integer);

begin
	with hjPtrs[np]^ do
	begin

		hjegnm  := dot(hjnm,vhjeggs, khj) * hjdelk;
		hjegwt  := dot(hjwt,vhjeggs, khj) * hjdelk;
		hjlarn  := dot(hjnm,vhjimm,  khj) * hjdelk;
		hjlarwt := dot(hjwt,vhjimm,  khj) * hjdelk;
		hjpupnm := dot(hjnm,vhjpupa, khj) * hjdelk;
		hjpupwt := dot(hjwt,vhjpupa, khj) * hjdelk;
		hjadnm  := dot(hjnm,vhjadlt, khj) * hjdelk;
		hjadwt  := dot(hjwt,vhjadlt, khj) * hjdelk;
		hjemwt  := sum(hjembwgt,1,khj) * delkemhj;
		hjemnm  := sum(hjembnum,1,khj) * delkemhj;
		{c total numbers and mass of live hyperaspis jucunda }
		hjtotn  := hjegnm + hjlarn + hjadnm;
		hjtotwt := hjemwt + hjlarwt + hjadwt;
	end;
end;

Procedure Hjmod(np:integer);
(*
c hyperaspis jucunda model called from casava
c jday := julian day of model
c cmbtot := total wgt of cmb := food supply for hj
c hjfin becomes true if hj population dies out.
*)
var
	ovawgt,cimwgt,adlwgt,ewgt,cmbreserves:single;
	r:real;
begin

	with mbPtrs[np]^ do
	begin
		ovawgt := dot(Cmbwgt,vova,  kCmb) * delkCmb;
		cimwgt := dot(Cmbwgt,vgrow, kCmb) * delkCmb;
		adlwgt := dot(Cmbwgt,vadlt, kCmb) * delkCmb;
		ewgt   := sum(embwgt,1,kem) * delkem;
		Cmbreserves := sum(cresv,1,kCmb)*delkCmb;
		cmbtot:= ovawgt + cimwgt + adlwgt + ewgt + Cmbreserves;

		if cmbtot>HJMBLEV then gohj:=true;                {?????????? what should hjmblev be????????}

		r:=random;
{02/15/01}	if(gohj) then if r<hjimmigprob then hjimmigrate(np);

		with casPtrs[np]^ do 
		if hjthisplant then with hjPtrs[np]^ do
		begin
			hjheat(np);
			Hjdem(np);
			hjsup(np);
			hjrati(np);
			hjmort(np);
			hjgrow(np);
			hjcount(np);
			if((hjtdelt > 100.0) and ((hjegnm+hjlarn+hjadnm) < 0.00001))then
			begin
				hjegnm:=0.0;
				hjlarn:=0.0;
				hjadnm:=0.0;
				hjtotn:=0.0;
			end;
		end;
	end;
end; {Hjmod}

end.
