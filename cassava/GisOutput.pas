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

Procedure GisOutput;
var
	i:word;
	TimeNow:string[11];
begin
	if((GisFileIndex>1)or DoEndFile)then	//skip first year output unless running only 1 year.
	begin
		{In output formats, min field size of 1 is used along with tab delimiting to prevent leading blanks.}
		{replace blank in time string:}
		TimeNow:=TimeToStr(time);
		for i:=1 to 11 do if (TimeNow[i]=' ')then TimeNow[i]:='-';

		with casPtrs[101]^ do write(GisFile,'CasGIS',tb,DatetoStr(date),tb,TimeNow,tb,
		wxfilename,tb,longitude:1:4,tb,latitudeDegrees:1:4,tb,JdayStart:1,tb,JdayEnd:1,tb,
	    	month:1,tb,day:1,tb,modelyear:1,tb,tddfield:1:0,tb,
		totalr:1:3,tb,totals:1:3,tb,totall:1:3,tb,tuber:1:3,tb,tfolnum:1:3,tb,
		sdlsr:1:2,tb,nsdlsr:1:2,tb,wsd:1:2,tb,sqdmpl:1:3,tb,fieldlai:1:3,tb,
		fieldevapsoil:1:3,tb,fielddem:1:3,tb,avgev:1:3,tb,avgwd:1:3);

		if GmInField        then with gmptrs[101]^ do write(GisFile,tb,gmtot:1:4);
		//with gmptrs[101]^ do writeln('GISout',tb,gmtot:1:4); readln;
		if TaripoInField    then with Taripoptrs[101]^ do write(GisFile,tb,predreport:1:4);
		if TmanihotiInField then with Tmanihotiptrs[101]^ do write(GisFile,tb,predreport:1:4);
		if HJInField        then with hjptrs[101]^ do write(GisFile,tb,hjegnm:1:3,tb,hjlarn:1:3,tb,hjadnm:1:3);
		if cmbinfield       then with mbPtrs[101]^  do for i:=1 to 6 do write(GisFile,tb,mbn[i]:1:3);
		if edInField        then with edPtrs[101]^  do for i:=1 to 3 do write(GisFile,tb,ednum[i]:1:3);
		if elInField        then with elPtrs[101]^  do write(GisFile,tb,elnum[1]:1:3,tb,elnum[2]:1:3,tb,elnum[3]:1:3);

		{Write an EOL to the file.}
		writeln(Gisfile);

		close(gisfile);

	end; //if((GisFileIndex>1)or DoEndFile

end;


