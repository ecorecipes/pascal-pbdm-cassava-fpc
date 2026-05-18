{ Authors: 
- Andrew Paul Gutierrez (University of California, Berkeley / CASAS Global 
	(Center for Analysis of Sustainable Agriculture Systems) 
	<casas.kensington gmail.com>
- Luigi Ponti (ENEA - Agenzia nazionale per le nuove tecnologie, l'energia e 
	lo sviluppo economico sostenibile / CASAS Global) <quartese gmail.com>

Copyright: (C) CASAS Global (Center for the Analysis of Sustainable 
	Agricultural Systems)

SPDX-License-Identifier: GPL-3.0-or-later }

Unit wxread;
interface

uses globals,modutils,sysutils;
procedure readwx(var wxfile:text;Firstdate,Lastdate:single;
					  var ndays:word);

Implementation

(*
//for metacot
Procedure SetupStations;
var
	i,icol,irow:integer;
	intstr:string;
	LonMid,LatMid:real;
id:string;
begin
	lonmid:=Longitude;
	latmid:=LatitudeDegrees;
	irow:=1;
	for i:=1 to 100 do{ with CotPlantArray[i]^ do}
	begin
		str(i,intstr);
		id:=location+intstr;
		icol:=((i-1)mod 10)+1;
//Longitude,LatitudeDegrees
writeln(irow:3,icol:3,' ',id);
		if icol=10 then inc(irow);
readln;
	end;
end;
*)

 
procedure wxmissing;
(*
	Check for missing data markers in wx file and fill in with
	default values.
*)
var
	tmiss,smiss,pmiss,rmiss,wmiss:boolean;
	i,j:word;
	tmaxd,tmind,DefaultSolar,DefaultPrecip,DefaultRelHum,DefaultWind : single;
	CountMiss,t1,t2,FillValue,Slope,Intercept:real;
	FirstMissing,LastMissing:word;

begin
	tmiss:=false;
	smiss:=false;
	pmiss:=false;
	rmiss:=false;
	wmiss:=false;

	for i:=1 to ndays do
	begin
		if((temps[i,1]=-99.0)or(temps[i,2]=-99.0))then tmiss:=true;
		if(solar[i]=-99.0)then smiss:=true;
		if(rain[i]=-99.0)then pmiss:=true;
		if(relhum[i]=-99.0)then rmiss:=true;
		if(winds[i]=-99.0)then wmiss:=true;
	end;            

	if tmiss then
	begin
		{default values for celsius temps:}
		tmaxd:=25.0; 
		tmind:=12.0;
//		reporterror('Some temperature data is missing. Using tmax=25, tmin=12.');
	end;
	DefaultSolar:=200.0;
	DefaultPrecip:=0.0;
	DefaultRelHum:=55.0;
	DefaultWind:=1.0;

// Replace missing data with linear interpolations between previous good value and next good value.
// t1=last previous value, t2=first value after dmiss run.
// If dmiss run starts with first value then fill with t2.
// If dmiss run goes to end of data then fill with t1.
// If all data is missing then fill with a default value.?????  

//Check Tmax data:
		CountMiss:=0;
		t1:=-99.0;
		t2:=-99.0;
		for i:=1 to ndays do
		begin

			if (temps[i,1]=-99.0) then
			begin
				CountMiss:=CountMiss+1;
				 //Start of missing data run
				if CountMiss=1 then if i>1 then t1:= temps[i-1,1];
				if CountMiss=1 then FirstMissing:=i-1;
			end;
		
			//Is this dmiss run at end of data?
			if i=ndays then if (temps[i,1]=-99.0) then
			begin
				FillValue:=t1;
				if t1=-99.0 then FillValue:=tmaxd; //all data is missing.????
				for j:=FirstMissing to ndays do temps[j,1]:=FillValue;
				countmiss:=0;
			end;

			if ((temps[i,1]<>-99.0)and(CountMiss>0)) then
			begin

				//found the end of missing data run.
				LastMissing:=i;
				t2:=temps[i,1];
				// compute slope and intercept for y=mx+c
				// Slope=m=(y2-y1)/(x2-x1)
				// Intercept:  c=y-mx 
				// at y=y2 c=y2-m*x2
				//
				if t1>-99.0 then
				begin
					Slope:=(t2-t1)/(LastMissing-FirstMissing); //(y2-y1)/(x2-x1))
					Intercept:=t2-slope*Lastmissing;
					for j:=firstMissing to LastMissing do
						temps[j,1]:=Slope*j+Intercept;

				end;

				//when dmiss run is at beginning of data
				if t1=-99.0 then for j:=firstMissing to LastMissing do temps[j,1]:=t2;

				//reset for remaining tests
				CountMiss:=0;
				t1:=-99.0;
				t2:=-99.0;
			end;

		end;

//Check Tmin data:
		CountMiss:=0;
		t1:=-99.0;
		t2:=-99.0;
		for i:=1 to ndays do
		begin
			if (temps[i,2]=-99.0) then
			begin
				CountMiss:=CountMiss+1;
				 //Start of missing data run
				if CountMiss=1 then if i>1 then t1:= temps[i-1,2];
				if CountMiss=1 then FirstMissing:=i-1;
			end;
			
			//Is this dmiss run at end of data?
			if i=ndays then if (temps[i,2]=-99.0) then
			begin
				FillValue:=t1;
				if t1=-99.0 then FillValue:=tmaxd; //all data is missing.????
				for j:=FirstMissing to ndays do temps[j,2]:=FillValue;
				countmiss:=0;
			end;
 
			if ((temps[i,2]<>-99.0)and(CountMiss>0)) then
			begin
				//found the end of missing data run.
				LastMissing:=i;
				t2:=temps[i,2];
				// compute slope and intercept for y=mx+c
				// Slope=m=(y2-y1)/(x2-x1)
				// Intercept:  c=y-mx 
				// at y=y2 c=y2-m*x2
				//
//writeln('firstmissing,lastmissing,i,temps[i,2]:',firstmissing:4,lastmissing:4,i:4,temps[i,2]:8:3);
				if t1>-99.0 then
				begin
					Slope:=(t2-t1)/(LastMissing-FirstMissing); //(y2-y1)/(x2-x1))
					Intercept:=t2-slope*Lastmissing;
					for j:=firstMissing to LastMissing do
						temps[j,2]:=Slope*j+Intercept;
				end;

				//when dmiss run is at beginning of data
				if t1=-99.0 then for j:=firstMissing to LastMissing do temps[j,2]:=t2;

				//reset for remaining tests
				CountMiss:=0;
				t1:=-99.0;
				t2:=-99.0;
			end;
		end;

//Check Solar data:
		CountMiss:=0;
		t1:=-99.0;
		t2:=-99.0;
		for i:=1 to ndays do
		begin
			if (Solar[i]=-99.0) then Solar[i]:= 200;
(*			begin
				CountMiss:=CountMiss+1;
				 //Start of missing data run
				if CountMiss=1 then if i>1 then t1:= Solar[i-1];
				if CountMiss=1 then FirstMissing:=i-1;
			end;
	
			//Is this dmiss run at end of data?
			if i=ndays then if (Solar[i]=-99.0) then
			begin
				FillValue:=t1;
				if t1=-99.0 then FillValue:=tmaxd; //all data is missing.????
				for j:=FirstMissing to ndays do Solar[j]:=FillValue;
				countmiss:=0;
			end;

			if ((Solar[i]<>-99.0)and(CountMiss>0)) then
			begin
				//found the end of missing data run.
				LastMissing:=i;
				t2:=Solar[i];
				// compute slope and intercept for y=mx+c
				// Slope=m=(y2-y1)/(x2-x1)
				// Intercept:  c=y-mx 
				// at y=y2 c=y2-m*x2
				//
				if t1>-99.0 then
				begin
					Slope:=(t2-t1)/(LastMissing-FirstMissing); //(y2-y1)/(x2-x1))
					Intercept:=t2-slope*Lastmissing;
					for j:=firstMissing to LastMissing do
						Solar[j]:=Slope*j+Intercept;
				end;

				//when dmiss run is at beginning of data
				if t1=-99.0 then for j:=firstMissing to LastMissing do Solar[j]:=t2;

				//reset for remaining tests
				CountMiss:=0;
				t1:=-99.0;
				t2:=-99.0;
			end;
*)
		end;


//Check Rain data:
		CountMiss:=0;
		t1:=-99.0;
		t2:=-99.0;
		for i:=1 to ndays do
		begin
			if (Rain[i]=-99.0) then Rain[i]:= 0.0;
(*			begin
				CountMiss:=CountMiss+1;
				 //Start of missing data run
				if CountMiss=1 then if i>1 then t1:= Rain[i-1];
				if CountMiss=1 then FirstMissing:=i-1;
			end;
			
			//Is this dmiss run at end of data?
			if i=ndays then if (rain[i]=-99.0) then
			begin
				FillValue:=t1;
				if t1=-99.0 then FillValue:=tmaxd; //all data is missing.????
				for j:=FirstMissing to ndays do Rain[j]:=FillValue;
				countmiss:=0;
			end;
 
			if ((Rain[i]<>-99.0)and(CountMiss>0)) then
			begin
				//found the end of missing data run.
				LastMissing:=i;
				t2:=Rain[i];
				// compute slope and intercept for y=mx+c
				// Slope=m=(y2-y1)/(x2-x1)
				// Intercept:  c=y-mx 
				// at y=y2 c=y2-m*x2
				//
				if t1>-99.0 then
				begin
					Slope:=(t2-t1)/(LastMissing-FirstMissing); //(y2-y1)/(x2-x1))
					Intercept:=t2-slope*Lastmissing;
					for j:=firstMissing to LastMissing do
						Rain[j]:=Slope*j+Intercept;
				end;

				//when dmiss run is at beginning of data
				if t1=-99.0 then for j:=firstMissing to LastMissing do Rain[j]:=t2;

				//reset for remaining tests
				CountMiss:=0;
				t1:=-99.0;
				t2:=-99.0;
			end;
*)
		end;
//Check Wind data:
		CountMiss:=0;
		t1:=-99.0;
		t2:=-99.0;
		for i:=1 to ndays do
		begin
			if (Winds[i]=-99.0) then
(*			begin
				CountMiss:=CountMiss+1;
				 //Start of missing data run
				if CountMiss=1 then if i>1 then t1:= Winds[i-1];
				if CountMiss=1 then FirstMissing:=i-1;
			end;
			
			//Is this dmiss run at end of data?
			if i=ndays then if (Winds[i]=-99.0) then
			begin
				FillValue:=t1;
				if t1=-99.0 then FillValue:=DefaultWind; //all data is missing.????
				for j:=FirstMissing to ndays do Winds[j]:=FillValue;
				countmiss:=0;
			end;
 
			if ((Winds[i]<>-99.0)and(CountMiss>0)) then
			begin
				//found the end of missing data run.
				LastMissing:=i;
				t2:=Winds[i];
				// compute slope and intercept for y=mx+c
				// Slope=m=(y2-y1)/(x2-x1)
				// Intercept:  c=y-mx 
				// at y=y2 c=y2-m*x2
				//
				if t1>-99.0 then
				begin
					Slope:=(t2-t1)/(LastMissing-FirstMissing); //(y2-y1)/(x2-x1))
					Intercept:=t2-slope*Lastmissing;
					for j:=firstMissing to LastMissing do
						Winds[j]:=Slope*j+Intercept;
				end;

				//when dmiss run is at beginning of data
				if t1=-99.0 then for j:=firstMissing to LastMissing do Winds[j]:=t2;

				//reset for remaining tests
				CountMiss:=0;
				t1:=-99.0;
				t2:=-99.0;
			end;
*)
		end;



// Check RelHum data:
		CountMiss:=0;
		t1:=-99.0;
		t2:=-99.0;
		for i:=1 to ndays do
		begin
			if (RelHum[i]=-99.0) then RelHum[i]:= 99.0;
(*			begin
				CountMiss:=CountMiss+1;
				 //Start of missing data run
				if CountMiss=1 then if i>1 then t1:= RelHum[i-1];
				if CountMiss=1 then FirstMissing:=i-1;
			end;
			
			//Is this dmiss run at end of data?
			if i=ndays then if (relhum[i]=-99.0) then
			begin
				FillValue:=t1;
				if t1=-99.0 then FillValue:=tmaxd; //all data is missing.????
				for j:=FirstMissing to ndays do RelHum[j]:=FillValue;
				countmiss:=0;
			end;
 
			if ((RelHum[i]<>-99.0)and(CountMiss>0)) then
			begin
				//found the end of missing data run.
				LastMissing:=i;
				t2:=RelHum[i];
				// compute slope and intercept for y=mx+c
				// Slope=m=(y2-y1)/(x2-x1)
				// Intercept:  c=y-mx 
				// at y=y2 c=y2-m*x2
				//
				if t1>-99.0 then
				begin
					Slope:=(t2-t1)/(LastMissing-FirstMissing); //(y2-y1)/(x2-x1))
					Intercept:=t2-slope*Lastmissing;
					for j:=firstMissing to LastMissing do
						RelHum[j]:=Slope*j+Intercept;
				end;

				//when dmiss run is at beginning of data
				if t1=-99.0 then for j:=firstMissing to LastMissing do RelHum[j]:=t2;

				//reset for remaining tests
				CountMiss:=0;
				t1:=-99.0;
				t2:=-99.0;
			end;
*)
		end;

(*

		for i:=1 to ndays do
		begin
		//	if (temps[i,1]=-99.0) then temps[i,1]:=tmaxd;
			if (temps[i,2]=-99.0) then temps[i,1]:=tmind;
		end;


	if smiss then
	begin
		DefaultSolar:=200.0;
//		reporterror('Some solar data is missing.  Using solrad=200.');
		for i:=1 to ndays do
		begin
			if (solar[i]=-99.0) then solar[i]:=DefaultSolar;
		end;
	end;

	if pmiss then
	begin
		DefaultPrecip:=0.0;
//		reporterror('Some rain data is missing.  Using precip=0.0.');
		for i:=1 to ndays do
		begin
			if (rain[i]=-99.0) then rain[i]:=DefaultPrecip;
		end;
	end;
	if rmiss then
	begin
//		reporterror('Some rel. hum. data is missing.  Using 55%.');
		DefaultRelHum:=55.0;
		for i:=1 to ndays do
		begin
			if (relhum[i]=-99.0) then relhum[i]:=DefaultRelHum;
		end;
	end;

	if wmiss then
	begin
//		reporterror('Some wind data is missing.  Using wind default=1.0');
		DefaultWind:=1.0;
		for i:=1 to ndays do
		begin
			if (winds[i]=-99.0) then winds[i]:=DefaultWind;
		end;
	end;
*)

end;


procedure wxunits(fahr,watts,inches,kilom,metersPerSec:boolean);
(*
	  called from readwx to make sure weather data is in expected units.
	  arrays temps, solar, rain, winds are global.
*)
var i:word;
begin
	for i:=1 to ndays do
	begin
		if fahr then
		begin
			{writeln('converting temps data from fahrenheit to celsius.');}
				if temps[i,1]>-99.0 then temps[i,1]:=(temps[i,1]-32)* 0.55555;
				if temps[i,2]>-99.0 then temps[i,2]:=(temps[i,2]-32)* 0.55555;
			end;
		if watts then
		begin
{
All the GIS solrad data should be in watts.
Here we convert it to langleys:
1/0.484=2.066
Conversion units from http://www.ces.ncsu.edu/depts/hort/hil/pdf/hil-710.pdf  2/6/2002

(*
http://www.solarbuzz.com/Consumer/Glossary2.htm
Langley: Unit of solar irradiance, one calorie per square centimeter. 1 L = 41.84 kJ/m2. 
*)
}
//if i=1 then writeln('wxunits sol[1]=',solar[1]:9:3);
			if solar[i]>-99.0 then	solar[i] := solar[i]*2.066; //This converts solrad data from watts to langleys.
		end;

		if inches then
		begin
			{writeln('converting precipitation data from inches to mm.');}
			if rain[i]>-99.0 then rain[i]:=rain[i]*25.4;
		end;
		if kilom then
		begin
			{writeln('converting windspeed data from kilometers to miles.');}
			if winds[i]>-99.0 then winds[i]:=winds[i]*1.609;
		end;
		if metersPerSec then
		begin
			{writeln('converting windspeed data from meters/sec to miles/hour.');}
			if winds[i]>-99.0 then winds[i]:=winds[i]*2.237; {http://www.digitaldutch.com/unitconverter/}
		end;
	end;
end; {procedure wxunits}


procedure DoAdjustWx;
{ Adjust wx data by adding offsets in array wxcons (if they are<>0.0).}
var i:word;
begin
	for i:= 1 to ndays do 
	begin
		if(wxcons[1]<>0.0)then
		begin
			if temps[i,1]>-99.0 then temps[i,1]:=temps[i,1] + wxcons[1];
			if temps[i,2]>-99.0 then temps[i,2]:=temps[i,2] + wxcons[1];
		end;

		if solar[i]>-99.0 then	if(wxcons[2]<>0.0)then solar[i]:=solar[i]+wxcons[2];
		if rain[i]>-99.0 then if(wxcons[3]<>0.0)then rain[i]:=rain[i]+wxcons[3];
		if relhum[i]>-99.0 then if(wxcons[4]<>0.0)then relhum[i]:=relhum[i]+wxcons[4];
		if winds[i]>-99.0 then if(wxcons[5]<>0.0)then winds[i]:=winds[i]+wxcons[5];
	end;
end;


procedure readwx(var wxfile:text;Firstdate,Lastdate:single;
					  var ndays:word);
(*
	read weather data from text file wxfile which has been linked
	(assigned) to a disk file.
*)
var
	fahr,watts,inches,kilom,MetersPerSec,Adjustwx,ok:boolean;
	wxday : single;
//	wxdayprev : single;
	month,day,year,mm,dd,yy:integer;
	i:word;
	tb:char;
	a:array[0..255]of char;
begin
	tb:=#9; //tab
	assign(wxfile,wxfilename);
	{$i-} reset(wxfile) {$i+};

	readln(wxfile,wxid);

	strPCopy(a,wxid); //get Pascal string into null-terminated string

	//find 1st tab in wxid header
	i:=0;	repeat inc(i) until a[i]=tb; {repeat inc(i) until a[i]=tb;} a[i]:=#0;{null}
	//transfer wxid up to 1st tab into pascal string 'location'.
	//this avoids the extra text that may be at the end of the header.	
	location:=strpas(a);	
	readln(wxfile,Longitude,LatitudeDegrees);              {read long,latitude}


//test code for metacot
(* writeln('wxid=     ',wxid);
writeln('location= ',location);
readln;
//setupstations;
readln;
*)

	{Convert LatitudeDegrees from degrees to radians}
	{1 degrees = 0.0174533 radians}
	LatitudeRadians:= 0.0174533*LatitudeDegrees;
	Adjustwx:=false;
	for i:=1 to 5 do if wxcons[i]<>0.0 then Adjustwx:=true;

//preset all wx vars to -55
	for i:=1 to ndays do
	begin
		temps[i,1]:=-99;
		temps[i,2]:=-99;
		solar[i]:=-99;
		rain[i]:=-99;
		relhum[i]:=-99;
		winds[i]:=-99;
	end;

	readln(wxfile);  {read line of column headers in data file}
	
	{read first line of data}
	readln(wxfile,month,day,year,temps[1,1],temps[1,2],solar[1],rain[1],
			 relhum[1],winds[1]);
	wxday:= rdate(year,julian(month,day,year));
	ok:=true;

	if (Modelstartdate < wxday) then
	begin
		ReportError('Model start date precedes weather data.');
		runok:=false;
		exit;
	end;

	{read from wx file until date = ModelStartDate  or eof}
	while (ok and (ModelStartdate > wxday) and not eof(wxfile)) do
	begin
		 readln(wxfile,month,day,year,temps[1,1],temps[1,2],solar[1],
				  rain[1],relhum[1],winds[1]);
(*	writeln(month:10,day:10,year:10,temps[1,1]:10:2,temps[1,2]:10:2,solar[1]:10:2,
				  rain[1]:10:2,relhum[1]:10:2,winds[1]:10:2); 	
*)				  
		 wxday:=rdate(year,julian(month,day,year));
	end;

	if(Modelstartdate > wxday)then
	begin
	{	writeln('Weather data ends before model start date.');}
		reporterror('Weather data ends before model start date.');
		runok:=false;
		exit;
	end;

	if ok then
	begin
{		wxday:=wxday-1;}{for sequence test}
		mm:=13; //mm is month
		i:=2;

		while ((not eof(wxfile)) and (wxday < Lastdate)and (mm>0)) do
		begin

			if (not (eof(wxfile)))then
			begin
				readln(wxfile,mm,dd,yy,temps[i,1],temps[i,2],solar[i],
					rain[i],relhum[i],winds[i]);
				if mm>0 then begin
						 month:=mm;day:=dd;year:=yy;
					     end;

//				wxdayPrev:=wxday;
				if month>0 then	wxday:=rdate(year,julian(month,day,year));


//turn on the following block and line 563? to verify wx data date sequence:
					{
					if (wxday-wxdayPrev)<>1 then
					begin
						writeln('WEATHER DATA NOT IN SEQUENCE AT DATE ',month:2,day:3,year:5);
						readln;
					end;
					}	

				inc(i);
			end;
		end;

		{here if wxday<Lastdate there is not enough data in the wx file }
		if (wxday<Lastdate) then
		begin
//			writeln('end date adjust.  wxday,lastdate:',wxday:8:1,lastdate:8:1);
			reporterror('Model end date adjusted to end of weather data.');
			ndays:=trunc(wxday-ModelStartDate);
		 end;
	end;

	if ok then wxmissing;
(*
dec(i);
writeln('last i=',i:9);
writeln(mm,dd:3,yy:5,temps[i,1]:7:2,temps[i,2]:7:2,solar[i]:7:0,rain[i]:7:2,relhum[i]:7:2,winds[i]:7:2);
writeln(' wxday,lastdate:',wxday:8:0,lastdate:8:0);
readln;
*)	
	fahr:=false;	//gis data is in Celsius
	watts:=true;	//All the GIS solrad data should be in watts and must be converted to Langleys.
	inches:=false;	//gis precip data is in mm.
	kilom:=false;	//gis wind data is meters/sec.
	meterspersec:=true; //gis wind data is meters/sec.
		
	wxunits(fahr,watts,inches,kilom,metersPerSec);
	if Adjustwx then doAdjustwx;	//if *.ini has adjustment values <>0.0;

end; {procedure readwx}
end.
