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

unit globals;
interface
const
 kfol=50; {this is the max size for the r and v arrays.  See how Type 'Single100' is defined in line 13.}
 kstem=50;
 kroot=50;
 kpred=50;
 kgm=50;
 kova=50;
 khj=50;
 kcmb=50;
 kem=50;
 kel=50;
 ked=50;		

type
	i100      = array[1..100] of integer;
	Single100  = array[1..kfol] of single;
	single10  = array[1..10] of single;
	single6   = array[1..6] of single;
	a2darray   = array[1..22,1..22] of single;
	weather   = array [1..73050] of single;	//73050=365.25*200  allows 200 years
	weathers  = array [1..73050, 1..2] of single;
	string4 = string[4];

Varietyrec = record    
{varietal variables }
	dda,base                          : single;
	age1,age2,agegrow,agefat          : single;
	shdmnb,shdmxb,shdmnf,winmax       : single;
	dmgmle                            : single;
	tffb,ratefp                       : single;
	delfol,delroot,delstem     : single;
	delkfol,delkroot,delkstem : single;
	db,df                             : single;
	dlp,dsp,drp,dlmax,dsmax           : single;
	dlfmass                           : single;
	grlfmul,drmul,dsmul,ndlmul        : single; {corn}
	grl1,grl2,dmresmul                : single; {cas}
	dsmul1,dsmul2,dms2time            : single; {cas}
	dmtb1,dmtb2,dmt2time              : single; {cas}
	critera                           : single;{cas}
	costph                            : single;
	ndelay                            : integer;
	laimax                            : single;
	rootmax,maxdepth				  : single;
end; {varietyrec}

predvarietyrec = record    
{Species variables for gmite predators.}
	predbase :single; {physiological time threshold}
	tpeak:single;
	predage: array[1..7]of single;
	preddem: array[1..7]of single; { prey(eggs+larvae)/dd}
	predfec:single; {eggs oviposited/dd for ovip stage}
	predsexr1:single; {fraction of fem.}
	delpred,delkpred:single;
	predalphain,predalpha:single; {predalphain is initial, predalpha can change}
	veggs,vlarva,vproto,vdeuto,vpreov,vovipad,vadult,vreport : Single100;
	rhlim:single; {lower rh limit for lx}
	sdmin:single; {lower sd limit to allow pollen effect}
end;

{Variables for each pred population}
predrec = record
	prednums : Single100;
	predov,predlarv,predproto,preddeuto,predpreovip,predovipad,predad,predbirth : single; {counts}
	predreport:single; {stages 2 thru 7}
	predn : array[1..7]of single; {numbers for 7 age categories}
	preddd,tpreddd : single;
	predsd,preddam,preddays,cumpreddam,bpred : single;
	predsfin   : boolean; {control stop of each pop.}
	predsexr	       : single;
	emigrants:single;
end;

plantrec = record
	done                            : boolean;
	folwgt,stemwgt,rootwgt          : Single100;
	folnum                          : Single100;
	gmfood				: Single100; {holds leaf damaged by green mite}
	folinmass                       : single;
	tdda                            : single;
	totph,reserves,resinc           : single;
	lai                             : single;
	maxlai	                    	: single;
	rootdepth		        : single;
	f1,f2,f3			: single;
	totalr,totall,leaftot,totals,totalf     : single;{current wgts}
	totalh                          : single; {corn}
	activ                           : single;
	dh,dl,ds,dr                     : single;
	sdlsr,sdtot                     : single;
	dmlsr,dmbud,dmres,dmtuber       : single;
	gf,gr,gs,gh,glf                 : single;
	tfolnum                         : single; {cas}  
	gtuber,gres                     : single; {cas}
	b,bgm,costmr,costlr,pcost  	: single;
	shdnr,shdmas                    : single; {cowp}
	stack                           : single10; {cowp}
	buds                            : single; {cowp}
 {vars for cycle version.}
 	mbdays,eddays,eldays,gmdays,Taripodays,Tmanihotidays : single;

