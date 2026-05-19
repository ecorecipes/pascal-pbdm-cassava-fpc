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
Unit Para;
interface
uses globals,Modutils;
Procedure Parasetup;
Procedure Paras(np:integer;goel,goed:boolean;mbn:single6);
Procedure Edimmig(var mbr:mbrec;np:integer);
Procedure Elimmig(var mbr:mbrec;np:integer);

Implementation
var
  {local to routine or unit - set before used each day.}
  {el is A. lopezi and ed is A. diversicornis}
	adlhfd,adlhfl : single;
	edavgsd,elavgsd : single; {set in inits,parova, used in survs}
	edfemin,edmalin,elfemin,elmalin : single;
	elfemad,edfemad : single;
	elbt,edbt : single; {set in survsl,used in survsl,parova.}
	kdelel,kdeled : single;
	texp,cept : single;
	edv,elv : single100;
	kimm:integer;
	xinm,xinf:single;

Procedure parasetup;
(* set global values for all el and ed populations.*)
var
	i,j,k:integer;
begin
(*
  age := array of transit times for e.lopezi
     age1-------------age2--------age3--------------------------------age4
     0                100          186                                 366 
     |--eggsl----larva-|--pupa----- | --------------------adults -------|
	 Erlange k=50
*)
	elage[1]:=0.0;
	elage[2]:=100.0;
	elage[3]:=186.0;
	elage[4]:=366.0;
	delkel := elage[4]/kel;
	kdelel := kel/elage[4];
	ovipel := 0.9; {*****??????????????****}

(*
    age := array of transit times for e.diversicornus
    age1----------------age2-------age3-------------------------------age4
     0                  105         195                                380 
     |--eggsed-----larva-|--pupa-----| --------------------adults-------|
	 Erlange k=50
*)
	edage[1]:=0.0;
	edage[2]:=105.0;
	edage[3]:=195.0;
	edage[4]:=380.0;
	delked := edage[4]/ked;
	kdeled := ked/edage[4];
	oviped := 0.9;
	
	{setup an extra record to store sampled means}
	if firstyear then new(elPtrs[101]);
	if firstyear then 	new(edPtrs[101]);
	elPtrs[101]^.sexratio:= 0.0;
	edPtrs[101]^.sexratio:= 0.0;
	
	for k:=1 to ncas do

	begin
{A. lopezi }
		j:=deck[k];
		new(elPtrs[j]);
		with elPtrs[j]^ do
		begin
			elnum[1] := 0.0;
			elnum[2] := 0.0;

			for i := 1 to kel do
			begin
				elfrn[i] := 0.0;
				elmrn[i] := 0.0;
			end;

			for i:=1 to 7 do elsd[i]:=1.0;
			elavgsd:= 1.0;
		end; {with elPtrs[j]^}
		
{A. diversicornis }	
		new(edPtrs[j]);
		with edPtrs[j]^ do
		begin
			ednum[1] := 0.0;
			ednum[2] := 0.0;

			for i := 1 to ked do
			begin
				edfrn[i] := 0.0;
				edmrn[i] := 0.0;
			end;

			for i:=1 to 7 do edsd[i]:=1.0;
			edavgsd:=1.0;
		end; {with edPtrs[j]^}
	end;
end; {parasetup}

Procedure Edimmig(var mbr:mbrec;np:integer);
(*
  Allow small random immigration of young A. diversicornis adults, either a standard number, or part of a pool.
*)
begin
	with mbr do
	begin
		if edthisplant then
		begin
			if immigmethod=1 then
			begin
				xinm:=edins/delked;
				xinf:=xinm;
			end;
			
			if immigmethod=2 then
			begin
				xinm:=edmImmigpoola/ncas;
				xinf:=edfImmigpoola/ncas;
			end;
		end;

		if not(edthisplant)then
		begin
			xinm:=edins/delked;
			xinf:=xinm;
		end;
		
		xinm:= xinm*ncas/100.0; {compensate for variation in plant density 12-03-97}
		xinf:= xinf*ncas/100.0; {compensate for variation in plant density 12-03-97}

		kimm:=round((edage[3]/edage[4])*kel);
		if xinm>0.0 then
		begin
			xinm:=fran(xinm,edinspcnt);
			edthisplant:=true;
			with edPtrs[np]^ do edmrn[kimm] :=edmrn[kimm] + xinm;
		end;
		if xinf>0.0 then
		begin
			xinf:=fran(xinf,edinspcnt);
			edthisplant:=true;
			with edPtrs[np]^ do edfrn[kimm] :=edfrn[kimm] + xinf;
		end;
	end; {with mbr}
