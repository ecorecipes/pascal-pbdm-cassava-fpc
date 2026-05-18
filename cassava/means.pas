{ Authors: 
- Andrew Paul Gutierrez (University of California, Berkeley / CASAS Global 
	(Center for Analysis of Sustainable Agriculture Systems) 
	<casas.kensington gmail.com>
- Luigi Ponti (ENEA - Agenzia nazionale per le nuove tecnologie, l'energia e 
	lo sviluppo economico sostenibile / CASAS Global) <quartese gmail.com>

Copyright: (C) CASAS Global (Center for the Analysis of Sustainable 
	Agricultural Systems)

SPDX-License-Identifier: GPL-3.0-or-later }

unit means;
interface
uses globals,Modutils;

procedure  GetMeans;

implementation

procedure GetMeans;
{
From a plant population of size ncas represented in PLANTARRAY,
record the means of variables such as fruit mass, leaf mass, etc. in the plantarray cell 101.
Same for insects.
}
var
	f,t,l,la,ln,s,sd,ws,ns,rs,d,r,nit,sqdm:single;
	Taripot,Tmanihotit:single;
	hjt:array[1..3]of single;
	gmt:array[1..4]of single;
	mbt:array[1..6]of single;
	edt:array[1..3]of single;
	elt:array[1..3]of single;
	i,k:word;
begin
	d:=0.0;
	f:=0.0;
	t:=0.0;
	l:=0.0;
	la:=0.0;
	ln:=0.0;
	nit:=0.0;
	ns:=0.0;
	r:=0.0;
	s:=0.0;
	sd:=0.0;
	rs:=0.0;
	ws:=0.0;
	sqdm:=0.0;

	for i:=1 to ncas do
	begin
	{total each var}
	{The first ncas entries of array 'deck' have indeces of plant locations.}
		with casPtrs[i]^ do
		begin
			t:=t+tuber;
			l:=l+totall;
			ln:=ln+tfolnum;
			r:=r+totalr;
			s:=s+totals;
			la:=la+lai;
			rs:=rs+reserves;
			nit:=nit+nres;
			ns:=ns+nsdlsr;
			sd:=sd+sdlsr;
			ws:=ws+wsd;
			sqdm:=sqdm+sqdmpl;			
		end;
	end;
	{store means in plant 101.}
	with casPtrs[101]^ do
	begin
		tuber   := t/ncas;
		totall  := l/ncas;
		totalr  := r/ncas;
		tfolnum := ln/ncas;
		totals  := s/ncas;

		lai     := la/ncas;
		reserves:= rs/ncas;
		nres    := nit/ncas;
		nsdlsr  := ns/ncas;
		sdlsr   := sd/ncas;
		wsd     := ws/ncas;
		sqdmpl  := sqdm/ncas;
	end;

	if gmin then
	begin
		for k:=1 to 4 do gmt[k]:=0.0;
		Taripot:=0.0;
		Tmanihotit:=0.0;

		{accumulate gm totals in temporary variables.}
		for i:=1 to ncas do
		begin
			with gmptrs[i]^ do for k:=1 to 4 do gmt[k]:=gmt[k]+gmnums[k];

			if Taripoin then with Taripoptrs[i]^ do Taripot:=Taripot+predreport; {Predreport is set in Preds.pas.}
			if Tmanihotiin then with Tmanihotiptrs[i]^ do Tmanihotit:=Tmanihotit+predreport;
		end;
	
		{store means in array cell 101.}
		with gmptrs[101]^ do
		begin
			gmtot:=0.0;
			for k:=1 to 4 do 
			begin
				gmnums[k]:= gmt[k]/ncas;
				gmtot:= gmtot+gmnums[k];
			end;
		end;

		if Taripoin then with Taripoptrs[101]^ do predreport:=Taripot/ncas;
		if Tmanihotiin then with Tmanihotiptrs[101]^ do predreport:=Tmanihotit/ncas;

	// cumulative sums since previous output.	
		gmsum    := gmsum    + gmptrs[101].gmtot;
		if Taripoin then TariSum  := TariSum  + Taripoptrs[101].predreport;
		if Tmanihotiin then TmaniSum := TmaniSum + Tmanihotiptrs[101].predreport;

	end; {if gmin}

	if hjin then
	begin
		for k:=1 to 3 do hjt[k]:=0.0;

		{accumulate sample totals in temporary variables.}
		for i:=1 to ncas do
		begin
			if casPtrs[i]^.hjthisplant then
			with hjptrs[i]^ do
			begin
				hjt[1]:=hjt[1]+	hjegnm;
				hjt[2]:=hjt[2]+ hjlarn;
				hjt[3]:=hjt[3]+ hjadnm;
			end;
		end;

		{store means in array cell 101.}
		with hjptrs[101]^ do
		begin
			hjegnm:=hjt[1]/ncas;
			hjlarn:=hjt[2]/ncas;
			hjadnm:=hjt[3]/ncas;

		// cumulative sums since previous output.
			HjEggSum := HjEggSum + hjegnm;
			HjLarSum := HjLarSum + hjlarn;
			HjAdlSum := HjAdlSum + hjadnm;
		end;

	end;

	if cmbin then 
	begin
		for k:=1 to 6 do mbt[k]:=0.0;

		for k:=1 to 3 do 
		begin
			edt[k]:=0.0;
			elt[k]:=0.0;
		end;

		for i:=1 to ncas do
		{accumulate totals in temporary variables.}
		begin
			with casPtrs[i]^ do
			begin	
				if cmbthisplant then {are cmb on it?}
				with mbPtrs[i]^ do if cmbgo then   {are they active?}
				begin
					for k:=1 to 6 do mbt[k]:=mbt[k]+mbn[k];
				
					if elthisplant then 
					with elPtrs[i]^ do for k:=1 to 3 do elt[k]:=elt[k]+elnum[k];

					if edthisplant then
					with edPtrs[i]^ do for k:=1 to 3 do edt[k]:=edt[k]+ednum[k];
				end;
			end; {with casPtrs[i]^ do}
		end;


		{store means in array cell 101.}
		with mbPtrs[101]^ do for k:=1 to 6 do mbn[k]:=mbt[k]/ncas;

		if edin then
		with edPtrs[101]^ do for k:=1 to 3 do ednum[k]:=edt[k]/ncas;

		if elin then
		with elPtrs[101]^ do for k:=1 to 3 do elnum[k]:=elt[k]/ncas;


		// cumulative sums since previous output.
		with mbPtrs[101]^ do for k:=1 to 6 do mbnSum[k]   := mbnSum[k]   + mbn[k];
 
		if edin then
		with edPtrs[101]^ do for k:=1 to 3 do ednumSum[k] := ednumSum[k] + ednum[k];

		if elin then
		with elPtrs[101]^ do for k:=1 to 3 do elnumSum[k] := elnumSum[k] + elnum[k];
	end;{if cmbin}

end;{Getmeans}
end.




