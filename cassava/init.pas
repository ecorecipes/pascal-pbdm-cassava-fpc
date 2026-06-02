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

unit init;
interface
uses mb,para,gmite,preds,globals,Modutils,nitr,water,setupcas,Hyperaspis,sysutils,rng;

procedure ReadInputs;
procedure initMisc;
procedure Casvariety;
procedure InitYear;
Procedure ReclaimStack;

implementation

var
	cbf:single;
	jyr:integer;
	setfile : text;
	casiety:byte;
	datespread:word;
	hdate:single;

(*
//shufl moved here to try to fix type mismatch 01/25/05
procedure shufl(var deck:i100; n:integer);
{
	Deck is an integer array of length 100.
	n is the number of cells to deal with.
	Return array Deck with the first N cells containing integers from
	1 to n shuffled.
}
var
	i,j:integer;
	hit:boolean;
	bool:array[1..100]of boolean;
begin
	for i:=1 to n do bool[i]:=false;
	for i:=1 to n do deck[i]:=0;

	for i:=1 to n do
	begin
		j:=trunc(n*random)+1;
		hit:=false;
		repeat
			if bool[j] then begin inc(j); if j>n then j:=1 ;end
			else
			begin
				deck[i]:=j;
				bool[j]:=true;
				hit:=true;
			end;
		until hit;
	end;
end;
*)

procedure readaster;
{
Verify order of separator lines in setup file.
Test first character for asterisk.  If not report and halt.
}
var jk:char;

const
 aster:char='*';

begin
	readln(setfile,jk);
	if jk <> aster then
	begin
		reporterror('Input out of sequence in setup file.  Expected to read asterisk.');
		Runok:=false;
		exit;
	end;
end;

{$IFDEF DUMPINPUTS}
procedure DumpParsedInputs;
var dmp: text;
begin
	assign(dmp,'inputs_dump.txt'); rewrite(dmp);
	writeln(dmp,'longitude=',Longitude);
	writeln(dmp,'latitudedegrees=',LatitudeDegrees);
	writeln(dmp,'month1=',month1,' day1=',day1,' year1=',year1);
	writeln(dmp,'month2=',month2,' day2=',day2,' year2=',year2);
	writeln(dmp,'GisOutPutInterval=',GisOutPutInterval);
	writeln(dmp,'jdayStart=',jdayStart,' jdayEnd=',jdayEnd,' ndays=',ndays);
	writeln(dmp,'ncasin=',ncasin,' plantdistr=',plantdistr,' scattered=',scattered);
	writeln(dmp,'datespread=',datespread);
	writeln(dmp,'wxcons1=',wxcons[1],' wxcons2=',wxcons[2],' wxcons3=',wxcons[3],' wxcons4=',wxcons[4],' wxcons5=',wxcons[5]);
	writeln(dmp,'casiety=',casiety);
	writeln(dmp,'cbf=',cbf);
	writeln(dmp,'ranstick=',ranstick);
	writeln(dmp,'plantspacingin=',plantspacingin,' rowspacingin=',rowspacingin);
	writeln(dmp,'plantspacing=',plantspacing,' rowspacing=',rowspacing);
	writeln(dmp,'casdensity=',casdensity,' halfx=',halfx,' halfy=',halfy);
	writeln(dmp,'pspacedist=',pspacedist,' rspacedist=',rspacedist);
	writeln(dmp,'totpwp=',totpwp,' soilwin=',soilwin,' soilwmaxin=',soilwmaxin);
	writeln(dmp,'orgin=',orgin,' soilnin=',soilnin,' phosphate=',phosphate);
	writeln(dmp,'nitdis=',nitdis,' nitdisvar=',nitdisvar,' nitgrad=',nitgrad);
	writeln(dmp,'watdis=',watdis,' watdisvar=',watdisvar,' watgrad=',watgrad);
	writeln(dmp,'modout=',modout,' daily=',daily,' summary=',summary,' GisOutputTarget=',GisOutputTarget);
	writeln(dmp,'CMBinfield=',CMBinfield,' ndlcmb=',ndlcmb,' cmbbeta=',cmbbeta,' cmbrem=',cmbrem,' cmbDelay=',cmbDelay);
	writeln(dmp,'mbimmigprobin=',mbimmigprobin,' mbinsin=',mbinsin,' mbinspcnt=',mbinspcnt);
	writeln(dmp,'elinfield=',elinfield,' mbLevElStart=',mbLevElStart,' elimmigprobin=',elimmigprobin,' elinsin=',elinsin,' elinspcnt=',elinspcnt);
	writeln(dmp,'edinfield=',edinfield,' mbLevEdStart=',mbLevEdStart,' edimmigprobin=',edimmigprobin,' edinsin=',edinsin,' edinspcnt=',edinspcnt);
	writeln(dmp,'gminfield=',gminfield,' gmimmigprobin=',gmimmigprobin,' gminsin=',gminsin,' gminspcnt=',gminspcnt);
	writeln(dmp,'Taripoinfield=',Taripoinfield,' gmWgtTaripoStart=',gmWgtTaripoStart,' Taripoimmigprobin=',Taripoimmigprobin);
	writeln(dmp,'Tmanihotiinfield=',Tmanihotiinfield,' gmWgtTmanihotiStart=',gmWgtTmanihotiStart,' Tmanihotiimmigprobin=',Tmanihotiimmigprobin);
	writeln(dmp,'hjinfield=',hjinfield,' ndelayhj=',ndelayhj,' HJMBLEV=',HJMBLEV,' HJimmigprob=',HJimmigprob,' hjinsin=',hjinsin,' hjinspcnt=',hjinspcnt);
	writeln(dmp,'fminfield=',fminfield,' immigmethod=',immigmethod,' randseed=',randseed);
	close(dmp);
end;
{$ENDIF}

procedure ReadInputs;
type string10 = string[10];
var

	ch             : char;
	i,j:integer;
	j1,code:integer;
	NowTime: TDateTime; 
begin

	{Setup error log.}
	assign(errorlogfile,'errorlog');
	{$i-} append(errorlogfile) {$i+};
	i:=ioresult;
	ok:=(i = 0);
	if not ok then
	begin
		if i=2 then rewrite(errorlogfile); 
	end;


