{ Authors: 
- Andrew Paul Gutierrez (University of California, Berkeley / CASAS Global 
	(Center for Analysis of Sustainable Agriculture Systems) 
	<casas.kensington gmail.com>
- Luigi Ponti (ENEA - Agenzia nazionale per le nuove tecnologie, l'energia e 
	lo sviluppo economico sostenibile / CASAS Global) <quartese gmail.com>

Copyright: (C) CASAS Global (Center for the Analysis of Sustainable 
	Agricultural Systems)

SPDX-License-Identifier: GPL-3.0-or-later }

{$N+,E-}
Unit MB;
interface
uses globals,Modutils,bio,para;
{Procedure Infest(np:integer);}
Procedure CmbSetup(ncas:integer);
Procedure CmbImmig(var plant:plantrec;np:integer);
Procedure CmbMod(np:integer;var totph,casres,tuber:single);

Implementation
var

{Local variables.  They are used only in routines contained
 in this unit or called by routines in this unit.}
Cmbdda,deltmax,dmgrow,dmCmbres,dmrespmb,mbfood :single;
sdemb,sdgrow,mbdmtot,mbsdtot,ovawgt,rsvplr     :single;
dmemb,fecq  : single;
Cmbreserves : single;
Cmbimm,Cmbadults  : single;
totCmb : single;
		(*
		mbn[1]: ova
		mbn[2]: crawlers
		mbn[3]: larv2n
		mbn[4]: larv3n
		mbn[5]: mbpreovn
		mbn[6]: mbadl2n
		*)


procedure CmbCount(np:integer);
{
    age := array of transit times for each Cmb instar
        |--------a1----------a2-----------a3----------a4----------------a5
        0        114        182            306         371               890
        |--eggs---|-crawlers-|--larv2,3-----|--adults1--|--adults ovip----|
 vova   111111111110000000000000000000000000000000000000000000000000000000
 vcrawl 000000000001111111111100000000000000000000000000000000000000000000
 vlarv2 000000000000000000000011111110000000000000000000000000000000000000
 vlarv3 000000000000000000000000000001111111100000000000000000000000000000
 vgrow  000000000001111111111111111111111111100000000000000000000000000000
 vpreov 000000000000000000000000000000000000011111111111100000000000000000
 vadlt2 000000000000000000000000000000000000000000000000011111111111111111
 vadlt  000000000000000000000000000000000000011111111111111111111111111111
 }
var
	a,dwtdt:single;
	crawlwgt,larv2wgt,larv3wgt,preovwgt,adlt2wgt:single;
	crawlmax,larv2max,larv3max,preovmax,adlt2max:single;
	cimwgt:single;
	ewgt,adlwgt:single;
	i:integer;
begin

  with mbPtrs[np]^ do
  begin
	mbn[1] := dot(Cmbnum,vova,  kCmb) * delkCmb;
	ovawgt := dot(Cmbwgt,vova,  kCmb) * delkCmb;
	Cmbimm := dot(Cmbnum,vgrow, kCmb) * delkCmb;
	Cimwgt := dot(Cmbwgt,vgrow, kCmb) * delkCmb;
	Cmbadults := dot(Cmbnum,vadlt, kCmb) * delkCmb;
	adlwgt := dot(Cmbwgt,vadlt, kCmb) * delkCmb;
//preovw := dot(Cmbwgt,vpreov,kCmb) * delkCmb;
	ewgt   := sum(embwgt,1,kem) * delkem;
	Cmbreserves := sum(cresv,1,kCmb)*delkCmb;
{ total mass of live Cmb}
	totCmb := ovawgt + cimwgt + adlwgt + ewgt + Cmbreserves;

    //if(Cmbadults > 0.0)then totCmb:=totCmb +
	//			ednum[1]+ elnum[1])*adlwgt/Cmbadults;
	if ((Cmbadults+Cmbimm+mbn[1]) <= 0.0000001) then
	begin
		totCmb:=0.0;
		mbn[1]:=0.0;
		Cmbimm:=0.0;
		Cmbadults:=0.0;
	end;
(*
   ncrawlers,larv2,3n ,mbpreovn, mbadl2n are used in paras.
   E. lopezi and e.diversicornis may actually choose their
   host based on size rather than age.  Instead of using
   v age arrays to count age categories we can count members
   of size groups if LXsize is true.
*)

(* categorize by age:*)
		mbn[1]:=dot(Cmbnum,vova,  kCmb)*delkCmb; {ova}
		mbn[2]:=dot(Cmbnum,vcrawl,kCmb)*delkCmb; {crawlers}
		mbn[3]:=dot(Cmbnum,vlarv2,kCmb)*delkCmb; {larv2n}
		mbn[4]:=dot(Cmbnum,vlarv3,kCmb)*delkCmb; {larv3n}
		mbn[5]:=dot(Cmbnum,vpreov,kCmb)*delkCmb; {mbpreovn}
		mbn[6]:=dot(Cmbnum,vadlt2,kCmb)*delkCmb; {mbadl2n}
		adults:=mbn[5]+mbn[6];
{average sizes}
	for i:=1 to 6 do mbsize[i]:=0.0;
	if(mbn[2]>0.0)then mbsize[2] := (dot(Cmbwgt,vcrawl,kCmb) * delkCmb)/mbn[2];
	if(mbn[3]>0.0)then mbsize[3] := (dot(Cmbwgt,vlarv2,kCmb) * delkCmb)/mbn[3];
	if(mbn[4]>0.0)then mbsize[4] := (dot(Cmbwgt,vlarv3,kCmb) * delkCmb)/mbn[4];
	if(mbn[5]>0.0)then mbsize[5] := (dot(Cmbwgt,vpreov,kCmb) * delkCmb)/mbn[5];
	for i:=1 to 6 do if (mbsize[i]<0.0001) then mbsize[i]:=0.0;
	for i:=1 to 6 do phi[i]:=1.0;

	If lxsize then {categorize by size}
	begin
		crawlmax:=0.0;
		larv2max:=0.0;
		larv3max:=0.0;
		preovmax:=0.0;
		adlt2max:=0.0;
		for i:=1 to kCmb do
		begin
			a := ((i * delkCmb)-114.0);
			if a>192.0 then a:=192.0; {114+192= 306 = age of new adults a3}
			dwtdt := 0.01013 *exp(0.01013 * a);
			crawlmax:=crawlmax+dwtdt*Cmbnum[i]*vcrawl[i];
			larv2max:=larv2max+dwtdt*Cmbnum[i]*vlarv2[i];
			larv3max:=larv3max+dwtdt*Cmbnum[i]*vlarv3[i];
			preovmax:=preovmax+dwtdt*Cmbnum[i]*vpreov[i];
			adlt2max:=adlt2max+dwtdt*Cmbnum[i]*vadlt2[i];
		end;
		
		crawlwgt:=dot(Cmbwgt,vcrawl,kCmb);
		larv2wgt:=dot(Cmbwgt,vlarv2,kCmb);
		larv3wgt:=dot(Cmbwgt,vlarv3,kCmb);
		preovwgt:=dot(Cmbwgt,vpreov,kCmb);
		adlt2wgt:=dot(Cmbwgt,vadlt2,kCmb);
		
{what is phi?}
		if crawlmax>0.0 then phi[2] :=min(1.0,crawlwgt/crawlmax);
		if larv2max>0.0 then phi[3] :=min(1.0,larv2wgt/larv2max);
		if larv3max>0.0 then phi[4] :=min(1.0,larv3wgt/larv3max);
		if preovmax>0.0 then phi[5] :=min(1.0,preovwgt/preovmax);
		if adlt2max>0.0 then phi[6] :=min(1.0,adlt2wgt/adlt2max);
	end; {if lxsize}
  end;{with mbPtrs}
end; {CmbCount}

Procedure CmbDemand(np:integer);
{
    age := array of transit times for each Cmb instar
       |---------a1-----------a2---------- a3----------a4---------------a5
       0        114          182          306         371              890
       |--eggs----|--crawlers--|--larv2,3--|--preova---|--adults ovip---|
 vgrow 000000000000111111111111111111111111100000000000000000000000000000
}
var
	dwtdt,a,dq,rate,t: single;
	totelwgt,totedwgt: single;
	i:integer;
begin
{fecq can be used to modify growth and fecundity.}
	fecq:=1.0;
	with casPtrs[np]^ do if folwgt[10]>0.0 then  
		fecq := 0.35* (folnit[10]/folwgt[10])*100.0;
	fecq := max(fecq,0.0);
	fecq := min(fecq,1.1);
	fecq:=1.0;			 {?no nitrogen effect?}
	
	with mbPtrs[np]^ do
	begin
		dmgrow 	:= 0.0;
		dwtdt	:= 0.0;
		for i:=1 to kCmb do
		begin
			if(vgrow[i] > 0.0)then
			begin
				a := (i * delkCmb)-114.0;
				if a>192.0 then a:=192.0; {added 5-29-2024 APG}
				dwtdt := 0.01013 *exp(0.01013 * a);
				dmgrow := dmgrow + Cmbnum[i]*vgrow[i]*dwtdt{*fecq};
			end;
		end;
		deltmax := min(Cmbdda,25.0);		
		dmgrow := dmgrow*delkCmb*deltmax;
		
{**** growth of parasitoid larvae in CMB ********************}
		totedwgt:=0.0;
		totelwgt:=0.0;
		if(edthisplant)then
		begin
			totedwgt := edPtrs[np]^.ednum[1]*dwtdt;
			dmgrow := dmgrow + totedwgt*deltmax;
		end;
		if(elthisplant)then 
		begin
			totelwgt := elPtrs[np]^.elnum[1]*dwtdt;
			dmgrow := dmgrow + totelwgt*deltmax;
		end;

		{ demand (growth) of embryos - they attain .1 mg after 65dd}
		dmemb:=0.0;
		dq := 0.1/65.0;
		for i:=1 to kem do  dmemb := dmemb + embnum[i] * dq;
		dmemb := dmemb * delkem * deltmax ;
	
		{reserve demand}
		dmCmbres := 0.05*(dmgrow + dmemb);

		{cost of maintenance respiration (temperature dep. function of
	      active wgt -> this is a Q10 rule guess}
		rate := 0.008 * power(2.0,(0.1*(Cmbdda-10.0)));
		t:=totCmb-ovawgt+dmemb+dmgrow;
		t:=t-Cmbreserves;
		t:=t+totelwgt+totedwgt;
		if t < 1.0e-8 then t:=0.0;
		dmrespmb:=rate*t;

		mbdmtot:=(dmgrow + dmCmbres + dmrespmb + dmemb)/(1-Cmbbeta);

		(*writeln('dmgrow,dmCmbres,dmrespmb,dmemb,Cmbbeta:',
		dmgrow:8:5,dmCmbres:8:5,dmrespmb:8:5,dmemb:8:5,Cmbbeta:8:5); Readln;*)

	end; {mbPtrs[np]^}
end; {CmbDemand}

Procedure CmbSetup(ncas:integer);
{
 Pick and calculate species dependent parameters other than demands.
 Setup for all mb populations.
    age := array of transit times for each Cmb instar
	    |---------a1-----------a2----------a3----------a4---------------a5
        0        114          182         306         371              890
        |--eggs----|--crawlers--|--larv2,3--|--adults1--|--adults ovip---|
 vova   111111111111000000000000000000000000000000000000000000000000000000
 vcrawl 000000000000111111111111100000000000000000000000000000000000000000
 vgrow  000000000000111111111111111111111111100000000000000000000000000000
 vpreov 000000000000000000000000000000000000011111111111100000000000000000
 vadlt  000000000000000000000000000000000000011111111111111111111111111111

 age1          eggs
 age2          crawlers
 age3          immatures
 age4          adults
 age5          max age
 Cmbbase       dd threshold
 iety          1:=cultivar
 Cmbrateem     rate of embryo production  embryos/dd
 embshedmin,embshedmax min and max resorption age for emryos
}
var
	dtlarv : single;
	j,k:integer;
	i:byte;
begin

	Cmbage[1] := 114.0;
	Cmbage[2] := 182.0;
	Cmbage[3] := 306.6;
	Cmbage[4] := 371.0;
	Cmbage[5] := 890.0;
	embshedmin := 0.0;
	embshedmax := 50.0;
	Cmbbase:=14.6 {14.6 Schultess -old 13.5};
	delkCmb :=Cmbage[5]/kCmb;
	delem:= 65.0;
	delkem :=delem/kem;
	kcrawl:=round((148.0/Cmbage[5])*kCmb);
	wdwvec(0.0 		,Cmbage[1],  kCmb,Cmbage[5], vova);
	wdwvec(Cmbage[1],131.0    ,  kCmb,Cmbage[5], vcrawly); {1/4 youngest}
	wdwvec(Cmbage[1],Cmbage[2],  kCmb,Cmbage[5], vcrawl);
	wdwvec(Cmbage[1],Cmbage[3],  kCmb,Cmbage[5], vgrow);
	wdwvec(Cmbage[2],Cmbage[5],  kCmb,Cmbage[5], vattk);
	wdwvec(Cmbage[3],Cmbage[4],  kCmb,Cmbage[5], vpreov);
	wdwvec(Cmbage[4],Cmbage[5],  kCmb,Cmbage[5], vadlt2);
	wdwvec(Cmbage[3],Cmbage[5],  kCmb,Cmbage[5], vadlt);
{ divide the larva into 2 instars }
	dtlarv:=Cmbage[3]-Cmbage[2];
	wdwvec(Cmbage[2],Cmbage[2]+dtlarv/2.0,kCmb,Cmbage[5], vlarv2);
	wdwvec(Cmbage[2]+dtlarv/2.0,Cmbage[3],kCmb,Cmbage[5], vlarv3);
	wdwvec(embshedmin,embshedmax,         kem, delem    , vemb);

	{setup an extra record to store sampled means}
	if firstyear then new(mbPtrs[101]);
	with mbPtrs[101]^ do
		for i:=1 to kCmb do
			Cmbnum[i]:=0.0;
	(* 
	   Allocate space for Cmb variables on all plants and initialize to
	   zero populations. 
	 *)
	for k:=1 to ncas do
	begin
		j:=deck[k];
		new(mbPtrs[j]);
		with mbPtrs[j]^ do
		begin
			for i:=1 to kCmb do
			begin
				Cmbnum[i]:=0.0;
				Cmbwgt[i]:=0.0;
				cresv[i] :=0.0;
				embnum[i]:=0.0;
				embwgt[i]:=0.0;
			end;
			
			for i:=1 to 6 do lx[i]:=1.0;
			adults:=0.0;
			next:=0;
			mbsdtot:=0.0;
			ovawgt := 0.0;
			Cmbfin:=false;
			hjlx:=1.0;
			Cmbgo:=false;

			{date when this population would start}
			mbstart:=d1Cmb + random*10.0; {vary within 10 days}

			elthisplant:=false;
			edthisplant:=false;
			goel:=false;
			goed:=false;
			
			for i:=1 to 10 do stack[i]:=1.0;
			numberscolr:=0;                 {color in Cmb graphic}
			ShowingValues:=false; 
		end;{mbPtrs[j]^}
	end; {for j=}
end; { CmbSetup }


Procedure CmbGrowth(np:integer);
{
 growth of immature cmb  mg/dd
 (i * delkcmb)-114 := age in dd after egg stage
}
var
	a,dwtdt,dm,delwgt:single;
	i:integer;
begin
	with mbPtrs[np]^ do
	begin
		for i:= 1 to kcmb do
			if(vgrow[i] > 0.0)then
			begin
				a :=(i*delkcmb)-114.0;
				dwtdt := 0.01013 *exp(0.01013 * a);
				dm := dwtdt *cmbnum[i]* vgrow[i]*sdgrow*deltmax;{*fecq}
				cmbwgt[i] := cmbwgt[i] + dm ;
				cresv[i] := cresv[i] + 0.05*dm ;
			end;
{embryo growth: they attain .1 mg after 65.dd?, .1/65.=.00154 mg/dd}
		dwtdt := 0.1/65.0;
		for i := 1 to kem do
		begin
			delwgt := embnum[i]*dwtdt*sdemb*deltmax;
			embwgt[i] := embwgt[i] + delwgt;
		end;
	end;
end;

Procedure CmbNewEmbryos(np:integer);
var
   a,bn1,adinbin,ri,ff:single;
   bornnr,bornwt,ageout:single;
	i:integer;
begin
	with mbPtrs[np]^ do
	begin
		{Sum bn1 for all adults:}
		bn1 := 0.0;
		for i:=1 to kcmb do
			if(vadlt2[i] > 0)then
			begin
				a:=i-21 + 0.5; 
				a:= max(0.0,a);
				bn1:= bn1 + (7.1*a/(1+power(1.325,a)))*vadlt2[i]*cmbnum[i];
				
				{old adinbin := vadlt2[i]*cmbnum[i];
				a:=delkcmb*(ri-0.5)-371.0;
				bn1 := bn1 + adinbin*0.5688*a/power(1.0072,a);
				}
			end;
	{ calculate temperature effects}
		ff:= max(0.0, ffTemperature(tmean, 18, 35)); {Schulthess et al. data -- 5-22-2024APG}
		{Modify bn1 by sd (and temperature effects):}
		bn1 := max(0.0, bn1*delkcmb*sdemb*ff{*fecq});
	
 		DelayNoPLR(bn1,bornnr,embnum,delem,cmbdda,kem);
		DelayNoPLR(0.01*bn1,bornwt,embwgt,delem,cmbdda,kem);

	{convert output of emb arrays to integrals for input to cmb arrays.}
		bornnr:=bornnr*delkem;
		bornwt:=bornwt*delkem;
		DelayNoPLR(bornnr,ageout,cmbnum,cmbage[5],cmbdda,kcmb);
		DelayNoPLR(bornwt,ageout,cmbwgt,cmbage[5],cmbdda,kcmb);
		
	{input 0.1 of bornwt to reserve array:}
		DelayNoPLR(0.1*bornwt,ageout,cresv, cmbage[5],cmbdda,kcmb);
	end;{with mbPtrs}
end; {cmbNewEmbryos}

Procedure CmbSupply(var totph,tuber,casres:single);
{
 The source of food is totph generated by casava.
 Calculate food -- the supply of metabolite material
}
var
   a,b,food1,food2,food3,sap:single;
begin
	mbfood:=0.0;
{	writeln('sup. mbdmtot=',mbdmtot:8:3);}
	if(mbdmtot > 0.0)then
	begin
	{a = frazer gilbert fraction of photosynthate available}
		a:=0.85;
		b := mbdmtot;
		if b< 1.0E-20 then b:=0.0;

		food2:=0.0;
		food3:=0.0;
		sap := totph*1000.0; {sap is today's photosynthate}
		if b>0.00001 then food1:=b*(1.0-expo(-a*sap/b)) else food1:=0.0;

	{If the sap satisfies > 95% of demand then we're done.}
		if (food1 > 0.95*mbdmtot)then
		begin
			totph := totph - food1/1000.0;
			mbfood:=food1;
		end
		else

	{If more is needed then include casres.}
		begin
		{check value of b near 0.0}			//if ((b<0.000001) and (b>-0.000001))then b:=0.0;{??????????????}
			sap:=totph*1000.0 + casres*1000.0;
		if b>0.00001 then food2 := b*(1.0-expo(-a*sap/b));
			if (food2 > 0.95*mbdmtot)then
				begin
					totph := totph - food1/1000.0;
					mbfood:= food2;
					casres:= max(0.0, casres -(food2-food1)/1000.0);
					mbfood:= food2;
				end
				else
	{If we need more then include some from tuber.}
				begin
					sap:=totph*1000.0 + casres*1000.0 + 0.01*tuber*1000.0;
					if b>0.00001 then food3 := b*(1.0-expo(-a*sap/b))
						else food3:=0.0;
					totph := totph - food1/1000.0;
					casres := casres -(food2-food1)/1000.0;
					tuber := tuber-(food3-food2-food1)/1000.0;
					mbfood := food3;
     //writeln('using tbr for mb. mbfood=',mbfood:10:4);
				end;
		end;
	end; {mbdmtot>0.0}
end; {CmbSupply}

Procedure Cmbrsv;
{
 At this point, if food is negative, use Cmb reserves.
 (decrement of Cmb reserve via rsvplr)
}
var
   tempres,resinc:single;
begin
	tempres:= Cmbreserves;
	resinc:= min(Cmbreserves,(-mbfood));
	mbfood:= mbfood + resinc;
	Cmbreserves:= Cmbreserves-resinc;
	
	rsvplr:=0.0;
	if(tempres > 0.0)then rsvplr:= Cmbreserves/tempres;
	if(mbfood  <  0.0)then
	begin
		{ Cmb is in trouble and so is the plant.}
//		if iomode=1 then
//			writeln(' Cmb reserves less than 0');
		Cmbreserves:=max(Cmbreserves,0.0);
	end;
end;

Procedure CmbCosts;
{
 Subtract costs from the metabolite pool (mbfood,from CmbSupply)
}
begin
{c decrement for fraction excreted}
	mbfood := mbfood*(1.0-Cmbbeta);

{c decrement for respiration demand}
	mbfood := mbfood-dmrespmb;
{   if(mbfood < 0.0)then Cmbrsv; ??????????????}
	mbfood:=max(mbfood,0.0);
end;
	
Procedure Cmbsdr;
{
 s/d ratio.
}
var
	totdm : single;
begin
	mbsdtot :=1.0;
	totdm := dmemb + dmCmbres + dmgrow;
{writeln('dmemb,dmcmbres,dmgrow:','dmemb:9:4,dmcmbres:9:4,dmgrow:9:4);}
	if(totdm > 0.00001)then mbsdtot := mbfood/totdm; {try to avoid crash 10/20/96}
	if mbsdtot>1.0 then mbsdtot:=1.0;
	
{ embryo s/d}
	sdemb := mbsdtot;
	
{ Cmb immature s/d}
	sdgrow := mbsdtot;
	mbfood := 0.0;
end; {Cmbsdr}

procedure CmbImmig(var plant:plantrec;np:integer);
(*
  Add migrants to a Cmb population on a plant.
  Method1: the source of immigrants is assumed unknown,
  Method2: the source is the pool of emigrants from other plants.
  If mb exists here then increment the proper arrays.
  If no mb here then turn on the proper mb flags.
*)
var xin,meanin:single;
(*
	Immigmethod: byte; {1=source unknown, 2=daily migrant pool}
	read from setup file.
*)
begin
	with casPtrs[np]^ do
	begin
		if cmbthisplant then
		begin
			if immigmethod=1 then meanin:=mbins/delkcmb;
			if immigmethod=2 then meanin:= 0.01 {mbImmigpoola/ncas};
		end;
		
		if not(cmbthisplant)then meanin:=mbins/delkcmb;
		meanin:=meanin*ncas/100.0; {compensate for variation in plant density 12-03-97}

		if meanin>0.0 then
		begin
			xin:=fran(meanin,mbinspcnt);
			with plant do Cmbthisplant:=true;
			with mbPtrs[np]^ do
			begin
				Cmbnum[kcrawl]:=Cmbnum[kcrawl]+xin;
				Cmbwgt[kcrawl]:=Cmbnum[kcrawl]*0.1;
				cresv[kcrawl] :=Cmbnum[kcrawl]*0.01;
				CmbCount(np);
			end;{mbPtrs[np]^}
		end; {actual immig>0.0}
	end; {with plant}
end;

Procedure CmbMort(np:integer);
{
 Cmbsim   create survivorship vectors - emblx,Cmblx
 ndelay   nr days from stress to abort (inital)
 embshedmin,embshedmax   min and max abort (shed) ages for embryos
 hjlx := survivorship of Cmb from hj attack
 lx[6] is paras el and ed mort 
 rnsdlx - rain and sd survivorship
}
var
	Cmblx,reslx,elx,sd,tmplx: single;
	i:integer;
begin
with mbPtrs[np]^  do
begin

{ put today's mbsdtot in stack array using 'circular' indexing
  after NdlCmb days stack will contain the most recent NdlCmb days' mbsdtot values.}
	inc(next);
	if(next > NdlCmb)then next:=1;
	stack[next]:=mbsdtot;

{fetch an sd value from stack that is NdlCmb days old.
        kx:=next-NdlCmb
        if(kx < 1)kx:=kx+10
        sd:=stack[kx]}

	if ndlCmb>0 then 
	begin
		sd := 1.0;
		for i:=1 to NdlCmb do sd:=sd+stack[i];
		sd:=sd/NdlCmb;
	end
	else sd:=mbsdtot;
{write(sd:8:3);}
{Rain mort (as in green mites). (Fmin = use fungus mortality)}
	Cmbrmort:= 0.0;
	if FMin then {fungus mortality in run}
	begin
		Cmbrmort:= 0.45*(1.0 - EXP(-0.025*precip)) ; {-0.025 new fit 5-29-2024 APG}
	end;
	
	elx:=(1.0-Cmbrmort)*hjlx*lx[6]; 
	for i := 1 to kem do
	begin
		embnum[i] := embnum[i]*elx*(sd*vemb[i]);
		embwgt[i] := embwgt[i]*elx*(sd*vemb[i]);
	end;
	{
		Survivorships lx[i] due to paras e.d. and e.l. computed
		in routine Parova in file Para.pas.
		As i increments, different lx's are selected by v arrays.
	}
	for i := 1 to kCmb do
	begin
		tmplx :=  vova[i]   * lx[1]
				+ vcrawl[i] * lx[2]
				+ vlarv2[i] * lx[3]
				+ vlarv3[i] * lx[4]
				+ vpreov[i] * lx[5]
				+ vadlt2[i] * lx[6];

		tmplx := tmplx * sd * (1.0-Cmbrmort)*hjlx;

		reslx:=zerone((1.0-rsvplr)*tmplx);
		Cmblx:=zerone(tmplx);
	
{Separate emigration due to sd only from the other "mortalities".
Transfer youngest crawlers that leave due to sd to mbImmigpoolb.}

		if ((immigmethod=2) and (vcrawly[i]>0.0)) then
			mbImmigpoolb:=mbImmigpoolb+vcrawly[i]*Cmbnum[i]*(1.0-sd);
{
The pool will receive numbers that leave plants due to sd.
The next day they will be available for random migrations to all
plants. 
}
		Cmbnum[i] := Cmbnum[i]*Cmblx;
		Cmbwgt[i] := Cmbwgt[i]*Cmblx;
		cresv[i]  := cresv[i]*reslx;
	end;
	rnsdlx := (1.0-Cmbrmort)* sd * hjlx; {for paras}
end;{with mbPtrs}

end;

Procedure CmbDone(np:integer);
{Is this population extinct?}
begin
	with mbPtrs[np]^ do
	begin           
		Cmbfin:=((Cmbadults+Cmbimm+mbn[1]) <=  0.0);
		if(Cmbfin)then
		begin
//			if((iomode=1)and(nyears=1))then
//				writeln('****** mealybugs extinct on plant ',np:3,' ******');
			casPtrs[np]^.Cmbthisplant:=false;
			Cmbimm:=0.0;
			Cmbadults:=0.0;
			mbn[1]:=0.0;
		end;
	end;
end;

Procedure CmbMod(np:integer;var totph,casres,tuber:single);
{
 mb simulation called from Models.
 mb's food source is totph generated by casava.
}
var      ddb:single;
begin
(*
with mbPtrs[np]^ do
		mbn[2]:=dot(Cmbnum,vcrawl,kCmb)*delkCmb; {crawlers}
 with mbPtrs[np]^ do
		write('1 mb2=',mbn[2]:8:3);
*)
	daydegrees(modelday,Cmbbase, Cmbdda,ddb);
	CmbDemand(np);
	CmbSupply(totph,tuber,casres);
	CmbCosts;
	Cmbsdr;
	CmbMort(np);
	CmbGrowth(np);
	CmbNewEmbryos(np);
	CmbCount(np);
	CmbDone(np);
end;
end.
