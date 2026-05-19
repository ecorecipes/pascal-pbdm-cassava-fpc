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

Unit Output;
interface
uses globals,Modutils,means,sysutils;

Procedure colheadings;
Procedure outputs;

Implementation

Procedure colheadings;
{
 print column headings for tabular output.
 called at start and before each month.
}
begin
	writeln;
	if castrue then 
	begin
		writeln(
	 '      day	month 	year	date    dd    folm   tuber    stem    root    resv    lai   sd  wsd  nsd');
	end;
end; {colhead}

Procedure outputs;
var
	stemreport : single;
        sw,tubreport:single;
	i,j,idd : integer;
	month,day:byte;
	sday:single;
	ednumReport,elNumReport:array[1..3]of real;

begin

	if((MODELDAY mod modout)=0)then
	begin
		caland(modelyear,jday, month,day,ok);
		if(tab and (firstcols or (day=1)))then colheadings;
		tubreport:=0.0;stemreport:=0.0;
		idd:=round(tddfield);
		if castrue then
		with casvar do
		with casPtrs[101]^ do
		begin
			if (totals+tuber)>0.0 then tubreport:=tuber+(tuber/(totals+tuber))*reserves;
			if (totals+tuber)>0.0 then stemreport:= totals+ (totals/(totals+tuber))*reserves;

			if elin then with elPtrs[101]^ do
				for i:=1 to 3 do elNumReport[i]:=elnum[i];
			if edin then with edPtrs[101]^ do
				for i:=1 to 3 do edNumReport[i]:=ednum[i];

		
			if(tab)then 
			begin
				writeln(' cas', month:3,day:3,idd:6,
				totall:8:1,tubreport:8:1,stemreport:8:1,totalr:8:1,reserves:8:1,
				lai*100:7:2,sdlsr:5:1,wsd:5:1,nsdlsr:5:1);
			end;

			if tab then if (cmbin) then
			begin
			 with mbPtrs[101]^ do
	  		 begin
			  write('mb:');
			  for i:=1 to 6 do write(mbn[i]:10:3);
			  writeln;
			  if elin then
			  with elPtrs[101]^ do
			  begin
				write('el:');
				for i:=1 to 3 do write(elnum[i]:10:3);
				write(' sxr=',sexratio:8:3);
				writeln;
			  end;
			  if edin then
			  with edPtrs[101]^ do
			  begin
				write('ed:');
				for i:=1 to 3 do write(ednum[i]:10:3);
				write(' sxr=',sexratio:8:3);
				writeln;
			  end;
			end; {with mbPtrs[101]}
		      end; {if tab}
		end; {with casPtrs[101]}
	

(* turn off this tabular output for multiseason version?*)
(* may use for debugging.
	if (tab and (iomode=1)) then
	begin
		if (gmin and (ModelDate>gmstartday)) then
		 with gmptrs[101]^ do
		writeln('gm: ',gmnums[1]:10:2,'eggs ',gmnums[2]:10:2,'imm ',gmnums[3]:10:2,
		'preo ',gmnums[4]:10:2,'ad');
	
		if Taripoin then with Taripoptrs[101]^ do
		begin
		 write('Taripo 7 stages=');
		 for i:=1 to 6 do write(predn[i]:8:2,' ');writeln(predn[7]:7:2);
		end;
		if Tmanihotiin then with Tmanihotiptrs[101]^ do
		begin
		 write('Tmanihoti 7 stages=');
		 for i:=1 to 6 do write(predn[i]:8:3,' ');writeln(predn[7]:7:3);
		end;

	end;
*)

{with only 1 plant in center use soiln of 1 sq meter in center}
{
	if ncas=1 then

	begin
		soiln:=narray[10,10]+narray[10,11]+narray[11,10]+narray[11,11];
	end;
}