{Get command line parameters.}

	SetupFileName:=paramstr(1);
	location:=SetupFileName;

{First date on command line is first date of weather data to retrieve. }
{The start of season  is ?}
 
	val(paramstr(2),month1,code);
	if ((code>0)or (month1>12)) then
	begin
		reporterror('Error in date month1 ');
		Runok:=false;
		exit;
	end;

	val(paramstr(3),day1,code);
	if code>0 then
	begin
		reporterror('Error in date day1 ');
		Runok:=false;
		exit;
	end;

	val(paramstr(4),year1,code);
	if code>0 then
	begin
		reporterror('Error in date year1 ');
		Runok:=false;
		exit;
	end;

{Second date on command line specifies the harvest date.  Only the Julian day relative to the starting date is used.}
{Only 1 season is delimited with these dates.}
{Harvest date may be determined by running avg of tmin.}
{The nr of seasons in a run of the model is determined by the setup file parameter 'nrSeasons'.}
	val(paramstr(5),month2,code);
	if ((code>0)or(month2>12)) then
	begin
		reporterror('Error in date month2 ');
		Runok:=false;
		exit;
	end;

	val(paramstr(6),day2,code);
	if code>0 then
	begin
		reporterror('Error in date day2 ');
		Runok:=false;
		exit;
	end;

	val(paramstr(7),year2,code);
	if code>0 then
	begin
		reporterror('Error in date year2 ');
		Runok:=false;
		exit;
	end;

	val(paramstr(8),GisOutPutInterval,code);  {0=end of season only, 10=every 10 days, 20=every 20 days,... }
	if code>0 then
	begin
		reporterror('Error in GIS output interval ');
		Runok:=false;
		exit;
	end;

	jdayStart:=julian(month1,day1,year1);
	ModelStartDate:=rdate(year1,jdayStart);
	pdate:=modelstartdate;
	modelyear:=year1;
	yearLength:=365;
	if(ModelYear mod 4)=0 THEN yearLength:=366;

	jdayEnd:=julian(month2,day2,year2);
	ModelEndDate:=rdate(year2,jdayEnd);
{	if JdayEnd>jdayStart then DaysInSeason:=JdayEnd-jdayStart+1 else DaysInSeason:=JdayEnd+365-jdayStart+1;}

	ndays:=round(ModelEndDate-ModelStartDate)+1;

	wxFilename:=paramstr(9);
// open weather file and get latitude.  Latitude is needed in routine SetDates.
	assign(wxfile,wxfilename);
	{$i-} reset(wxfile) {$i+};
	ok:=(ioresult=0);
	while not ok do
	begin
		reporterror('Initialize cot. Wx file not found: "'+wxfilename+'"');
		Runok:=false;
		exit;
	end;
	readln(wxfile);	//skip first line in wx file.
	readln(wxfile,Longitude,LatitudeDegrees);
	close(wxfile);
// wxfile will be opened again in Readwx.



{Open the setup file cassava.ini}
	assign(setFile,SetupFilename);
	{$i-} reset(setFile) {$i+};
	ok:=(ioresult = 0);
	if not ok then
	begin
		reporterror('Setup file not found ');
		Runok:=false;
		exit;
	end;

	castrue:=true;

	readln(setfile,ncasin); {number of cas plants}
	ncas:=ncasin;
	GISirngck(ncasin,1,100, 'number of cassava plants');
	readln(setfile,plantdistr);{1=in rows, 2=scattered,3=clustered}
	scattered:=plantdistr=2;

	readaster;

	NowTime:=now;

{Boolean switches to turn on seasonal random variations of selected variables}
	readln(setfile,ch);varnplants:=(upcase(ch)='T');
	readln(setfile,ch);varnitro:=(upcase(ch)='T');
	readln(setfile,ch);varwater:=(upcase(ch)='T');
	readln(setfile,ch);varspacing:=(upcase(ch)='T');
	readln(setfile,ch);varcmbstart:=(upcase(ch)='T');
	readln(setfile,ch);varcmbnm1:=(upcase(ch)='T');
	readln(setfile,ch);varcmbprob:=(upcase(ch)='T');
	readln(setfile,ch);varcmbimm:=(upcase(ch)='T');
	readln(setfile,ch);varedstart:=(upcase(ch)='T');
	readln(setfile,ch);varedprob:=(upcase(ch)='T');
	readln(setfile,ch);varedimm:=(upcase(ch)='T');
	readln(setfile,ch);varelstart:=(upcase(ch)='T');
	readln(setfile,ch);varelprob:=(upcase(ch)='T');
	readln(setfile,ch);varelimm:=(upcase(ch)='T');
	readln(setfile,ch);vargmstart:=(upcase(ch)='T');
	readln(setfile,ch);vargmprob:=(upcase(ch)='T');
	readln(setfile,ch);varTaripoprob:=(upcase(ch)='T');
	readln(setfile,ch);varTmanihotiprob:=(upcase(ch)='T');
	readln(setfile,ch);varTaripoalpha:=(upcase(ch)='T');
	readln(setfile,ch);varTmanihotialpha:=(upcase(ch)='T');
{
 Boolean variable PresenceAbsence selects the presence/absence mode
 for insects.  This allows a switch to set each year to include or
 exclude an insect in the model.  The variablility of population sizes
 is the same as in mulcas2 when an insect is included.  CMB paras can
 be in only if CMB is in,  GM preds can be in only if GM is in. HJ can 
 be in only if cmb is in.
}
	readln(setfile,ch); PresenceAbsence:=(upcase(ch)='T');

	readaster;
	readln(setfile,datespread); {nr days over which to spread the plantings}

{scalars for adjusting wx  normally=1.0}
	for i:=1 to 5 do readln(setFile,wxcons[i]);
	readln(setfile,casiety);

	GISirngck(casiety,1,5, 'Cassava variety selector');
	readln(setfile,cbf);
	GISrngchk(cbf,1.0,2.0,'Number of initl sticks');
	readln(setfile,ranstick); {% variation in planting stick mass}
	ranstick:=ranstick/100.0;
	readln(setfile,plantspacingin);  {plant spacing within row (WM)}
	readln(setfile,rowspacingin);    {distance between rows (WM)}
	plantspacing:=plantspacingin;
	rowspacing:=rowspacingin;
	if varspacing then
	begin
		plantspacing:=fran(plantspacing,plseasonalvar);
		rowspacing:=fran(rowspacing,roseasonalvar);
	end;

	casdensity:=plantspacing*rowspacing;
	halfx:=plantspacing/2;
	halfy:=rowspacing/2;
	readln(setfile,pspacedist); {+-% plantspace variation}
	readln(setfile,rspacedist); {+-% rowspace variation}
	pspacedist:=pspacedist/100.0;
	rspacedist:=rspacedist/100.0;

