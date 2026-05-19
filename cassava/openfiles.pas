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
    	write(outFile,'Model',tb,'Date',tb,'Time',tb,'WxFile',tb,'Long',tb,'Lat',tb,'JdStart',tb,'JdEnd',tb,'Month',tb,'Day',tb,'Year',tb);
	write(outfile,'dd',tb,'root',tb,'stem',tb,'leaf',tb,'tuber',tb,'leafnum',tb,'sdlsr',tb,'nsdlsr',tb,'wsd',tb,'sqdecplt',tb,'lai',tb);
	write(outfile,'evapsoil',tb,'fielddem',tb,'avgev',tb,'wvgwd',tb);
	write(outfile,'gmtot',tb,'TariNum',tb,'TManNum',tb,'hjegnm',tb,'hjlarnm',tb,'hjadnm',tb);
	write(outfile,'mb1',tb,'mb2',tb,'mb3',tb,'mb4',tb,'mb5',tb,'mb6',tb);
	write(outfile,'ed1',tb,'ed2',tb,'ed3',tb);
	write(outFile,'el1',tb,'el2',tb,'el3');

	writeln(outFile);
end;


Procedure OpenGisFile;
(*
Open gisfiles for appending or create new ones if they don't exist.
An output line will be at end of season and optionally at intervals during the season.
There will be a separate file for each of those outputs.  
The file names will be of the form 'Out00xxx' indicating:
	Out=output file, xxx is the sequence number of the output (or end for harvest output).
*)
var
	mm:string;

begin

	{Make file name.}
	if (DoEndFile) then gisfilename:='OUT00end.txt'
	else
	begin
		{Filename includes the index number.}
		inc(GisFileIndex);
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

		gisfilename:='OUT'+mm+'.txt';

	end;

	assign(gisfile,gisFilename);
	{$i-} append(gisFile); {$i+}
	i:=ioresult;
	ok:=(i = 0);
	if not ok then
	begin
		if i=2 then rewrite(gisfile); 
		WriteHeader(gisfile);
	end;
end;


