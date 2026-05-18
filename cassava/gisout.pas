{ Authors: 
- Andrew Paul Gutierrez (University of California, Berkeley / CASAS Global 
	(Center for Analysis of Sustainable Agriculture Systems) 
	<casas.kensington gmail.com>
- Luigi Ponti (ENEA - Agenzia nazionale per le nuove tecnologie, l'energia e 
	lo sviluppo economico sostenibile / CASAS Global) <quartese gmail.com>

Copyright: (C) CASAS Global (Center for the Analysis of Sustainable 
	Agricultural Systems)

SPDX-License-Identifier: GPL-3.0-or-later }

Procedure GisOutput;
var
	i:word;
	tempo:string[11];
begin

	{In output formats, min field size of 1 is used along with tab delimiting to prevent leading blanks.}
	{replace blank in time string:}
	tempo:=TimeToStr(time);
	for i:=1 to 11 do if (tempo[i]=' ')then tempo[i]:='-';

	with casptr[101]^ do write(GisFile,'CasGIS',tb,DatetoStr(date),tb,tempo,tb,
	wxfilename,tb,longitude:1:4,tb,latitude:1:4,tb,JdayStart:1,tb,JdayEnd:1,tb,
    	month:1,tb,day:1,tb,modelyear:1,tb,tddfield:1:0,tb,
	totalr:1:3,tb,totals:1:3,tb,totall:1:3,tb,tuber:1:3,tb,tfolnum:1:3,tb,
	sdlsr:1:2,tb,nsdlsr:1:2,tb,wsd:1:2,tb,sqdmpl:1:3,tb,fieldlai:1:3,tb,
	fieldevapsoil:1:3,tb,fielddem:1:3,tb,avgev:1:3,tb,avgwd:1:3,tb);

(*
//these insect means are replaced by cumulative means below.
	with gmptrs[101]^ do write(GisFile,gmtot:1:4,tb);
	with Taripoptrs[101]^ do write(GisFile,predreport:1:4,tb);
	with Tmanihotiptrs[101]^ do write(GisFile,predreport:1:4,tb);
	with hjptrs[101]^ do write(GisFile,hjegnm:1:3,tb,hjlarn:1:3,tb,hjadnm:1:3,tb);
	with mbptr[101]^  do for i:=1 to 6 do write(GisFile,mbn[i]:1:3,tb);
	with edptr[101]^  do for i:=1 to 3 do write(GisFile,ednum[i]:1:3,tb);
	with elptr[101]^  do write(GisFile,elnum[1]:1:3,tb,elnum[2]:1:3,tb,elnum[3]:1:3);
*)
//cumulative sums since previous output of insect values for Gis and Summaries outputs.	
	write(GisFile,gSum:1:4,tb);
	write(GisFile,tariSum:1:4,tb);
	write(GisFile,tmaniSum:1:4,tb);
	write(GisFile,HjEggSum:1:3,tb,HjLarSum:1:3,tb,HjAdlSum:1:3,tb);
	for i:=1 to 6 do write(GisFile,mbnSum[i]:1:3,tb);
	for i:=1 to 3 do write(GisFile,ednumSum[i]:1:3,tb);
	for i:=1 to 3 do write(GisFile,elnumSum[i]:1:3,tb);

	{Write an EOL to the file.}
	writeln(Gisfile);

	close(gisfile);
end;