(************soil water and nitrogen****************)
	readaster;
	readln(setfile,totpwp);
	readln(setfile,soilwin);
	readln(setfile,soilwmaxin);
	readln(setfile,orgin);
	readln(setfile,soilnin);
{ 
	To vary initial N levels at start of each season set soiln and
	org to random values between their nominal values +- 75%.
	soilnin and orgin save input original values cross seasons.
 }
	readln(setfile,phosphate);
	phosphatein:=phosphate;
	readln(setfile,nitdis);    {nitr. distribution: Uniform,Gradient,Random}
	nitdis:=upcase(nitdis);
	readln(setfile,nitdisvar); {variance of distr.}
	nitdisvarin:=nitdisvar;    {save initial value for later seasons}
	nitdisvar:=nitdisvar/100.0; {%}
	readln(setfile,nitgrad);   {direction of gradient}

	readln(setfile,watdis); {water distribution: Uniform,Gradient,Random}
	watdis:=upcase(watdis);
	readln(setfile,watdisvar); {variance of distr.}
	watdisvarin:=watdisvar; {save initial value for later seasons}
	watdisvar:=watdisvar/100.0; {%}
	readln(setfile,watgrad); {direction of gradient}

	readaster;

	readln(setfile,modout);
	readln(setfile,ch);daily:=upcase(ch)='T';
	//writeln('daily', daily:10); readln;
	if daily then
	begin
		assign(dailyfile,'CassavaDaily.txt');
		{$i-} rewrite(dailyfile); {$i+}
		i:=ioresult;
		ok:=(i = 0);
		if not ok then
		begin
			reporterror('Setup file not found ');
			Runok:=false;
			exit;
		end;
	
		writeln(dailyfile,'CasGis run on '+DateTimeToStr(NowTime));
		writeln(Dailyfile,'Number of plants=',tb,ncas:4);
	end;
	
	readln(setfile,ch);Summary:=upcase(ch)='T';

//Gis output Target: 1=ArcInfo(Casas), 2=Grass(Luigi)
	readln(setfile,GisOutputTarget);

	startday:=ModelStartDate;

{read cmb inits.}
{       CMB }
{these can vary each year: varcmbstart,varcmbnm1,varcmbprob,varcmbimm}
	readaster;
	readln(setfile,ch); CMBinfield:=(upcase(ch)='T');
	readln(setfile,ndlcmb);
	readln(setfile,cmbbeta);
	readln(setfile,cmbrem);

	readln(setfile,cmbDelay); //days after cas start for cmb start
	D1CMBin:=ModelStartDate+cmbDelay;

{ allow yearly cmb start to vary with d1cmbin +- 30 days.}
	d1cmb:=d1cmbin;

	{for cmbstartseasonalvar=30 then d1cmb=d1cmbin +- 30 days}
	if varcmbstart then d1cmb:=d1cmbin-cmbstartseasonalvar
							 + random(2*cmbstartseasonalvar);

	if d1cmb<startday then d1cmb:=startday;
	readln(setfile,mbimmigprobin); {prob. of immig. event/day/plant}
	mbimmigprob:=mbimmigprobin;
	if varcmbprob then mbimmigprob:=fran(mbimmigprob,cmbprobseasonalvar);
	readln(setfile,mbinsin,mbinspcnt); {nr in +-%}
	mbins:=mbinsin;
	if varcmbimm then mbins:=fran(mbins,cmbimmseasonalvar);
	if CMBinfield then
	begin
		GISirngck(NDLCMB,1,10, 'CM mort delay');
		GISrngchk(cmbbeta,0.0,10.,'CMB BETA');
		GISrngchk(CMBREM,0.0,30.,'CMB EMERGENCE RATE');
	end;

{ Parasitoid E. lopezi}
	readaster;
	readln(setfile,ch);elinfield:=(upcase(ch)='T');
	if(elinfield and(not cmbinfield))then elinfield:=false;

	readln(setfile,mbLevElStart); {level of mb[3] to attract start of el immig.}
	readln(setfile,elimmigprobin); {prob. of immigrants each day}
	elimmigprob:=elimmigprobin;
	if varelprob then elimmigprob:=fran(elimmigprob,elprobseasonalvar);

	readln(setfile,elinsin,elinspcnt); {nr in +-%}
	elins:=elinsin;
	if varelimm then elins:=fran(elins,elimmseasonalvar);

{ Parasitoid E.diversicornis}
	readaster;
	readln(setfile,ch);edinfield:=(upcase(ch)='T');

	readln(setfile,mbLevEdStart); {level of mb[3] to attract start of ed immig.}
		
	readln(setfile,edimmigprobin); {prob. of immigrants each day}
	edimmigprob:=edimmigprobin;
	if varedprob then edimmigprob:=fran(edimmigprob,edprobseasonalvar);

	readln(setfile,edinsin,edinspcnt); {nr in +-%}
	edins:=edinsin;
	if varedimm then edins:=fran(edins,edimmseasonalvar);