end;

Procedure elimmig(var mbr:mbrec;np:integer);
(*
  Allow small random immigration of young A. lopezi adults, either a standard number, or part of a pool.
*)

begin
	with mbr do
	begin
		if elthisplant then
		begin
			if immigmethod=1 then
			begin
				xinm:=elins/delkel;
				xinf:=xinm;
			end;
			
			if immigmethod=2 then
			begin
				xinm:=elmImmigpoola/ncas;
				xinf:=elfImmigpoola/ncas;
			end;
		end;

		if not(elthisplant)then
		begin
			xinm:=elins/delkel;
			xinf:=xinm;
		end;
		
		xinm:=xinm*ncas/100.0; {compensate for variation in plant density 12-03-97}
		xinf:=xinf*ncas/100.0; {compensate for variation in plant density 12-03-97}

		kimm:=round((elage[3]/elage[4])*kel);
		if xinm>0.0 then
		begin
			xinm:=fran(xinm,elinspcnt);
			elthisplant:=true;
			with elPtrs[np]^ do elmrn[kimm] :=elmrn[kimm] + xinm;
		end;
		if xinf>0.0 then
		begin
			xinf:=fran(xinf,elinspcnt);
			elthisplant:=true;
			with elPtrs[np]^ do elfrn[kimm] :=elfrn[kimm] + xinf;
		end;
	end; {with mbr}
			
end;

{**********Survsd START of A. lopezi routines*****************}
Procedure survsl(edthisplant,elthisplant:boolean;np:integer;mbn:single6);
var
	elb,elfrac,demand:single;
	parael,paraed,a,q,ff,bhf,natkd,wgtedlh : single;
	i,j:integer;
begin
{ calculate temperature effects q }
	q := fftemperature(Tmean,13.5,34);
	ff :=max(0.0,q);
	//demand:=0.0;
	{
	  calculate  elb,bhf
	  elb = demand for oviposition sites
	  bhf = demand for host feeding 
	}
	
{ per capita age demand per female}
{Sum Elb for all adults:}
(*		if elthisplant then with elPtrs[np]^ do
		begin
		Elb := 0.0;
		ovipel:=0.0;
		for i:=26 to kel do
			if(elfrn[i] > 0)then
			begin
				a:=i-25 + 0.5;
				a:=max(a,0.0);
				ovipel := ovipel + (8.0 - 0.355*a)*elfrn[i];
			end;
		end;
*)
{ constant per capita age demand per female}
	elb:= ovipel*ff*elavgsd; {*************}
	bhf := 0.02*eldelt;
	elbt := (1.0 + bhf) * elb;

	parael := 0.0;
	paraed := 0.0;
	for j:=1 to kel do
	begin
		if(elv[j] > 0.00001)then
		begin
		
		if elthisplant then with elPtrs[np]^ do
			parael:= parael + (elfrn[j]+elmrn[j])*elv[j];

		if edthisplant then with edPtrs[np]^ do
			paraed:= paraed + (edfrn[j]+edmrn[j])*edv[j];
		end;
	end; {j=1 to kel}

		(*
		mbn[1]: ova
		mbn[2]: crawlers
		mbn[3]: larv2n
		mbn[4]: larv3n
		mbn[5]: mbpreovn
		mbn[6]: mbadl2n
		*)

 { A. lopezi preference rates }
	wgtedlh := 0.328 * mbn[3]
			 + 0.514 * mbn[4]
			 + 1.000 * mbn[5]
			 + 1.000{0.514} * mbn[6]
	         + 0.25 * parael*delkel
	         + 0.25 * paraed*delked;
	{ elfrac is attacked fraction of host }
	elfrac := 0.0;
	if((elbt=0.0) or (eldelt=0.0))then exit;
	
	cept:=0.65; 
	
{****Gilbert-Fraser Model*****}
	with casPtrs[np]^ do
	demand:= elfemad*elbt*eldelt;
	if demand>0.00000001 then texp := 1.0 - expo(-cept*wgtedlh/demand) else texp:= 0.0;
	if wgtedlh>0.0 then elfrac := 1.0-expo(-demand*texp/wgtedlh);
	natkd:=elfrac*wgtedlh;
	