{water}
	wsdarray			: single10;{wsd record}
	iwsd				: integer;{ptr to most recent ws in wsdarray}
	wsd				: single;
	wdemand    {was tritch}		: single; {plant demand for transpiration}
	transpire			: single; {water used by plant}
	prevawat			: single; 
	watfirst			: boolean;
	watertime,es1,es2		: single;
   {associated with a plant  or with a region of field?}
   {nitrogen}
	folnit,stnit,rtnit		: Single100;
	nsdlsr,nres,nveg,ndtot		: single;
	ndres,ndlsr,ndtube		: single;
	prevanit,totnuptk		: single;
	id : string4;
	tuber                          : single;{cas}
	branch                         : byte;{cas}
	branchtime                     : single;{cas}
	ntuber,ntsout,ntrout,ntlout    : single;{cas}
	sumflin 					   : single;{cas}
	x,y                            : single;{field location, meters from low left}
	xl,xr,ya,yb                    : integer;{sides of rect. on screen}
	jl,ja,jr,jb 				   : integer; {indeces of 4 neighbors}
	sidel,sidea,sider,sideb        : single;{sides of plant area in field}
	sqdmpl                         : single; {area for light interception (setsides)}
	plantdate,harvestdate           : single;
	emerging					   : boolean; 
	iety                            : integer;
	cbfact,stickin				   : single;{cas}
	colr                             : word; {color in plant graphic}
	biomasscolr						: word;{color in tuber graphic}
	cmbthisplant         : boolean; {is mb on this plant?}
	Hjthisplant          : boolean; {is HJ on this plant?}
	HJonScreen           : boolean; 
	gmthisplant          : boolean; {is green mite on this plant?}
	gmonscreen           : boolean; {was green mite on this plant?}
	gmpred1onscreen,gmpred2onscreen:boolean;
	LeafMass12 : array[1..12] of single; {lf mass in 6 age categories}
	ShowingValues:boolean;
end; {plantrec}


locrec=record
	aplant:boolean;
	x,y:single;
end;