{ green mite}
	readaster;
	readln(setfile,ch);gminfield:=(upcase(ch)='T');
	readln(setfile,i,j,jyr); {start date}
	j1:=julian(i,j,jyr);
	if(j1 = 0)then
	begin
		reporterror('Error in green mite start date');
		Runok:=false;
		exit;
	end;
{allow yearly gm start to vary with gmstartdayin +- 30 days.}
	gmstartdayin:=rdate(jyr,j1);
	gmstartday:=gmstartdayin;
	if vargmstart then gmstartday:=gmstartday-gmstartseasonalvar
					 + random(2*gmstartseasonalvar);

	if gmstartday<startday then gmstartday:=startday;
	if(gmin and(gmstartday < pdate))then gmstartday:=pdate;

	readln(setfile,gmimmigprobin); {prob each plant gets 1 adult each day}
	gmimmigprob:=gmimmigprobin;
	if vargmprob then gmimmigprob:=fran(gmimmigprob,gmprobseasonalvar);
	readln(setfile,gminsin,gminspcnt);
	gmins:=gminsin;
{ green mite pred1}
	readaster;
	readln(setfile,ch);Taripoinfield:=(upcase(ch)='T');
	readln(setfile,gmWgtTaripoStart); {gm wgt to start Taripo immig}
	if (Taripoinfield and(not gminfield))then Taripoinfield:=false;

	readln(setfile,Taripoimmigprobin);
	Taripoimmigprob:=Taripoimmigprobin;
{ green mite pred2}
	readln(setfile,ch);Tmanihotiinfield:=(upcase(ch)='T');
	readln(setfile,gmWgtTmanihotiStart); {gm wgt to start Tmanihoti immig}
	if (Tmanihotiinfield and(not gminfield))then Tmanihotiinfield:=false;

	readln(setfile,Tmanihotiimmigprobin);
	Tmanihotiimmigprob:=Tmanihotiimmigprobin;


	if varTaripoprob then Taripoimmigprob:=fran(Taripoimmigprobin,Taripoprobseasonalvar);
	with Tariporec do
	begin
		predalpha:=predalphain; {initial nominal value}
		if varTaripoalpha then predalpha:=fran(predalpha,Taripoalphavar);
	end;
	if varTmanihotiprob then Tmanihotiimmigprob:=fran(Tmanihotiimmigprobin,Tmanihotiprobseasonalvar);
	with Tmanihotirec do
	begin
		predalpha:=predalphain; {initial nominal value}
		if varTmanihotialpha then predalpha:=fran(predalpha,Tmanihotialphavar);
	end;

{ HYPERASPIS JUCUNDA }
	readaster;
	readln(setfile,ch);
	hjinfield:=(upcase(ch)='T');
	if ((hjinfield)and(not CMBinfield))then hjinfield:=false;

	readln(setfile,ndelayhj);

	readln(setfile,HJMBLEV);

	readln(setfile,HJimmigprob);
	readln(setfile,hjinsin,hjinspcnt); {nr in +-%}
	hjins:=hjinsin;

	IF(hjinfield) then GISirngck(ndelayhj,0,10, 'HJ stress delay');
	readaster;
{fungus mort}
	readln(setfile,ch);fminfield:=(upcase(ch)='T');

	readln(setfile,immigmethod); {1:source=unknown, 2:source=pool}
	immigmethodsave:=immigmethod;
{Read Randseed - system variable for the randomize function.  if > 0 then use same random sequence each time.}
	readln(setfile,randseed);
	if randseed=0 then randomize;

	maxwidth:=2.0; {for scattered, unlimitted growth.}
	GisFileIndex:=0; {Used for sequential naming of gis output files}

{$IFDEF DUMPINPUTS}
	DumpParsedInputs;
{$ENDIF}
end; {procedure ReadInputs}


procedure findnbrs;
{compute the indeces of 4 neighbors, jl,jr,ja,jb.}
var
	i,j,nmax:integer;
begin
	if scattered then nmax:=100 else nmax:=ncas;
	for i:=1 to ncas do
	begin
		j:=deck[i];
		with casPtrs[j]^ do
		begin
			{
			When plants are not scattered the index i is the same as the
			cell number in the 10x10 array of plants.  When they are
			scattered  the index is mapped randomly to cell numbers via
			array deck.
			}
			{
			If current plant is on an edge the neighbor which would be
			outside the array is represented by the plant 'reflected'
			from the opposite edge.  The distance between plants in this
			case is the normal planting distance.  If there is only 1 plant,
			it can use itself as it's reflected neighbor.
			If there is a single row then the neighbors above and below
			can be the same row reflected.
			}
			{right}
			{if j is on right edge then use plant on left edge reflected.}
			jr:=j+1;
			if (j mod plantsperrow)=0 then jr:=j-plantsperrow+1;
			if jr>nmax then repeat dec(jr) until (jr mod plantsperrow)=1;
			{left}
			{if j is on left edge then use plant on right edge.}
			jl:=j-1;
			if (j mod plantsperrow)=1 then jl:=j+plantsperrow-1;
			if jl>nmax then jl:=nmax;

			{above}
			ja:=j-plantsperrow;
			if ja<1 then {j in top row: use reflection from bottom row.}
			begin
				repeat ja:=ja+plantsperrow; until ja>nmax;
				ja:=ja-plantsperrow;
			end;

			{below}
			jb:=j+plantsperrow;
			if jb>nmax then {j in bottom row: use reflection from top row.}
			begin
				repeat jb:=jb-plantsperrow; until jb<1;
				jb:=jb+plantsperrow;
			end;
		end;

	end;
end;


procedure initnit;
{fill array of nitrogen distribution.}
{The number in each cell represents g/m**3 but our arithmetic 
 ignores depth so in effect we consider it g/m**2.}
var
	nmin,omin,omax,val,oval:single;
	i,j,ix,iy,ndim:integer;