{	if(elfemad > 0.0)then elatpf:=elfrac*wgtedlh/elfemad;}
{	 calculate the different mb survivorships to be used in mb  }
	for i:=1 to 6 do lxlmb[i]:=1.0;
		If wgtedlh>0.0 then
	begin

		if mbn[3]>0.0 then lxlmb[3]:=1.0-min(1.0,natkd*0.328*mbn[3]/wgtedlh/mbn[3]);
		if mbn[4]>0.0 then lxlmb[4]:=1.0-min(1.0,natkd*0.514*mbn[4]/wgtedlh/mbn[4]);
		if mbn[5]>0.0 then lxlmb[5]:=1.0-min(1.0,natkd*1.0*mbn[5]/wgtedlh/mbn[5]);
		if mbn[6]>0.0 then lxlmb[6]:=1.0-min(1.0,natkd*1.0 {0.514} *mbn[6]/wgtedlh/mbn[6]);
	end;
end;

Procedure elopez(np:integer);
(*
c Epidinocarsis lopezi
c parasite of cassava mealy bug
c avgpar := avg mass of individuals of 3 age categories   (avgsm)
c lxel* := survivorships, set in survs     (lxa,lxa1,lxa2)
c elnum := counts of 3 parasite categories (both sexes)
c eldelt := daily dd  (ddaa)
c edfrn := rate array of numbers of female parasites
c elmrn := rate array of numbers of male parasites
c elb := demand for oviposition sites
c bt := elb*(1.0 + bhf =(0.02*eldelt))  ( bhf := demand for host feeding)
c lxel1 := cocc surv.
c rnsdlx := rain and sd survivorship from cmbmor
c elavgsd  := emigration surv.
c adlhfl := adult host feeding surv.
*)
var
	ellx,oldnr : single;	
	i,j : integer;
begin
 with elPtrs[np]^ do
 begin
	{sd mortality loop.}
	for i := 1 to 3	do
	begin
		ellx:=1.0;
		if((i=1)and(hjin))then ellx:=hjptrs[np]^.lxel1*rnsdlx;
		if(i = 3)then ellx:=adlhfl;
		if( (i=1) or (i=3))then
		begin
			wdwvec(elage[i],elage[i+1],kel,elage[4],elv);
			for j:=1 to kel do
			begin
				if(elv[j] > 0.00001)then
				begin
					{adults lost to sd may emigrate.}
					if ((i=3)and(immigmethod=2)) then
					begin
						elfimmigpoolb:=elfimmigpoolb+(elfrn[j]*elv[j]*(1.0-ellx));
						elmimmigpoolb:=elmimmigpoolb+(elmrn[j]*elv[j]*(1.0-ellx));
					end;
					elfrn[j]:=elfrn[j]*ellx*elv[j];
					elmrn[j]:=elmrn[j]*ellx*elv[j];
				end;
			end; {j=1 to kel}

		end; {i=1 or i=3}
	end; {1=1 to 3}

	{ inputs is correction for host feeding }
	elfemin:=elfemin/(1.0 + 0.02*eldelt);
	elmalin:=elmalin/(1.0 + 0.02*eldelt);

	DelayNoPlr(elfemin,oldnr,elfrn,elage[4],eldelt,kel);
	DelayNoPlr(elmalin,oldnr,elmrn,elage[4],eldelt,kel);

	{ counts in 3 categories (both sexes)}
	for  i:=1 to 3 do
	begin
		wdwvec(elage[i],elage[i+1],kel,elage[4],elv);
		elnum[i]:=dot(elfrn,elv,kel)+dot(elmrn,elv,kel);
		elnum[i]:=elnum[i]*delkel;
	end;

	{ female adults (use last settings of elv from loop above) }
	elfemad:=dot(elfrn,elv,kel)*delkel;
	if elnum[3]>0.0 then sexratio:=elfemad/elnum[3] else sexratio:=0;
	{check for extinction}

	if elnum[1]+elnum[2]+elnum[3]<0.0000001 then
	begin
		mbPtrs[np]^.elthisplant:=false;
		mbPtrs[np]^.goel:=false;
{		if ((iomode=1)and(nyears=1)) then writeln('E. lopezi now extinct on plant',np:3);}
	end;

  end;{with elPtrs}
end; {elopez}