soilrec = record
	top,bottom 						: single; {dx from soil surface}
	pwp,soilwmax			    	: single; 
	soilw							: single; {water in layer}
	avlw							: single;
{The soilw in a layer is distributed over the field in the 2d array:'}
	warray							: a2darray;
end;


{Variables for each cmb population}
mbrec = record
	cmbgo,cmbfin   : boolean; {control start and stop of each pop.}
	mbstart	       : single; {date when this pop. starts}
	cmbnum,cmbwgt,cresv  : Single100;
	embnum,embwgt        : Single100;
	mbn,mbsize : single6; {numbers,sizes for 6 age categories}
	adults : single;
	numberscolr						: word;{color in cmb graphic}
	stack                : array[1..10] of single;
	next:integer;
	elthisplant,edthisplant : boolean; {para el or ed included for this mb population}
	goel,goed,gohj : boolean; {they have started yes or no}
	sexratio:single;
	ShowingValues:boolean;
end;

{Variables for each e.lopezi population}
ElRec = record
	godelay:integer; {days this pop. delays after mb}
	elfrn,elmrn : Single100;
	elnum,elwgt : array[1..3] of single;
	elsd : array[1..7] of single;
	sexratio:single;
end;

{variables for each e.diversicornis population}
EdRec = record
	godelay:integer; {days this pop. delays after mb}
	edfrn,edmrn : Single100;
	ednum,edwgt : array[1..3] of single;
	edsd : array[1..7] of single;
	sexratio:single;
end;

{Variables for each green mite population}
gmrec = record
{green mite class variables unique for each pop}
	gmfin,gmgo : boolean;
	gmova,gmn : Single100;
	gmnums,gmwgt : array[1..4] of single;
	gmovnm,gmimnm,gmpreo,gmadnm,gmtot,gmtotwgt,gmsd:single;
	gmbeg : single;{gm start date f(gmstartday)}
	gmdam,cumgmdam : single;
	gdelt,tgdelt : single;
	cmbrmort,gmdays : single;
	npccon,eggr,deadleaf,leafmass : single;
	goTaripo,goTmanihoti,Taripothisplant,Tmanihotithisplant:boolean;
end;

{variables for each HJ population}
hjrec = record
	hjfin : boolean;
	hjnm,hjwt,hjembnum,hjembwgt : Single100;
	hjegnm,hjlarn,hjadnm,hjpupwt,hjpupnm,hjemnm,hjemwt : single;
	hjegwt,hjlarwt,hjadwt,hjtotn,hjtotwt,hjegest : single;
	bornhj : single;
	nexthj : integer;
	hjreserve,dmgro,gr : single;
	dmres,dmresphj,bhj,food : single;
	hjsexr : single;
	hjstack : array[1..10] of single;
	lxed1,lxel1,toplai : single;
	hjdelt,hjtdelt:single;
	sde,sdv:single;
end;

	plantptr = ^plantrec;
	mptr     = ^mbrec;
	elp      = ^elrec;
	edp      = ^edrec;
	gmptr    = ^gmrec;
	predptr  = ^predrec;
	hjptr    = ^hjrec;

	plantptrarray = array[1..101] of plantptr;
	mptrarray     = array[1..101] of mptr;
	elparray      = array[1..101] of elp;
	edparray      = array[1..101] of edp;
	gmptrarray    = array[1..101] of gmptr;
	predarray     = array[1..101] of predptr;
	hjarray       = array[1..101] of hjptr;

const
	tb = #9; {Tab character for delimitting output}

var
	RunOk:boolean; {Leads to exit if bad error occurs}
	EndFileWritten,DoEndFile : boolean;
	GisOutputTarget:byte; //1=ArcInfo(Casas), 2=Grass(Luigi)

	vs,location : string; {used in reporterror messages}
	PresenceAbsence:boolean;
	CMBPresent,ELPresent,EDPresent,GMPresent,TaripoPresent,TmanihotiPresent:boolean;
	HJPresent,FMPresent:boolean;
	CMBin,ELin,EDin,GMin,Taripoin,Tmanihotiin,HJin,FMin:boolean;
	tuberintervals,mbintervals,gmintervals,waterintervals,nitrointervals:single10;	
	Longitude,LatitudeDegrees,LatitudeRadians,daylng,dlprev			:single;
	pdate,pdate1,lastdate:single;
	totdays:single;
	jday1,jdayStart,jdayEnd,modelnday:integer;
	month,day:byte;

	avgwd,avgev,fielddem:single;
	maxwidth:single;
	casvar: varietyrec;
	tddfield:single;
	Tariporec,Tmanihotirec : predvarietyrec;

	gmWgtTaripoStart,gmWgtTmanihotiStart: single; {Tot wgt of gm to attract start of Taripo, Tmanihoti immig.}
	
	casloc:array[1..100]of locrec;
	deck:i100; {array[1..100]of integer;}

	sdavg:single;

	halfx,halfy:single; {half the mean dx between plants and rows}

	casPtrs : plantptrarray;

	np    : integer; {number of plants growing.}
	plantdistr : byte; {1=plant in rows, 2=scattered,3=cluster}
	scattered : boolean;

	layer : array[1..3] of soilrec;
	castrue : boolean;    
	casdaily,Summary : boolean;    
	cassemerging  : boolean;
	cmbrmort,hjlx : single;
	lxdmb,lxlmb : single6;
	kcrawl : integer; {index for cmb immigrants}
	base:single;
	ddb:single;
	nuptk,nuptkpot: single;

	DailyFileName,GisFileName,AllPlantsFilename,SetupFileName,SummaryFileName     : string;
	wxfilename,wxid    : string;

	dailyfile,SummaryFile,wxfile:text;
	GisFile,errorlogfile,GisFilesListfile : text;

	plantspacingin,rowspacingin : single;
	plantspacing,rowspacing : single;
	pspacedist,rspacedist : single; {%distrib of spacings}
	ranstick : single; {variation of initial stick mass}
	nrows : integer;
	xdotspermeter,plantsperrow : integer;
	ylinespermeter : integer;
	left,right,top,bottom:integer; {sides of display of 10x10m field}

	ned,nel : integer; {number of ed and el populations}

	daily,tab,iacre,ok,randm,firstcols,savemeans : boolean;

	fminfield                      : boolean; {fungus mort (rain)}

	solar,rain,relhum,winds                : weather;
	temps                                  : weathers;
	tmax,tmin,tmean,precip,wind,rhmean     : single;
	solrad                                 : single;
	wxcons:array[1..5]of single;
	startday                               : single;
	casdensity                             : single;

	jday                             : integer;
	ndays:word; {May be many years so could be larger than 16384}

	ncasin :integer; {Nominal number of plants}
	ncas        : integer;  {Actual number of plants}
	nsamp : integer; {nr plants to sample each day}
	month1,day1,year1:integer;
	month2,day2,year2:integer;
	ModelStartDate,ModelEndDate:single;

	nyears,iyr:integer;
	firstyear:boolean;
	ModelDate                     : single;
	modelday,modelyear                : integer;
	yearlength,modout,GisOutputInterval,AllPlantsOutputInterval          : integer;
	GisFileIndex:integer; {Used for sequential naming of gis output files}
	IHR,IMIN,ISEC,Ic1,IHR2,IMIN2,ISEC2,Ic2        : word; {For computing elapsed time}

	{field water variables}
	Soilwin,Soilwmaxin,totpwp    : single;
	totwatloss,sumtransp            : single;
	fieldlai:single;	
	fieldes1,fieldes2,fieldwatertime            : single;
	fieldwatfirst            : boolean;
	waterarray          : a2darray;
	fieldevapsoil,totevap {was ES}              : single; {may be F(all nearby plants)}
	h2odelay                       : single;
 	watdis : char;{ water distr. u=uniform,g=gradient,r=random}
	watdisvar : single; { % variation in water (in gradient or random)}
	watdisvarin : single; {initial value}
	watgrad : integer; {gradient direction. 1=left to right,2=tb,3=rl,4=bt}

{soilevap,transpiration,transsum,soilevapsum, totwatloss:real;}

{nitrogen}
	nds,ndr:single;
	org,soiln        : single;
	tdelorg:single;
	nmax : single; {max value in any narray cell.}
	narray,oarray : a2darray;
	ntsout,ntrout        : single; {N that has aged out}
	nitdis : char;{ nitrogen distr. u=uniform,g=gradient,r=random}
	nitdisvar : single; { % variation in nitrogen (in gradient or random)}
	nitdisvarin : single; {initial value}
	nitgrad : integer; {gradient direction. 1=left to right,2=tb,3=rl,4=bt}
	ndwt : single; {daily folnit change. (each plant)}
	nresut : single; {daily uptk to res (each plant)}
	phosphate        : single;
	orgin,soilnin,phosphatein:single; {initial values}

{CMB}
	{general cmb}
	{These apply to all mb populations.}

	mbimmigprobin,mbimmigprob : single;
	mbinsin,mbins : single;
	mbinspcnt : integer;
	cmbinfield  :  boolean; {include cmb in the field this run?}
	d1cmbin,d1cmb : single; {nominal start day. each pop. may vary.}
	cmbDelay:byte; //days after cas to start cmb
	cmbbase,cmbbeta,cmbrem,
	embshedmin,embshedmax : single;
	vova,vcrawl,vcrawly,vgrow,vattk,vpreov,vadlt2,vadlt : Single100;
	vlarv2,vlarv3,vemb : Single100;
	cmbage : array[1..5] of single;
	ndlcmb            : integer;
	delem,delkem,delkcmb : single;
	lxage,lxsize : boolean; {ed and el mort based on age or size}
	mbptrs : mptrarray; {array of ptrs to each mb population.}

	elPtrs : elparray; {array of ptrs to each el population.}
	edPtrs : edparray; {array of ptrs to each ed population.}

	hjptrs : hjarray; {array of ptrs to each hj pop.}

	rnsdlx : single; {set in paras}

	phi : single6; {ratios of mass to max mass}
	lx  : single6; {lx to 6 ages of mb from ed,el...}

{E lopezi, e diversicornis }
  {general variables set once for all}
	eddelt,eldelt,delked,delkel : single;
	edage,elage : array [1..4] of single;		
	oviped,ovipel : single;
	edinfield,elinfield:boolean;
	eddelayin,eldelayin,eddelay,eldelay:integer; {days after mb start to start}

	edimmigprobin,elimmigprobin:single;
	edimmigprob,elimmigprob:single;
	edinsin,elinsin:single;
	edins,elins,edfemad : single;
	edinspcnt,elinspcnt:integer;
	mbLevEdStart,mbLevElStart: single; {level of mb[3] to attract start of Ed, EL immig.}

{green mite class constants same for all pops}
	gmptrs : gmptrarray; {array of ptrs to each gm population.}
	Taripoptrs : predarray; {array of ptrs to each pred1 population.}
	Tmanihotiptrs : predarray; {array of ptrs to each pred2 population.}
	gminfield : boolean;
	gmstartdayin,gmstartday:single; {nominal start day.  each pop. may vary.}
	gmimmigprobin,gmimmigprob:single; {prob each plant gets immigrants each day}

	gminsin,gmins : single; {original and yearly default number to immigrate daily}
	gminspcnt : integer;  { % +- spread on immigrant number each day}

	delova,delimm,delpre,deladl : single;
	delgm,delkgm : single;
	LeafAgePref : array[1..12] of single;
	vgmova,vgmimm,vgmpre,vgmadlt : Single100;
	gmbase,sexr : single;
	Taripoinfield,Tmanihotiinfield:boolean;   {pred1,pred2 included?}
	Taripoimmigprob,Tmanihotiimmigprob:single; {prob plants to receive pred visitor daily}
	Taripoimmigprobin,Tmanihotiimmigprobin:single; {prob plants to receive pred visitor daily}
	gmTaripomort,gmTmanihotimort:Single100; {mortalities to gm due to pred1, pred2}


		immigmethod,immigmethodsave : integer; {1=source unknown, 2=daily migrant pool}
	immigcounter:integer;
	{
		pools of migrants.
	 
	 	*poola=yesterday's pool = source of today's immigrants
		*poolb=today's pool = target of today's emigrants
	}
	mbimmigpoola,mbimmigpoolb : single;
	elfimmigpoola,elmimmigpoola : single; {males and females}
	elfimmigpoolb,elmimmigpoolb : single; {males and females}
	edfimmigpoola,edmimmigpoola : single; {males and females}
	edfimmigpoolb,edmimmigpoolb : single; {males and females}
	gmimmigpoola,gmimmigpoolb : single;
	Taripoimmigpoola,Tmanihotiimmigpoola : single;
	Taripoimmigpoolb,Tmanihotiimmigpoolb : single;
	hjimmigpoola,hjimmigpoolb : single;

{Hyperaspis Jucunda}
{Variables for all instances}
{These are set at start and apply to all hj populations.}
	Hjinfield: boolean;  {HJ included this run?}
	ndelayhj : integer; {Delay for stress to take effect}
	hjage : array[1..5] of single;
	delemhj,delkemhj,hjdelk,hjbase,rateem,hjsexr : single;
	betahj : single;
	hjshedmin,hjshedmax : single;
	vhjeggs,vhjimm,vhjpupa,vhjadlt,vshedhjem : Single100;
	hj1:single; {Nr adults immig./day}
	hjmblev:single; {level of totcmb to allow immig}
	hjimmigprob:single; {prob. of hj immig each plant eachday.}
	hjins,hjinsin:single;
	hjinspcnt:integer;
	hjdmres:single;
	hjdelayin:integer;

//cumulative sums since previous output of insect values for Gis and Summaries outputs.	
	gmsum    : single;
	TariSum  : single;
	TmaniSum : single;
	mbnSum : array[1..6] of single;
	ednumSum,elnumSum : array[1..3] of single;
	HjEggSum,HjLarSum,HjAdlSum : single;

{variables relating to multi season runs}
{ Booleans to turn on seasonal random variations of selected variables}
	varNPlants,varnitro,varwater,varspacing,varplanting:boolean;
	varcmbstart,varcmbnm1,varcmbprob,varcmbimm:boolean;
	varelstart,varelprob,varelimm,varedstart,varedprob,varedimm:boolean;
	vargmstart,vargmprob,varTaripoprob,varTmanihotiprob:boolean;
	varTaripoalpha,varTmanihotialpha:boolean;

{limits of variability between seasons (all declared as integers here)}
	NPlantsSeasonalVar,  {Number of plants}
	nseasonalvar,        {soiln}
	oseasonalvar,         {org : soil organic N}
	phseasonalvar,       {phosphate}
	wseasonalvar,        {soil water}
	plseasonalvar,       {plant spacing}
	roseasonalvar,       {row spacing}
	cmbstartseasonalvar, {cmb start +- 30 days}
	cmbnm1seasonalvar,   {number of initial cmb}
	cmbprobseasonalvar,  {prob. of immigr. event for each plant each day}
	cmbimmseasonalvar,   {number immigrating to a plant}
	edstartseasonalvar,  {epi. divers. start +- 20 days}
	edprobseasonalvar,   {prob. of immigr. event for each plant each day}
	edimmseasonalvar,    {number of e.d. immigrants each day}
	elstartseasonalvar,  {epi. lopezi start +- 20 days}
	elprobseasonalvar,   {prob. of immigr. event for each plant each day}
	elimmseasonalvar,    {number of e.l. immigrants each day}
	gmstartseasonalvar,  {green mite start +- 20 days}
	gmprobseasonalvar,   {prob. of immigr. event for each plant each day}
	Taripoprobseasonalvar,   {prob. of immigr. event for each plant each day}
	Tmanihotiprobseasonalvar,    {prob. of immigr. event for each plant each day}
	Taripoalphavar,Tmanihotialphavar {variability of alphas cross seasons}
	: integer;

{Values of variables set each season to be saved in mulfile.}
	insoiln,inorg:single;
	tubermean:single;
implementation
end.