begin
	org:=orgin;
	soiln:=soilnin;
	if varnitro then
	begin
		soiln:=fran(soiln,nseasonalvar);  {soiln+-nseasonalvar%}
		org:=fran(org,oseasonalvar);
	end;
	phosphate:=phosphatein;

	insoiln:=soiln/4.0;
	inorg:=org/4.0;
	ndim:=22;
	case nitdis of
	'U' : {Uniform}
		begin
			for ix:=1 to ndim do for iy:=1 to ndim do 
			begin
				narray[ix,iy]:=insoiln;
				oarray[ix,iy]:=inorg;
			end;
			nmax:=15.0/4.0;
   		 end;

	'G' : {gradient}
		begin
			nmin:=insoiln*(1.0-nitdisvar);
			omin:=inorg  *(1.0-nitdisvar);
			nmax:=insoiln*(1.0+nitdisvar);
			if nmax>15/4.0 then nmax:=15.0/4.0;
			omax:=min(inorg  *(1.0+nitdisvar),120000.0/4.0);
			if nitgrad=1 then {gradient left to right}
			begin
				for ix:=1 to ndim do
				begin
					val:=nmin+(ix-1)*(nmax-nmin)/(ndim-1);
					oval:=omin+(ix-1)*(omax-omin)/(ndim-1);
					for iy:=1 to ndim do
					begin
						narray[ix,iy]:=val;
						oarray[ix,iy]:=oval;
					end;
				end;
			end;

			if nitgrad=2 then {gradient top to bottom}
			begin
				for iy:=1 to ndim do
				begin
					val:=nmin+(iy-1)*(nmax-nmin)/(ndim-1);
					oval:=omin+(iy-1)*(omax-omin)/(ndim-1);
					for ix:=1 to ndim do
					begin
						narray[ix,iy]:=val;
						oarray[ix,iy]:=oval;
					end;
				end;
			end;

			if nitgrad=3 then {gradient right to left}
			begin
				for ix:=1 to ndim do
				begin
					val:=nmax-(ix-1)*(nmax-nmin)/(ndim-1);
					oval:=omax-(ix-1)*(omax-omin)/(ndim-1);
					for iy:=1 to ndim do
					begin
						narray[ix,iy]:=val;
						oarray[ix,iy]:=oval;
					end;
				end;
			end;

			if nitgrad=4 then {gradient bottom to top}
			begin
				for iy:=1 to ndim do
				begin
					val:=nmax-(iy-1)*(nmax-nmin)/(ndim-1);
					oval:=omax-(iy-1)*(omax-omin)/(ndim-1);
					for ix:=1 to ndim do
					begin
						narray[ix,iy]:=val;
						oarray[ix,iy]:=oval;
					end;
				end;
			end;
		end; {'G'}

		'R' : {random  initial mean +- nitdisvar}
			begin
				nmin:=insoiln*(1.0-nitdisvar);
				omin:=inorg  *(1.0-nitdisvar);
				nmax:=insoiln*(1.0+nitdisvar);
				if nmax>15/4.0 then nmax:=15.0/4.0;
				omax:=min(inorg  *(1.0+nitdisvar),120000.0/4.0);
				for i:=1 to ndim do for j:=1 to ndim do
				begin	
					narray[i,j]:=nmin+random*(nmax-nmin);
					oarray[i,j]:=omin+random*(omax-omin);
				end;
			end;
	end; {case}
	tdelorg:=0.0;
end;


Procedure initsides;
{
 Set initial sides of the area around each plant, sidel,sidea,sider,sideb,
 in meters from leftedge and topedge.
 Set sides of plant area rectangle in screen space: lines from top,
 dots from left  - xl,xr,ya,yb.
}
var
	i:integer;
begin
	for i:=1 to ncas do
	with casPtrs[deck[i]]^ do
	begin
		{meters from leftedge and topedge of field.}
		sider:=x+0.01;
		sidel:=x-0.01;
		sidea:=y-0.01;
		sideb:=y+0.01;

		{dots from left and lines from top of screen}
		xl:=left+round(sidel*xdotspermeter);
		xr:=left+round(sider*xdotspermeter);
		ya:=top+round(sidea*ylinespermeter);
		yb:=top+round(sideb*ylinespermeter);
	end;
end; {initsides}


procedure wxmissing;
//procedure wxmissing(fahr,watts,inches,kilom:boolean);
(*
	Check for missing data markers in wx file and fill in with
	default values.
*)
var
	tmiss,smiss,pmiss,rmiss,wmiss:boolean;
	i:integer;
	rhdef,wdef : single;

begin
	tmiss:=false;
	smiss:=false;
	pmiss:=false;
	rmiss:=false;
	wmiss:=false;

	for i:=1 to ndays do
	begin
		if((temps[i,1]=-100.0)or(temps[i,2]=-100.0))then tmiss:=true;
		if(solar[i]=-1.0) then smiss:=true;
		if(rain[i]=-1.0)  then pmiss:=true;
		if(relhum[i]=-1.0)then rmiss:=true;
		if(winds[i]=-1.0) then wmiss:=true;

	end;            

	if tmiss then
	begin
(*
		writeln('Some temperature data is missing.');
		if fahr then writeln('Units are Fahrenheit.')
				else writeln('Units are Celsius.');
		write('Please enter default tmax value: ');
		readln(tmaxd);
		write('Please enter default tmin value: ');
		readln(tmind);
		for i:=1 to ndays do
		begin
			if (temps[i,1]=-100.0) then temps[i,1]:=tmaxd;
			if (temps[i,2]=-100.0) then temps[i,1]:=tmind;
		end;
*)
	end;

	if smiss then
	begin
(*
		writeln('Some solar radiation data is missing.');
		if watts then writeln('Units are watts.')
					else writeln('Units are Langleys.');
		write('Please enter default solrad value: ');
		readln(soldef);

		for i:=1 to ndays do
		begin
			if (solar[i]=-1.0) then solar[i]:=soldef;
		end;
*)
	end;

	if pmiss then
	begin
(*
		writeln('Some rain data is missing.');
		if inches then writeln('Units are inches.')
				 else writeln('Units are mm.');
		write('Please enter default precip value: ');
		readln(precdef);

		for i:=1 to ndays do
		begin
			if (rain[i]=-1.0) then rain[i]:=precdef;
		end;
*)
	end;

	if rmiss then
	begin
(*
		writeln('Some relative humidity data is missing.');
		write('Please enter default relhum value: ');
		readln(rhdef);
		writeln('Replacing missing relative humidity data with value of 55%.');
*)
		rhdef:=55.0;
		for i:=1 to ndays do
		begin
			if (relhum[i]=-1.0) then relhum[i]:=rhdef;
		end;
	end;

	if wmiss then
	begin
(*
		writeln('Some wind data is missing.');

		if kilom then writeln('Units are avg kilometers/h.')
				 else writeln('Units are avg miles/h.');
		write('Please enter default wind value: ');
		readln(wdef);

		writeln('Replacing missing wind data with value of 1 mph.');
*)
		wdef:=1.0;
		for i:=1 to ndays do
		begin
			if (winds[i]=-1.0) then winds[i]:=wdef;
		end;
	end;

end;