{**********Survsd START of A. diversicornis routines*****************}
Procedure Survsd(edthisplant,elthisplant:boolean;np:integer;mbn:single6);
var
	edb,edfrac,demand,edatpf:single;
	parael,paraed,q,ff,bhf,edhopf,natkd,wgteddh : single;
	i,j:integer;
begin
	{ calculate temperature effects q }
	q := fftemperature(Tmean,13.5,34);
	ff :=max(0.0,q);
	{
	 edb := demand for oviposition sites
	 bhf := demand for host feeding
	}
	edb:=oviped*ff*edavgsd;
	bhf := 0.02*eddelt;
	edbt := (1.0 + bhf)*edb;

	{ encounter rates  }
	parael := 0.0;
	paraed := 0.0;

	wdwvec(elage[1],elage[2],kel,elage[4],elv);
	for j:=1 to kel do
	begin
		if(elv[j] > 0.00001)then
		begin
			if elthisplant then with elPtrs[np]^ do
				parael:= parael + (elfrn[j]+elmrn[j])*elv[j];
			if edthisplant then with edPtrs[np]^ do
				paraed:= paraed + (edfrn[j]+edmrn[j])*edv[j];
		end;
	end; {j=1 to kel}

	wgteddh:= 0.160 * mbn[3]
			+ 0.540 * mbn[4]
			+ 1.000 * mbn[5]
			+ 0.500 * mbn[6]
		    + 0.25*parael * delkel
		    + 0.25*paraed * delked;

	{**** edfrac is attacked fraction of host ****}
	edfrac := 0.0;
	if((edbt=0.0) or (eddelt=0.0))then exit;
	
{ ***********Gilbert-Fraser model ************}
	cept:=0.6;
	with casPtrs[np]^ do

	demand:=edfemad*edbt*eddelt;
	if demand >0.00000001 then texp := 1.0- expo(-cept*wgteddh/demand) else texp:=0.0;
	if wgteddh>0.0 then edfrac := 1.0-expo(-demand*texp/wgteddh);
	natkd:=edfrac*wgteddh;

{ calculate the different cmb survivorships i.e. lxcmbi to be used in parova}
	for i:=1 to 6 do lxdmb[i]:=1.0;

	if wgteddh>0.0 then
	begin    
		if mbn[3]>0.0 then lxdmb[3] :=1.0-min(1.0,natkd*0.16*mbn[3]/wgteddh/mbn[3]);
		if mbn[4]>0.0 then lxdmb[4] :=1.0-min(1.0,natkd*0.54*mbn[4]/wgteddh/mbn[4]);
		if mbn[5]>0.0 then lxdmb[5] :=1.0-min(1.0,natkd*1.0 *mbn[5]/wgteddh/mbn[5]);
		if mbn[6]>0.0 then lxdmb[6] :=1.0-min(1.0,natkd*0.5 *mbn[6]/wgteddh/mbn[6]);
	end;
end; {Survsd}

Procedure Edivr(np:integer);
(*
c Epidinocarsis diversicornus
c parasite of casava mealy bug
c lxed* := survivorships, set in survs     (lxa,lxa1,lxa2)
c ednum := counts of 3 parasite categories (both sexes)
c eddelt := daily dd
c edfrn := rate array of numbers of female parasites
c edmrn := rate array of numbers of male parasites
c
c edb := demand for oviposition sites
c edbt := edb(1.0 + bhf (= 1.2 * eddeltb))  ( bhf := demand for host feeding)
c rnsdlx := rain and sd survivorship from cmbmor
c lxed1 := cocc surv.
c rnsdlx := rain and sd survivorship from cmbmor
c edavgsd  := running average of adltsd
c adlhfd := adult host feeding surv.
*)
var
	edlx,oldnr : single;
	i,j:integer;	
begin
 with edPtrs[np]^ do
 begin
	{mortalities}
 {  stage immature Ed }
	edlx:=(1.0 - cmbrmort);
	if (hjin) then edlx:=edlx*hjptrs[np]^.lxed1;
	wdwvec(edage[1],edage[2],ked,edage[4],edv);
	for j:=1 to ked do
	begin
		if(edv[j] > 0.00001) then
		begin
			edfrn[j]:=edfrn[j]*edlx*edv[j];
			edmrn[j]:=edmrn[j]*edlx*edv[j];
		end;
	end; {j=1 to ked}

 {  adult Ed }
	edlx:=adlhfd;
	wdwvec(edage[3],edage[4],ked,edage[4],edv);
	for j:=1 to ked do
	begin
		if(edv[j] > 0.00001) then
		begin
			{adults lost to sd may emigrate.}
			if (immigmethod=2) then
			begin
				edfimmigpoolb:=edfimmigpoolb+(edfrn[j]*edv[j]*(1.0-edlx));
				edmimmigpoolb:=edmimmigpoolb+(edmrn[j]*edv[j]*(1.0-edlx));
			end;

			edfrn[j]:=edfrn[j]*edlx*edv[j];
			edmrn[j]:=edmrn[j]*edlx*edv[j];
		end;
	end; {j=1 to ked}