{	if(daily)then with casPtrs[deck[1]]^ do}

	if(daily)then with casPtrs[101]^ do
	begin
		sw:=layer[1].warray[11,11]*4; {SOILW in 1 sq meter around plant}

		if ncas=1 then	with layer[1] do 
			sw:=warray[11,11]+warray[11,12]+warray[12,11]+warray[12,12];
	//writeln('CMBinfield', cmbInField:10); Readln;
		if(firstcols)then
		begin
			write(dailyfile,'year',tb,'jday',tb, 'month',tb,'date',tb,'day',tb,'dd',tb,'rain',tb,'leaf',tb,
			'stem',tb,'tuber',tb,'reserves',tb,'sumflin',tb,'sd*10',tb,'nsdlsr10',tb,'wsd*10',tb);
			write(dailyfile,'ibranch',tb,'gs',tb,'gr',tb,'gres',tb,'gtuber',tb,'glf',tb,'pcost',tb,'lai100',tb,'totevap',tb,'sumtrans',tb,'tnuptk',tb,'tdelorg',tb,'soiln',tb,'soilw',tb,'nveg');
			if GmInField        then write(dailyfile,tb,'gmitetot');
			if TaripoInField    then write(dailyfile,tb,'T_aripoN');
			if TmanihotiInField then write(dailyfile,tb,'T_ManihotiN');
			if HJInField        then write(dailyfile,tb,'hjegnm',tb,'hjlarnm',tb,'hjadnm');
			if cmbInField then write(dailyfile,tb,'mb1',tb,'mb2',tb,'mb3',tb,'mb4',tb,'mb5',tb,'mb6',tb, 'totCM');
			if edInField then write(dailyfile,tb,'ed1',tb,'ed2',tb,'ed3');
			if elInField then write(dailyfile,tb,'el1',tb,'el2',tb,'el3');
			writeln(dailyfile);


			if(ModelDate > startday)then
			for j:=1 to trunc(ModelDate-startday) do
			begin
			  sday:=startday+j-1;		
			  write(dailyfile,sday:1:0,tb,modelyear:10,tb,day:10, tb,month:10,tb,modelday:1,tb,idd:1,tb,precip:1:3,tb,
			  totall:1:3,tb,stemreport:1:3,tb,tubreport:1:3,tb,reserves:1:3,tb,sumflin:1:3,tb,
			  (sdlsr*10.0):1:3,tb,(nsdlsr*10.0):1:3,tb,(wsd*10.0):1:3,tb,
			  branch:1,tb,gs:1:3,tb,gr:1:3,tb,gres:1:3,tb,gtuber:1:3,tb,
			  glf:1:3,tb,pcost:1:3,tb,lai*100:1:3,tb,
			  totevap:1:3,tb,sumtransp:1:2,tb,totnuptk:1:2,tb,tdelorg*0.05:1:3,tb,
			  soiln:1:2,tb,sw:1:2,tb,nveg:1:2);
			  
			  //with gmptrs[101]^  do writeln('Daily',tb,gmtot:1:4);
			  
			  if GmInField        then with gmptrs[101]^        do write(dailyFile,tb,gmtot:1:4);
			  if TaripoInField    then with Taripoptrs[101]^    do write(dailyFile,tb,predreport:1:4);
			  if TmanihotiInField then with Tmanihotiptrs[101]^ do write(dailyFile,tb,predreport:1:4);
			  if HJInField        then with hjptrs[101]^        do write(dailyFile,tb,hjegnm:1:3,tb,hjlarn:1:3,tb,hjadnm:1:3);
			  if cmbInField       then with mbPtrs[101]^        do for i:=1 to 6 do write(dailyFile,tb,mbn[i]:1:3);
			  if edInField        then write(dailyfile,tb,ednumReport[1]:1:2,tb,ednumReport[2]:1:2,tb,ednumReport[3]:1:2);
			  if elInField        then write(dailyfile,tb,elnumReport[1]:1:2,tb,elnumReport[2]:1:2,tb,elnumReport[3]:1:2);
			  writeln(dailyfile);
			end;

		end; {firstcols}

		write(dailyfile,
		modelyear:10,tb,day:10,tb,month:10,tb,modeldate:1:0,tb,modelday:1,tb,idd:1,tb,precip:1:3,tb,
		totall:1:3,tb,stemreport:1:3,tb,tubreport:1:3,tb,reserves:1:3,tb,sumflin:1:3,tb,
		(sdlsr*10.0):1:3,tb,(nsdlsr*10.0):1:3,tb,(wsd*10.0):1:3,tb,
		branch:1,tb,gs:1:3,tb,gr:1:3,tb,gres:1:3,tb,gtuber:1:3,tb,
		glf:1:3,tb,pcost:1:3,tb,lai*100:1:3,tb,
		totevap:1:3,tb,sumtransp:1:2,tb,totnuptk:1:2,tb,tdelorg*0.05:1:3,tb,
		soiln:1:2,tb,sw:1:2,tb,nveg:1:2);
		if GmInField        then with gmptrs[101]^        do write(dailyFile,tb,gmtot:1:4);
		if TaripoInField    then with Taripoptrs[101]^    do write(dailyFile,tb,predreport:1:4);
		if TmanihotiInField then with Tmanihotiptrs[101]^ do write(dailyFile,tb,predreport:1:4);
		if HJInField        then with hjptrs[101]^        do write(dailyFile,tb,hjegnm:1:3,tb,hjlarn:1:3,tb,hjadnm:1:3);
		if cmbInField       then with mbPtrs[101]^        do for i:=1 to 6 do write(dailyFile,tb,mbn[i]:1:3);
		if cmbInField       then with mbPtrs[101]^        do write(dailyFile,tb,(mbn[2]+mbn[3]+mbn[4]+mbn[5]+mbn[6]):1:3);
		if edInField        then write(dailyfile,tb,ednumReport[1]:1:2,tb,ednumReport[2]:1:2,tb,ednumReport[3]:1:2);
		if elInField        then write(dailyfile,tb,elnumReport[1]:1:2,tb,elnumReport[2]:1:2,tb,elnumReport[3]:1:2);
		writeln(dailyfile);

	end;{casdaily}


  end; {if(MODELDAY mod modout)=0)}

  firstcols:=false;
end; {outputs}


end. { unit }