procedure DoScaleWx(i:integer);
{ Multiply wx data by adjustment scalars in array wxcons (if they are<>1.0).}
begin
	if(wxcons[1]<>1.0)then
		begin
			temps[i,1]:=temps[i,1] * wxcons[1];
			temps[i,2]:=temps[i,2] * wxcons[1];
		end;

	if(wxcons[2]<>1.0)then solar[i]:=solar[i]*wxcons[2];
	if(wxcons[3]<>1.0)then rain[i]:= rain[i]*wxcons[3];
	if(wxcons[4]<>1.0)then relhum[i]:=relhum[i]*wxcons[4];
	if(wxcons[5]<>1.0)then winds[i]:=winds[i]*wxcons[5];
end;



procedure readwx(var wxfile:text;Firstdate,Lastdate:single;
					  var ndays:word);
(*
	read weather data from text file wxfile which has been linked
	(assigned) to a disk file.
*)
var
	 wxday : single;
	month,day,year:integer;
	jday:integer;
	i:integer;
begin

	readln(wxfile);  {read line of column headers in data file}
	{read first line of data}
	readln(wxfile,month,day,year,temps[1,1],temps[1,2],solar[1],rain[1],
			 relhum[1],winds[1]);
	jday:=julian(month,day,year);
	wxday:=rdate(year,jday);

	if (Firstdate < wxday) then
	begin
		ok:=false;
		ReportError('Model start date precedes weather data.');
		runok:=false;
		exit;
	end;

	{read from wx file until date = FirstDate  or eof}
	while (ok and (Firstdate > wxday) and not eof(wxfile)) do
	begin

		 readln(wxfile,month,day,year,temps[1,1],temps[1,2],solar[1],
				  rain[1],relhum[1],winds[1]);
		 wxday:=rdate(year,julian(month,day,year));
	end;

	if(Firstdate > wxday)then
	begin
		ok:=false;
		reporterror('Weather data ends before model start date.');
		runok:=false;
		exit;
	end;

	if ok then
	begin
		i:=2;
		while ((not eof(wxfile)) and (wxday < Lastdate)and (month>0)) do
		begin
			readln(wxfile,month,day,year,temps[i,1],temps[i,2],solar[i],
				rain[i],relhum[i],winds[i]);

			if month>0 then	wxday:=rdate(year,julian(month,day,year));
			inc(i);
		end;

		{here if wxday<Lastdate there is not enough data in the wx file }
		if (wxday<Lastdate) then
		begin
			reporterror('Model end date adjusted to end of weather data.');
			ndays:=trunc(wxday-FirstDate);
		 end;
	end;
	ndays:=trunc(wxday-FirstDate);

	if ok then wxmissing;

end; {procedure readwx}



procedure casvariety;         
{
casiety   
	  1:= TMS30572 Cultivar (Red)
	  2:= TMS4(2)1425
	  3:= Isunikankiyan
	  4:= TMS91934 
	  5:= ODONDBO 
	dmgmle  square decimeters per gram of leaf
	grl1,grl2,drmul,dsmul1,dsmul2,dmresmul,dmtb1,dmtb2
	critera,dmgmle
} 
var
	sinit:single;
	i,j:word;
begin

  with casvar do
  for i:=1 to ncas do
  with casPtrs[deck[i]]^ do
  begin
	case iety of
	1 : begin               {TMS30572}
		dmgmle  := 1.80;    {square decimeters per gram of leaf }
		base    := 13.0;
		delfol  := 668.0;
		grlfmul := -2.9957;
		grl1    := 0.000165;
		grl2    := 0.024;
		drmul   := 0.0095;
		dsmul1  := 0.1; {set to 0.0 = no effect?}
		dsmul2  := 1.2; {1.35;}{light search}

		dms2time:= 900.0;
		dmresmul:= 0.25;
		dmtb1   := 0.01;
		dmtb2   := 1.8; {2.0}{light search}
		ndlmul  := 0.05;
		dmt2time:= 900.0;
		critera := 600.0; {max time to first branching}
	    end;
	2 : begin               {TMS4(2)1425}
		dmgmle  := 1.80;        { square decimeters per gram of leaf }
		base    := 13.0;
		delfol  := 668.5;
		grlfmul := -2.9957;
		grl1    := 0.000165;
		grl2    := 0.024;
		drmul   := 0.0095;
		dsmul1  := 0.35;
		dsmul2  := 1.275;
		dms2time:= 850.0;
		dmresmul:= 0.25;
		dmtb1   := 0.25;
		dmtb2   := 1.7;
		ndlmul  := 0.05;
		dmt2time:= 850.0;
		critera := 650.0; {max time to first branching}
	    end;
	3 : begin             {ISUNIKANKYIAN}
		dmgmle  := 1.35;        { square decimeters per gram of leaf }
		base    := 13.0;
		delfol  := 700.0;
		grlfmul := -2.9957;
		grl1    := 0.00009;
		grl2    := 0.0225;
		drmul   := 0.0095;
		dsmul1  := 0.25;
		dsmul2  := 1.25;
		dms2time:= 1200.0;
		dmresmul:= 0.2;
		dmtb1   := 0.25;
		dmtb2   := 2.0;
		ndlmul  := 0.05;
		dmt2time:= 2250.0;
		critera := 1200.0; {max time to first branching}
	    end;
	4 : begin               {var TMS91934} 
		dmgmle  := 1.35;        { square decimeters per gram of leaf }
		base    := 13.0;
		delfol  := 650.0;
		grlfmul := -2.9957;
		grl1    := 0.00009;
		grl2    := 0.025;
		drmul   := 0.0095;
		dsmul1  := 0.35;
		dsmul2  := 0.85;
		dms2time:= 1100.0;
		dmresmul:= 0.2;
		dmtb1   := 0.25;
		dmtb2   := 2.10;
		ndlmul  := 0.055;
		dmt2time:= 1200.0;
		critera := 650.0; {max time to first branching}
	    end;

	5 : begin               {odondbo}
		dmgmle  := 2.2; { square decimeters per gram of leaf }
		base    := 13.0;
		delfol  := 750.0;
		grlfmul := -2.9957;
		grl1    := 0.00009;
		grl2    := 0.022;
		drmul   := 0.0095;
		dsmul1  := 0.35;
		dsmul2  := 2.8;
		dms2time:= 900.0;
		dmresmul:= 0.2;
		dmtb1   := 0.0;
		dmtb2   := 3.1;
		ndlmul  := 0.058;
		dmt2time:=1100.0;
		critera := 1080.0; {max time to first branching}
	    end;
	end; {case}

	delstem:=6000.0;
	delroot:=6000.0;
	delkfol:=delfol/kfol;
	delkstem:=delstem/kstem;
	delkroot:=delroot/kroot;
	sinit:= 3.25/6.0 * stickin /delstem;
	for j:=1 to kstem do stemwgt[j]:=sinit;
	totals:=sum(stemwgt,1,kstem)*delkstem;
	maxdepth:=2.5;
	rootdepth:=0.0;
 end;{casPtrs[i]}
