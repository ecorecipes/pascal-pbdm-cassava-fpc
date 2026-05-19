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

Procedure WriteHeader(var outfile:text);
{Write GIS output header using tab delimitted}
begin
    	write(outFile,'Model',tb,'Date',tb,'Time',tb,'WxFile',tb,'Long',tb,'Lat',tb,'JdStart',tb,'JdEnd',tb,'Month',tb,'Day',tb,'Year');
	write(outfile,tb,'dd',tb,'root',tb,'stem',tb,'leaf',tb,'tuber',tb,'leafnum',tb,'sdlsr',tb,'nsdlsr',tb,'wsd',tb,'sqdecplt',tb,'lai');
	write(outfile,tb,'evapsoil',tb,'fielddem',tb,'avgev',tb,'wvgwd');
	if GmInField        then write(outfile,tb,'gmtot');
	if TaripoInField    then write(outfile,tb,'TariNum');
	if TmanihotiInField then write(outfile,tb,'TManNum');
	if HJInField        then write(outfile,tb,'hjegnm',tb,'hjlarnm',tb,'hjadnm');
	if cmbinfield       then write(outfile,tb,'mb1',tb,'mb2',tb,'mb3',tb,'mb4',tb,'mb5',tb,'mb6');
	if edInField        then write(outfile,tb,'ed1',tb,'ed2',tb,'ed3');
	if elInField        then write(outFile,tb,'el1',tb,'el2',tb,'el3');

	writeln(outFile);
end;


Procedure OpenGisFile(modelName:string);
(*
Open gisfiles for appending or create new ones if they don't exist.
An output line will be at end of season and optionally at intervals during the season.
There will be a separate file for each of those outputs.  

If the Gis program is Arcinfo:
	 The file names will be of the form 'Out00xxx' indicating:
		Out=output file, xxx is the sequence number of the output (or end for harvest output).

If the Gis Program is Grass:
	 The file names will be of the form 'Model_ddMONyy_00xxx' indicating:
		Model=Alfalfa,Olive,Cotton,... ddMONyy is date when the files are created, xxx is the sequence number of the output (or end for harvest output).
*)
var
	mm:string;
	i:integer;
begin
	inc(GisFileIndex);
	shortdateformat:='ddmmmyy'; //delphi date format 01Jan06

	if ((DoEndFile) and (GisOutputTarget=1)) then gisfilename:='OUT00end.txt'
	
	else

	begin
		{Filename includes the index number.}
		if(GisFileIndex<10)then
		begin
			str(gisfileindex:1,mm);
			mm:='0000'+mm;
		end
		else
		if(GisFileIndex<100)then
		begin
			str(gisfileindex:2,mm);
			mm:='000'+mm;
		end
		else
		if(GisFileIndex<1000)then
		begin
			str(gisfileindex:2,mm);
			mm:='00'+mm;
		end
		else
		if(GisFileIndex<10000)then
		begin
			str(gisfileindex:2,mm);
			mm:='0'+mm;
		end;

		if GisOutputTarget=1 then gisfilename:='OUT'+mm+'.txt';
		if GisOutputTarget=2 then gisfilename:=ModelName+'_'+DatetoStr(date)+'_'+mm+'.txt';

	end;

//	if((GisFileIndex>1)or DoEndFile)then	//skip first year output unless running only 1 year.
	if(GisFileIndex>1)then	//skip first year output unless running only 1 year.
	begin
		assign(gisfile,gisFilename);
		{$i-} append(gisFile); {$i+}
		i:=ioresult;
		ok:=(i = 0);
		if not ok then
		begin
			if i=2 then rewrite(gisfile); 
			WriteHeader(gisfile);
			if i=2 then writeln(gisfilesListfile,gisfilename); //append to the list of file names to use at end for averages.
		end;
	end;	
end;