{previously blocked out -> down}
	for i := 1 to 3	do
	begin
		if(i = 1) then edlx:=(1.0 - cmbrmort);
		if((i = 1) and (hjin))then edlx:=edlx*hjptrs[np]^.lxed1;
		if(i=3)then edlx:=adlhfd;
		if( (i=1) or (i=3))then
		begin
			wdwvec(edage[i],edage[i+1],ked,edage[4],edv);
			for j:=1 to ked do
			begin
				if(edv[j] > 0.00001) then
				begin
					{adults lost to sd may emigrate.}
					if ((i=3)and(immigmethod=2)) then
					begin
						edfimmigpoolb:=edfimmigpoolb+(edfrn[j]*edv[j]*(1.0-edlx));
						edmimmigpoolb:=edmimmigpoolb+(edmrn[j]*edv[j]*(1.0-edlx));
					end;

					edfrn[j]:=edfrn[j]*edlx*edv[j];
					edmrn[j]:=edmrn[j]*edlx*edv[j];
				end;
			end; {j=1 to ked}
		end; {i=1 or i=3}
	end; {1=1 to 3}
{previously blocked out^}

	{inputs /(1.0 + 0.02*eddelt) is correction for host feeding}
	edfemin:=edfemin/(1.0 + 0.02*eddelt);
	edmalin:=edmalin/(1.0 + 0.02*eddelt);

	DelayNoPlr(edfemin,oldnr,edfrn,edage[4],eddelt,ked);
	DelayNoPlr(edmalin,oldnr,edmrn,edage[4],eddelt,ked);

	{	c counts in 3 categories (both sexes) }
	for  i:=1 to 3 do
	begin
		wdwvec(edage[i],edage[i+1],ked,edage[4],edv);
		ednum[i]:=dot(edfrn,edv,ked)+dot(edmrn,edv,ked);
		ednum[i]:=ednum[i]*delked;
	end;

	{ female adults (use last settings of edv from above loop) }
	edfemad:=dot(edfrn,edv,ked)*delked;
	if ednum[3]>0.0 then	sexratio:=edfemad/ednum[3] else sexratio:=0.5;

	{check for extinction}
	if ednum[1]+ednum[2]+ednum[3]<0.0000001 then
	begin
		mbPtrs[np]^.edthisplant:=false;
		mbPtrs[np]^.goed:=false;
{		if ((iomode=1)and(nyears=1)) then writeln('E. diversicornis now extinct on plant',np:3);}
	end;

  end;{with edPtrs}
end; {Edivr}

Procedure Parova(np:integer;edthisplant,elthisplant:boolean;mbn:single6);
(*  *************compute joint mortalities due to both parasitoids********)
{
Quantity of mb hosts are in variables mbn[2],mbn[3],mbn[4],
mbn[5], mbn[6].  These represent either age categories or
size categories.  (see boolean variables lxage and lxsize ).
}
var
	mued,muel:single6;
	naed,nael:single6;
	edadlsd,eladlsd,eggsed,eggsel : single;
	i:integer;
begin
	
	for i:=1 to 6 do
	begin
		mued[i]:=1.0-lxdmb[i];
		muel[i]:=1.0-lxlmb[i];
		naed[i]:=0.0;
		nael[i]:=0.0;
		if(mued[i]+muel[i])>0.0 then nael[i]:=mbn[i]*muel[i];
		if(mued[i]+muel[i])>0.0 then naed[i]:=mbn[i]*(mued[i]-muel[i]*mued[i]);
	end;
 	naed[2]:=mued[2]*mbn[2];
 	nael[2]:=muel[2]*mbn[2];

	for i:=1 to 6 do
		if(mbn[i] > 0.0)then lx[i] := 1.0-(naed[i]+nael[i])/mbn[i];