end; {procedure variety}


Procedure ReclaimStack;
var
	i,j:integer;
begin
{Reclaim stack space taken by previous New() calls.}

	for i:=1 to ncas do
	begin
		j:=deck[i];
		casloc[j].aplant:=false;
		with casPtrs[j]^ do
			if cmbthisplant then 
			begin
				dispose(mbPtrs[j]);
			end;
		if elinfield then dispose(elptrs[j]);
		if edinfield then dispose(edptrs[j]);
	end;

	for i:=1 to ncas do
	begin
		j:=deck[i];
			if (gminfield)then
			begin
				if Taripoinfield then dispose(Taripoptrs[j]);
				if Tmanihotiinfield then dispose(Tmanihotiptrs[j]);
				dispose(gmptrs[j]);
			end;
			if hjinfield then dispose(hjptrs[j]);
			dispose(casPtrs[j]);
	end;
end;


Procedure InitYear;
{Initializations at start of each of multi seasons.}
var
	i,j:integer;
	dek:i100;{array[1..100]of integer;}
begin

	{Get number of plants for new season.}
	ncas:=ncasin;
	if varnplants then
	begin
		ncas:=1+random(2*ncasin);
		if ncas>(2*ncasin) then ncas:=2*ncasin;
		if ncas>100 then ncas:=100;
	end;

	{initial values for each cas plant}
	setupcasxy; {set x,y planting locations for 100 plants in array casloc.}
	for i:=1 to 100 do casloc[i].aplant:=false; {initially no plants anywhere.}

	if scattered then
	begin
		{assign xy locations for ncas plants randomly.}
		i:=100;
		shufl(dek,i); //? mystery can't call shufl(deck,i) from here. 01/25/05
		for i:=1 to 100 do deck[i]:=dek[i];
	end
	 { integers 1 to 100}
	else for i:=1 to 100 do deck[i]:=i;

	for i:=1 to ncas do
	begin
		j:=deck[i];
		casloc[j].aplant:=true;
		new(casPtrs[j]);
		casPtrs[j]^.x:=casloc[j].x;
		casPtrs[j]^.y:=casloc[j].y;
	end;

	{allow 1 plant in center of field}
	if ncas=1 then  with casPtrs[deck[1]]^ do
	begin
		x:=5.0;
		y:=5.0;
	end;


	findnbrs; {find indeces of 4 neighbors for each plant.}

	for i:=1 to ncas do with casPtrs[deck[i]]^ do
	begin
		{set plant dates randomly near plantdate.}
		plantdate := pdate+ random(datespread);
		harvestdate:= hdate;
		emerging:=true;
		iety:=casiety; {}
		cbfact:=cbf;
		totall:=0.0;
		sqdmpl:=0.001;
		colr:=0;
		mbdays:=0.0;
		gmdays:=0.0;
		eddays:=0.0;
		eldays:=0.0;
		Taripodays:=0.0;
		Tmanihotidays:=0.0;
		biomasscolr:=0;
		
			for j:=1 to 6 do LeafMass12[j]:=0.0;
		ShowingValues:=false; 
	end;
	{record number 101 will be used for sampled means.}
	if firstyear then new(casPtrs[101]);
	with casPtrs[101]^ do
	begin
		plantdate := pdate;
		harvestdate:= hdate;
		emerging:=true;
		iety:=casiety;
		cbfact:=cbf;
		totall:=0.0;totals:=0.0;totalr:=0.0;tuber:=0.0;
		sqdmpl:=0.001;
		colr:=0;
		mbdays:=0.0;
	    	for j:=1 to 12 do LeafMass12[j]:=0.0;
	end;

	plantspacing:=plantspacingin;
	rowspacing:=rowspacingin;
	if varspacing then
	begin
		plantspacing:=fran(plantspacing,plseasonalvar);
		rowspacing:=fran(rowspacing,roseasonalvar);
	end;
	casdensity:=plantspacing*rowspacing;
	halfx:=plantspacing/2;
	halfy:=rowspacing/2;

	jday:=julian(month1,day1,year1);

	for i:=1 to ncas do with casPtrs[deck[i]]^ do
	begin
		{set plant dates randomly near plantdate.}
		plantdate := pdate+ random(datespread);
		harvestdate:= hdate;
		emerging:=true;
		iety:=casiety;
		cbfact:=cbf;
		totall:=0.0;
		sqdmpl:=0.001;
		colr:=0;
		mbdays:=0.0;
		gmdays:=0.0;
		eddays:=0.0;
		eldays:=0.0;
		Taripodays:=0.0;
		Tmanihotidays:=0.0;
		biomasscolr:=0;
	end;

{*************soil water and nitrogen****************}
	nitdisvar:=nitdisvarin; {variance of distr.}
	nitdisvar:=nitdisvar/100.0; {%}
	watdisvar:=watdisvarin; {variance of distr.}
	watdisvar:=watdisvar/100.0; {%}

	cmbrem:=2.37;
{ allow yearly cmb start to vary .}
	d1cmb:=d1cmbin;
	if varcmbstart then d1cmb:=d1cmbin-cmbstartseasonalvar
							 + random(2*cmbstartseasonalvar);
	if d1cmb<startday then d1cmb:=startday;
	mbimmigprob:=mbimmigprobin;
	if varcmbprob then mbimmigprob:=fran(mbimmigprob,cmbprobseasonalvar);
	mbins:=mbinsin;
	if varcmbimm then mbins:=fran(mbins,CMBimmseasonalvar);

 	elimmigprob:=elimmigprobin;
	if varelprob then elimmigprob:=fran(elimmigprob,ElProbSeasonalVar);
	elins:=elinsin;
	if varelimm then elins:=fran(elins,ElimmSeasonalVar);


