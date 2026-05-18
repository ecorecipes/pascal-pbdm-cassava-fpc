{ Authors: 
- Andrew Paul Gutierrez (University of California, Berkeley / CASAS Global 
	(Center for Analysis of Sustainable Agriculture Systems) 
	<casas.kensington gmail.com>
- Luigi Ponti (ENEA - Agenzia nazionale per le nuove tecnologie, l'energia e 
	lo sviluppo economico sostenibile / CASAS Global) <quartese gmail.com>

Copyright: (C) CASAS Global (Center for the Analysis of Sustainable 
	Agricultural Systems)

SPDX-License-Identifier: GPL-3.0-or-later }

Unit SummaryUnit;

interface
uses globals,modutils,sysutils;

Procedure WriteSummary;

Implementation

Procedure WriteSummary;
var
	TimeNow:string[11];
	i:byte;
 
begin
	SummaryFilename:='CassavaSummaries.txt';
	assign(SummaryFile,SummaryFilename);

	if not(FileExists(Summaryfilename))then
	begin
		rewrite(SummaryFile); 

		{If this is the first time this file is to be used write the header.}
	    write(SummaryFile,'Model',tb,'Date',tb,'Time',tb,'WxFile',tb,'Long',tb,'Lat',tb,
							'JdStart',tb,'JdEnd',tb,'Month',tb,'Day',tb,'Year');
		write(SummaryFile,tb,'dd',tb,'root',tb,'stem',tb,'leaf',tb,'tuber',tb,'leafnum',tb,
							'sdlsr',tb,'nsdlsr',tb,'wsd',tb,'sqdecplt',tb,'lai');
		write(SummaryFile,tb,'evapsoil',tb,'fielddem',tb,'avgev',tb,'wvgwd');
		write(SummaryFile,tb,'gmtot');
		write(SummaryFile,tb,'TariNum');
		write(SummaryFile,tb,'AmanNum');
		write(SummaryFile,tb,'hjlarnm');
		write(SummaryFile,tb,'Log10Cmb1to6');
		write(SummaryFile,tb,'Log10ed2');
		write(SummaryFile,tb,'log10el2');
		write(Summaryfile,tb,'GM01',tb,'Tarip01',tb,'Amani01',tb,'HJ01',tb,'CMB01',tb,'ED01',tb,'EL01',tb,'CMfung01');

		writeln(Summaryfile);
	end
	else {$i-} append(SummaryFile); {$i+};


	{In output formats, min field size of 1 is used along with tab delimiting to prevent leading blanks.}
	{replace blank in time string:}
	TimeNow:=TimeToStr(time);
	for i:=1 to 11 do if (TimeNow[i]=' ')then TimeNow[i]:='-';

if modelyear <= 2010 then 
	begin
	with casPtrs[101]^ do write(SummaryFile,'CasGIS',tb,DatetoStr(date),tb,TimeNow,tb,
	wxfilename,tb,longitude:1:4,tb,latitudeDegrees:1:4,tb,JdayStart:1,tb,JdayEnd:1,tb,
    	month:1,tb,day:1,tb,modelyear:1,tb,tddfield:1:0,tb,
	totalr:1:3,tb,totals:1:3,tb,totall:1:3,tb,tuber:1:3,tb,tfolnum:1:3,tb,
	sdlsr:1:2,tb,nsdlsr:1:2,tb,wsd:1:2,tb,sqdmpl:1:3,tb,fieldlai:1:3,tb,
	fieldevapsoil:1:3,tb,fielddem:1:3,tb,avgev:1:3,tb,avgwd:1:3);

//avg cumulative sum/plant since previous output of insect values for Gis and Summaries outputs.	
	//with gmptrs[101]^ do write(GisFile,tb,gmtot:1:4);
	//with gmptrs[101]^ do write(SummaryFile,tb,gmSum:1:4);
	//with gmptrs[101]^ do writeln(gmtot:1:4); readln;
	//with Taripoptrs[101]^ do write(SummaryFile,tb,TariSum:1:4);
	//with Tmanihotiptrs[101]^ do write(SummaryFile,tb,TmaniSum:1:4);

	write(SummaryFile,tb,gmSum/ncas:1:4);
	//writeln('Summary',tb, gmsum:1:4);
	write(SummaryFile,tb,TariSum/ncas:1:4);
	write(SummaryFile,tb,TmaniSum/ncas:1:4);

	write(SummaryFile,tb,HjLarSum:1:3);
	write(SummaryFile,tb,log10(mbnSum[1]+mbnSum[2]+mbnSum[3]+mbnSum[4]+mbnSum[5]+mbnSum[6]):1:3);
	write(SummaryFile,tb,log10(ednumSum[2]+1):1:3);
	write(SummaryFile,tb,log10(elnumSum[2]+1):1:3);

	if GmInField        then write(SummaryFile,tb,'1') else write(SummaryFile,tb,'0');
	if TaripoInField    then write(SummaryFile,tb,'1') else write(SummaryFile,tb,'0');
	if TmanihotiInField then write(SummaryFile,tb,'1') else write(SummaryFile,tb,'0');
	if HJInField        then write(SummaryFile,tb,'1') else write(SummaryFile,tb,'0');
	if cmbinfield       then write(SummaryFile,tb,'1') else write(SummaryFile,tb,'0');
	if edInField        then write(SummaryFile,tb,'1') else write(SummaryFile,tb,'0');
	if elInField        then write(SummaryFile,tb,'1') else write(SummaryFile,tb,'0');
	if FMinfield		then write(SummaryFile,tb,'1') else write(SummaryFile,tb,'0');
	

	writeln(SummaryFile);
	//tddfield:=0.0;
	end;

	close(SummaryFile);
end;
end. { unit }