(* this is how the lxi's are applied in MB:
		tmplx :=          vova[i]   * lx[1]
				+ vcrawl[i] * lx[2]
				+ vlarv2[i] * lx[3]
				+ vlarv3[i] * lx[4]
				+ vpreov[i] * lx[5]
				+ vadlt2[i] * lx[6];
*)

	{ calculate nr of eggs input to fem and male arrays, edfemin, edmalin }
	if edthisplant then
	begin
		edfemin := 0.13*sqr(phi[4])*naed[4]  {larv3}
			 + 0.73*sqr(phi[5])*naed[5]      {preov}
			 + 0.92*sqr(phi[6])*naed[6];     {adlt2}
		edmalin := (naed[3] + naed[4] + naed[5] + naed[6]) - edfemin;
		eggsed := edfemin + edmalin	;
	end;

	{ calculate nr of eggs input to fem and male arrays, elfemin, elmalin}
	if elthisplant then
	begin
		elfemin := 0.82*sqr(phi[4])*nael[4]
			 + 0.74*sqr(phi[5])*nael[5]
			 + 0.64*sqr(phi[6])*nael[6];
		elmalin := (nael[3] + nael[4] + nael[5] + nael[6]) - elfemin;
		eggsel := elfemin + elmalin;
	end;
	
	{ intrinsic mortality }
	adlhfd :=  1.0;
	adlhfl :=  1.0;
	edadlsd := 1.0;
	eladlsd := 1.0;
	if edthisplant then
	if((edbt*edfemad*eddelt) > 0.0)then
	begin
		edadlsd := min(1.0,eggsed/(edfemad*edbt*eddelt{/(1.0 + 0.02 *eddelt)}));
		adlhfd := edadlsd;
	end;
	
	if elthisplant then
	if(elfemad*elbt*eldelt > 0.0)then
	begin
		eladlsd := min(1.0,eggsel/(elfemad*elbt*eldelt{/(1.0 + 0.02*eldelt)}));
		adlhfl := eladlsd;
	end;
{if iomode=1 then writeln(' ADLHFL:',adlhfl,' eggsel=',eggsel:10:5,' elfemad=',elfemad);}
	{
	 edsd and elsd keep the 7 most recent daily values of adult sd.
	 they are used to make running averages of sd to be used in computing
	 demand for oviposition sites.
	 }
	if edthisplant then
	with edPtrs[np]^ do
	begin
		for i:=1 to 6 do edsd[8-i]:=edsd[7-i];
		edsd[1]:=edadlsd;
		edavgsd:=(edsd[1]+edsd[2])/2.0;
	end;
	if elthisplant then
	with elPtrs[np]^ do
	begin
		for i:=1 to 6 do elsd[8-i]:=elsd[7-i];
		elsd[1]:=eladlsd;
		elavgsd:=(elsd[1]+elsd[2])/2.0;
	end;

end; {Parova}

Procedure Paras(np:integer;goel,goed:boolean;mbn:single6);
(*
 CMB parasites E. lopezi and E. diversicornis
 NP selects  plant, MB, and paras populations.
 rnsdlx = rain and sd survivorship from cmbmor
 goel,goed are true if the date allows pops of el and ed.
*)
var
	r:single;
	i:integer;
begin
	r:=random;
	if(goel and (r<=elimmigprob))then elimmig(mbPtrs[np]^,np);
	r:=random;
	if(goed and (r<=edimmigprob))then edimmig(mbPtrs[np]^,np);
	with mbPtrs[np]^	do
	begin
		if(not edthisplant)then
		begin
			for i:=1 to 6 do lxdmb[i]:=1.0;
			edbt:=0.0;
			eddelt:=0.0;
			edfemad:=0.0;
		end;
		if(edthisplant)then
		begin
			daydegrees(modelday,13.3, eddelt,ddb);
			survsd(edthisplant,elthisplant,np,mbn);
		end;
		if(not elthisplant)then
		begin
			for i:=1 to 6 do lxlmb[i]:=1.0;
			elbt:=  0.0;
			eldelt:=0.0;
			elfemad:=0.0;
		end;
		if(elthisplant)then
		begin
			daydegrees(modelday,13.3, eldelt,ddb);
			survsl(edthisplant,elthisplant,np,mbn);
		end;
		parova(np,edthisplant,elthisplant,mbn);
		if(edthisplant)then edivr(np);
		if(elthisplant)then elopez(np);

	end; {with mbPtrs[np]}
end;
end.