{ Parasitoid E.diversicornis}
	eddelay:=eddelayin;
	edimmigprob:=edimmigprobin;
	if varedprob then edimmigprob:=fran(edimmigprob,EDprobseasonalvar);
	edins:=edinsin;
	if varedimm then edins:=fran(edins,EDimmseasonalvar);


{ green mite}
{allow yearly gm start to vary with gmstartdayin +- 30 days.}

	gmstartday:=gmstartdayin;
	if vargmstart then gmstartday:=gmstartday-gmstartseasonalvar
					 + random(2*gmstartseasonalvar);
	if gmstartday<startday then gmstartday:=startday;
	gmimmigprob:=gmimmigprobin;

	if vargmprob then gmimmigprob:=fran(gmimmigprob,GMprobseasonalvar);

//	if (Taripoinfield or Tmanihotiinfield)then predsetup;

	if varTaripoprob then Taripoimmigprob:=fran(Taripoimmigprob,Taripoprobseasonalvar);
	with Tariporec do
	begin
		predalpha:=predalphain; {initial nominal value}
		if varTaripoalpha then predalpha:=fran(predalpha,Taripoalphavar);
	end;

	if varTmanihotiprob then Tmanihotiimmigprob:=fran(Tmanihotiimmigprob,Tmanihotiprobseasonalvar);
	with Tmanihotirec do
	begin
		predalpha:=predalphain; {initial nominal value}
		if varTmanihotialpha then predalpha:=fran(predalpha,Tmanihotialphavar);
	end;


	maxwidth:=2.0; {for scattered, unlimitted growth.}
	casvariety;
	immigcounter:=0;
	tddField:=0.0;
//writeln('inityr');
end; {procedure InitYear}


Procedure InitMisc;     
{
Called From Mulcas to initialize misc stuff each season.
}
var

	i,j,k:integer;
Begin

	tddfield:=0.0;
	nds:=0.0;
	ndr:=0.0;
	fieldevapsoil:=0.0;
	firstcols:=true;

	if cmbinfield then cmbsetup(ncas);
	if (edinfield or elinfield)then parasetup;
	if gminfield then gmsetup(ncas); {set species parameters.}

	if (Taripoinfield or Tmanihotiinfield)then predsetup;

	if hjinfield then hjsetup(ncas);


//cumulative sums since previous output of insect values for Gis and Summaries outputs.	
	gmsum    :=0;
	TariSum  :=0;
	TmaniSum :=0;
	for i:= 1 to 6 do mbnSum[i]:=0;
	for i:=1 to 3 do
	begin
		ednumSum[i]:=0;
		elnumSum[i]:=0;
	end;
	HjEggSum := 0;
	HjLarSum := 0;
	HjAdlSum := 0;


	nel:=0; {number of el populations}
	ned:=0; {number of ed populations}
	with casvar do
	for k:=1 to ncas do
	begin
		i:=deck[k];
		with casPtrs[i]^ do with casvar do
		begin
			id := 'cas';
			done:=false;
			totph:=0.0;
			sdlsr:=1.0;
			tdda:=0.0;
			BRANCH:=trunc(cbfact);
			sumflin:=0.0;
			branchtime :=0.0;
			{ Plant starts with 11.0 gms cutting (6?) }
			tuber:=0.0;
			STICKIN:=6.0;
			{stickin:=6.0*((random-0.5)*2*ranstick +1.0);}
			reserves:=2.75/6.0 * STICKIN;
			glf:=0.0;
			gs:=0.0;
			gr:=0.0;
			gres:=0.0;
			gtuber:=0.0;
			tfolnum:=0.0;
			totall:=0.0;
			totalr:=0.0;
			totalf:=0.0;
			prevanit:=0.0;
			ndtot:=0.0;
			dmlsr:=0.0;
			f1:=0.0;
			f2:=0.0;
			f3:=0.0;
			pcost:=0.0;
			fill(rootwgt,kroot,0.0);
			fill(stemwgt,kstem,0.0);
			for j:=1 to kfol do
			begin
				folnum[j]:=0.0;
				folwgt[j]:=0.0;
				folnit[j]:=0.0;
			end;
			totnuptk:=0.0;
			for j:=1 to kstem do stnit[j]:=0.0;
			for j:=1 to kroot do rtnit[j]:=0.0;
			laimax:=4.5;
			rootmax:=08.00;
			{ Water model }
			ES1:=0.0;
			es2:=0.0;
			watfirst:=true;
			watertime:=0.0;
			lai:=0.0;
			maxlai:=0.0;
			rootdepth:=0.0;
			iwsd:=0;
			for j:=1 to 7 do wsdarray[j]:=1.0;
			wsd:=1.0;
			prevawat:=0.0;
			wdemand:=0.01;
			transpire:=0.0;

			nsdlsr:=1.0;
			NRES:=0.0836;
			NVEG := 0.0;
			ntuber:=0.0;
			ntsout:=0.0;
			ntrout:=0.0;
			ntlout:=0.0;
			cmbthisplant:=false;
			mbdays:=0.0;
			gmthisplant:=false;
			gmonscreen:=false;
			{gmpred1:=false;gmpred2:=false;} {predators present?}
			gmpred1onscreen:=false;
			gmpred2onscreen:=false;
			for j:=1 to kfol do gmfood[j]:=0.0; 
			hjthisplant:=false;
			hjonscreen:=false;

		end; {with casPtrs[i]}
	end;{k=1,ncas}
	cassemerging:=true;

	initsides;

	initnit;

	{water layer dimensions}
	{assume standard volume of 1m-sq x 2.5 m deep}
			layer[1].top:=0.0;
			layer[1].bottom:=0.75;
			layer[2].top:=0.75;
			layer[2].bottom:=1.5;
			layer[3].top:=1.5;
			layer[3].bottom:=2.5;

	initwat(layer[1]);
	casvariety;

end; {procedure InitMisc}

end.
