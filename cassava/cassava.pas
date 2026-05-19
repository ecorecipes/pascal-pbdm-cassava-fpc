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

{$N+,E-} (* compiler directive=use mathchip *)
uses globals,Modutils,bio,setupcas,init,wxread,spatial,nitr,output,casbio,water,models,Means,
	SummaryUnit,sysutils;
{$I GetDDs.pas}
{$I harv.pas}
{$I setsvar.pas}
{$I pools.pas}
{$I Presence.pas}
{$I GisOpenFiles.pas}
{$I GisOutput.pas}
{$I ResetSums.pas}

label ErrorExit;

var
	dda,ddb:single;
	daysdone:real;
	iday:word;
	ok:boolean;
	i:integer;
Begin
	Runok:=true;
	setsvar;
	firstyear:=true;

	ReadInputs;

	assign(gisfilesListfile,'GisFilesList.txt'); //used by makeavg
	{$i-} append(gisFilesListfile); {$i+}
	i:=ioresult;
	ok:=(i = 0); //if the file exists then we may  append a line of output later (in GisOpenFiles).
	if not ok then //If the file doesn't exist then create it.
	if i=2 then rewrite(gisFilesListfile); 

	{ get weather data for the run.}
	readwx(wxfile,ModelStartDate,ModelEndDate,ndays);

  	EndFileWritten:=false;

	if (not runok)then goto ErrorExit;

	daysdone:=0.0;

 	Presence; {select presence/absence values for each year}

	InitYear; {initializations for each year}

	InitMisc;

	zeropools;

	for iday:=1 to Ndays do
	Begin
		modelday:=iday; {loop control needs to be local, modelday must be global.}
		ModelDate:=Rdate(Modelyear,jday);
		caland(ModelYear,jday,month,day,ok);

		daydegrees(modelday,base,dda,ddb);
	{Keating & Evenson 1979 6/1/2024 -- same dd for all varieties}
		dda:=max(0.0, 106.8*(0.0095*(Tmean-14.85)/(1 +power(1.6,(Tmean-33.55)))/1.209)); 
		tddfield:=tddfield+dda; {tdd>cassava.base from day 1.}

		{Get tmean,solrad,precip,wind}
		GetDailyWx;
		{Get dd for field using cassava base.}
		base:=casvar.base;
		
		{Get today's dda for each plant.}
		Getdds(modelday,ModelDate,casvar,casPtrs,ncas);

		Getlais; {Get lai for each plant and for entire field}

		{Get evap and demand for field and for each plant}
		Waterdemands;

		nuptk:=0.0;
	{
		if((ModelDate>d1cmb)or(ModelDate>gmstartday))then
		begin
			inc(immigcounter);
			if immigcounter<60 then immigmethod:=1 else immigmethod:=immigmethodsave;
		end;
	}

		Plantsloop; {Call plant and insect models at each plant location.}

		Orgnupd; {allow org n to become available }

		{ Update soilwater each day using field evap., precip, transpiration.}
		Waterbalance;

		Setsides; {adjust areas of plants}

		GetMeans;
	
		Outputs;

		inc(jday);

		if jday>yearLength then
		begin
			jday:=1;
			inc(ModelYear);
			yearLength:=365;
			if(ModelYear mod 4)=0 THEN yearLength:=366;
			pdate:=pdate+yearlength;
		end;

		if immigmethod = 2 then resetpools;
		daysdone:=daysdone+1.0;
		
		//if((GisOutputInterval>0) and (ModelDate<>ModelEndDate) and ((modelday mod GisOutputInterval)=0))then
		//This assumes GIS output desired at end of each year.
		//Can't use interval of 365 over many years bcause of leapyear.
		// Just check jday=365  (Northern hemisphere) (jday=183 in south?)
		if((jday=365) and (EndFileWritten=false))then
		begin

			{Write gis output using tab delimitted.  Extra outputs pre-harvest.}
			DoEndFile:=false;
			if (GisOutputInterval>0) then OpenGisFile('Cassava');
			if (GisOutputInterval>0) then GisOutput;
			if Summary then
				if(GisFileIndex>1)then	WriteSummary;//skip first year summary output
			ResetSums;
		end;

		if modeldate=ModelEndDate then
		begin
			Presence; 		{select presence/absence values for each year}
			InitYear;      	{initializations for each year}
			ModelEndDate:=ModelEndDate+yearlength;
			InitMisc;
			zeropools;
			DoEndFile:=true;
			OpenGisFile('Cassava');
			GisOutput;
			EndFileWritten:=true;
			if Summary then
				if(GisFileIndex>1)then WriteSummary;//skip first year summary output
			ResetSums;
		end;
	end; {modelday=1 to ndays}

{ GIS output at end of season}
	firstyear:=false;
	if nyears>1 then  ReclaimStack; {free up temporary storage before next season}

ErrorExit:
	{In case of early exit always do an END file if one hasn't been done.}

	if((EndFileWritten=false)and (GisOutputTarget=1)) then 
	begin
		{Write cotout file for gis using tab delimitted.}
		DoEndFile:=true;
		OpenGisFile('Cassava');
		GisOutput;
	end;
	{Close any files.}
	if daily then close(dailyfile);
	close(errorlogfile);

	{$I-} //turn off I/O checking in case an error caused early exit.
	close(gisfileslistfile);
	{I+}

end. {Cassava (GIS) program}

	
