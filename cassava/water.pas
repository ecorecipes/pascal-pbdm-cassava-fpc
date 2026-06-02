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

Unit water;
interface
uses globals,Modutils,spatial,rng;

procedure initwat(var layer:soilrec);
Function Wav(sl,sa,sr,sb:single):single;
Procedure Waterdemands;
Procedure Transpiration(var plant:plantrec);
Procedure Wratio(var plant:plantrec);
procedure waterbalance;

implementation

procedure initwat(var layer:soilrec);
{call once for each layer to be used (single, or 3 layer methods)}
{Initialize the total water contents of the layer and distribute
water in the 2-d array according to specified distribution;}
var
	swin,val,wmax,wmin:single;
	i,j,ix,iy:integer;
(*

each layer has the following:
soilrec = record
	top,bottom   : single; {dx from soil surface}
	pwp,soilwmax : single; {permanent wilting point, soil water max}
	avlw		 : mean water/sq-meter in layer
	warray:array[1..22,1..22] of single; {water in each 1/4 sqmeter in layer.}
*)
begin
{with single layer method:}
	with layer do
	begin
		top:=0.0;
		bottom:=0.75;
		pwp:=totpwp;
		soilw:=Soilwin;
		soilwmax:=Soilwmaxin;
		if varwater then 
		begin
			{if wseasonalvar=30 then Soilw will be Soilwin+-30%, <=soilwmax}
			soilw:=fran(soilw,wseasonalvar);
			if soilw>soilwmax then soilw:=soilwmaxin;
		end;
		avlw:=10.0;
	end;
(*
 {with 3 layer method:}
	for i:=1 to 3 do with layer[i] do
	begin
		frac:=(bottom-top)/2.5;
		pwp:=totpwp*frac;
		soilw:=Soilwin*frac;
		soilwmax:=Soilwmaxin*frac;
		avlw:=10.0*frac;
	end;
*)

	{initialize water in each cell according to the type of distribution
	 specified in the setup file in variables watdis, watdisvar, and watgrad.}
	with layer do
	begin
		swin:=soilw/4.0; {initial cell contents=1/4 that of 1 sq m.}
		case watdis of
			'U' : {Uniform}
			begin
				for ix:=1 to 22 do for iy:=1 to 22 do 
					warray[ix,iy]:=swin;
			end;

	
			'G' : {gradient}
			{
			The water is initialized as a linear gradient from wmin to wmax across
			the field in 1 of 4 directions.
			}
			begin
				wmin:=swin*(1.0-watdisvar);
			   	wmax:=swin*(1.0+watdisvar);
				if wmax >(soilwmax/4.0) then
				begin
					writeln('Max water in gradient set to soilwmax=',soilwmax:9:2);
					wmax:=soilwmax/4.0;
				end;
				
				if watgrad=1 then {gradient left to right}
			   	begin
					for ix:=1 to 22 do
   					begin
   						val:=wmin+(ix-1)*(wmax-wmin)/21.0;
	   					for iy:=1 to 22 do
   						warray[ix,iy]:=val;
				   		end;
   				end;

				if watgrad=2 then {gradient top to bottom}
				begin
   					for iy:=1 to 22 do
	   				begin
   						val:=wmin+(iy-1)*(wmax-wmin)/21.0;
   						for ix:=1 to 22 do
   							warray[ix,iy]:=val;
			   			end;
	   			end;

   				if watgrad=3 then {gradient right to left}
			   	begin
   					for ix:=1 to 22 do
   					begin
   						val:=wmax-(ix-1)*(wmax-wmin)/21.0;
   						for iy:=1 to 22 do
   							warray[ix,iy]:=val;
			   		end;
	   			end;

   				if watgrad=4 then {gradient bottom to top}
			   	begin
   					for iy:=1 to 22 do
   					begin
   						val:=wmax-(iy-1)*(wmax-wmin)/21.0;
   						for ix:=1 to 22 do
  							warray[ix,iy]:=val;
			   		end;
	   			end;
			end; {'G'}

			'R' : {random  initial mean +- watdisvar}
			begin
				wmin:=swin*(1.0-watdisvar);
				wmax:=swin*(1.0+watdisvar);
				if wmax >(soilwmax/4.0) then wmax:=soilwmax/4.0;

				for i:=1 to 22 do for j:=1 to 22 do
					warray[i,j]:=wmin+random*(wmax-wmin);
			end;
		end; {case}

	end; {with layer}
	fieldES1:=0.0;
	fieldes2:=0.0;
	fieldwatfirst:=true;
	fieldwatertime:=0.0;
	totevap:=0.0;
	sumtransp:=0.0;
end;


Procedure Ritchi(lai,tmean,solrad,rhmean,wind:single;
 var watfirst:boolean; var watertime,es1,es2,wdemand,evapsoil:single);
(*
Inputs:
	tmean,solrad,thmean,wind, solrad: weather,
	lai
	watfirst,watertime,es1,es2
outputs:
	Water evaporation from soil and transpiration demand of plant.

  eo = potential evaporation
  ep = evapotranspiration (returned as wdemand)
  evapsoil = evaporation from the soil [mm=l/m2]
  wdemand = tritch= ritchie transpiration (=ep) [mm]
  albedo = albedo soil (0.055)
  es1,es2 = stage 1,2 evaporation from the soil.
  	stage 1: wet soil fast rate, stage 2 dryer soil slower rate.
  U	= cumulative evaporation for stage 1, U=2.589+62.9*hydroc
  coeff = 2.443+17.194*hydroc
  esuba = mean vapor pressure of the atmosphere calculated from DBULB
	   and WBULB temperatures [millibars]
  delta=slope of the saturation vapor pressure curve at mean air
  temperature (temp. input in degrees celsius).
  gamma=constant of the wet and dry bulb psychrometer equation
  hydroc=hydraulic conductivity of the soil at -0.1bar  (0.1)
  matric potential - used for calculation stage 1 drying rate of soil
  general form for gamma = .0006595*barometric pressure in millibars
	pwp = permanent wilting point (from infile)
  This program is different from the original Ritchie-program. The plant
  transpiration is calculated before the soil evaporation. Since evapsoil+ep
  equals at most eo(potential evaporation), evapsoil is restricted to eo-ep.
  Ritchi computes evapotranspiration with non-limiting water = demand
*)
Label
	1,2,3,4;
const
	albedo = 0.055;
	gamma  = 0.66;
	hydroc = 0.05;

var
   prec,u,coeff,alpha,q,rno,tk,esubo,esuba,delta : single;
   eso,eo,ep : single;
begin

	prec:=precip;
	U:=2.59+62.9*hydroc;
	coeff:=2.44+17.19*hydroc;
	alpha:=albedo+0.25*(0.23-albedo)*lai;
	{ Q is an adjusting scalar to reduce demand. Species dependant? }
	Q:=0.75;
	
	RNO:=Q*0.76*(1.0-alpha)*SOLRAD-20.0;
	if rno<=0.0 then rno:=0.01; {12/4/91 extreme low solrad}
	RNO:=RNO/59.0;	{ 1mm corresponds to 59cal }
	TK:=TMEAN+273.0;
	if(RHMEAN = 0.0)then RHMEAN:=55.0;

	esubo:=expo(54.878919-(6790.4985/TK)-(5.02808*ln(TK)));
	esuba:=esubo*RHMEAN/100;
	delta:=(esubo/TK)*(6790.4985/TK-5.02808);
	ESO:=(delta/(delta+gamma))*(RNO*expo(-0.398*lai));

	{eo=potential evaporation (Penman)}
	eo:=(delta/gamma*RNO+0.262*(1.0+0.0061*WIND)*(esubo-esuba))*(gamma/(delta+gamma));
	{
	  compute plant evapotranspiration ep as a function of lai and eo.
	  if lai becomes larger than 2.98, plant transpiration would exceed
	  total potential transpiration eo. Therefore ep is set to eo and
	  evapsoil to 0 (shaded soil). 
	}
	ep:=0.0;
	if lai>2.98                    then ep:=eo;
	if ((lai<=2.98)and(lai>0.091)) then ep:=eo*(-0.21+0.70*power(lai,0.5));
	if lai<=0.091                  then ep:=0.01;
	if(watfirst)then goto 1;
	if(es1 >= U)then goto 3;
1:	if(prec < es1)then es1:=es1-prec
	else
		begin
			watfirst:=false;
			es1:=0.0;
		end;

2:	if (ESO > eo-ep)then  ESO:=eo-ep;
	es1:=es1+ESO;
	if(es1 <= U)then evapsoil:=ESO
	else
	begin
		evapsoil:=ESO-0.4*(es1-U);
		es2:=0.6*(es1-U);
		watertime:=power((es2/coeff),2.0);
	end;
	goto 4;

3:	if(prec >= es2)then 
	begin
		prec:=prec-es2;
		es2:=0.0;
		es1:=U-prec;
		if(prec > U)then es1:=0.0;
		goto 2;
	end;
	watertime:=watertime+1.0;
	evapsoil:=coeff*sqrt(watertime)-coeff*sqrt(watertime-1.0);
	if(prec > 0.0)then
	begin
(* {replace next 4 lines with following 2 lines}
		ESX:=0.8*prec;
		if(ESX < evapsoil)then  ESX:=evapsoil+prec;
		if(ESX < ESO)then ESX:=ESO;
		evapsoil:=ESX;
*)
		if (evapsoil>=(0.8*prec)) then evapsoil:=evapsoil+prec;
		if (evapsoil<eso)         then evapsoil:=eso;
	end;
	if(evapsoil > (eo-ep))then  evapsoil:=eo-ep;
	es2:=es2+evapsoil-prec;
	watertime:=sqr(es2/coeff);
4:	wdemand:=ep; {tritch}
	if evapsoil<0.0 then evapsoil:=0.0;
end;


function Wav(sl,sa,sr,sb:single):single;
{get W available from wcells which overlap a rectangle in the field.}
{sl,sa,sr,sb are sides of the rectangle in meters from left and top}
{Each Wcell is 1/4 of a sq. meter.}
{Units: Wav=g?  =g/m^2?}
var
	tota,ac:single;
	frac,wtot,incr:single;
	i1,i2,j1,j2,i,j:integer;
begin
{Set i1.., j1.. , the indeces of Warray cells near this rectangle.}
{These must accord with dimensions of warray[22,22].}

{FEB 5 96.  ON LEFT AND TOP EDGES SL AND SA CAN BE <0.0.  TO MAP THEM INTO
 WARRAY INDECES TRUNCATION DOESN'T WORK.  TEST THEM FOR <0.0.}
	IF SL<0.0 THEN I1:=1 ELSE	i1:=trunc(sl*2)+2;
	i2:=minint(trunc(sr*2)+2, 22);
	IF SA<0.0 THEN J1:=1 ELSE   j1:=trunc(sa*2)+2;
	j2:=minint(trunc(sb*2)+2, 22);

	tota:=0.0;
	wtot:=0.0;
	for i:=i1 to i2 do
	for j:=j1 to j2 do
	begin
		ac:=cellarea(i,j,sl,sa,sr,sb); {area overlap in cell(i,j)}
		frac:=ac/0.25; {fraction of warray cell area in overlap}
		incr:=frac*(layer[1].warray[i,j]);
		if incr<0.0 then incr:=0.0;
		wtot:=wtot+incr;
		tota:=tota+ac;		
	end;
	Wav:=wtot;
end;


Procedure Waterdemands;
(*
 Call Ritchi with composite fieldlai to get soil evap/sq-m for field;
 Call Ritchi with lai of each plant for each wdemand.
*)
var
	wd,ev:single;
	i:integer;
begin
	Ritchi(fieldlai,tmean,solrad,rhmean,wind,
 	fieldwatfirst,fieldwatertime,fieldes1,fieldes2, wd,fieldevapsoil);
	fielddem:=wd;

	totevap:=totevap+fieldevapsoil;
	avgwd:=0.0;
	avgev:=0.0;

	for i:=1 to ncas do with casPtrs[deck[i]]^ do 
	begin

		Ritchi(lai,tmean,solrad,rhmean,wind,
 		watfirst,watertime,es1,es2, wdemand,ev);
 		avgwd:=avgwd+wdemand;
 		avgev:=avgev+ev;
	end;
	avgwd:=avgwd/ncas;
	avgev:=avgev/ncas;
end;


Procedure Wsupply(var plant:plantrec);
(*
 Compute Transpire - the supply to the plant;
	plantrec.wdemand   = Ritchie-transpiration (demand)(tritch)
	plantrec.Transpire = transpiration (supply)
	plantrec.tdda      = total dd		
	plantrec.lai       = lai (per plant)
	plantrec.prevawat  = previous value of A
	Soilwin            = Initial soil water content (liters/ varietal root zone)
	avlw               = water available to plant
	totpwp                = permanent wilting point
*)
var
a,avlw,frac : single;
begin
	with plant do
	begin
		Transpire:=0.0;
		if((tdda < 100.0) or (lai <= 0.0))then lai:=0.0;
		{use area of plant to compute A rather than lai?}
		A := 1.0 -EXP(-0.8047*lai);
		if(A <  0.05)then A:=0.05;
		if(A < prevawat)then  A:=prevawat;
		prevawat:=A;
		avlw:=wav(sidel,sidea,sider,sideb);
		frac:=(sider-sidel)*(sideb-sidea); {fraction of 1 sq-meter}
		avlw:=avlw-(frac*totpwp);
		{ Frazer-Gilbert model PREDATOR FORM }
		if(avlw > 0.0)then Transpire:=wdemand*(1.0-expo(-A*avlw/wdemand));
	end;{with plant}
end;


Procedure Transpiration(var plant:plantrec);
(*
 Called once for each plant.
 How much water is supplied to plant transpiration (from each soil layer).
 *)
begin
	with plant do
	begin
		Wsupply(plant);
	end;{with plant}
end; {transpiration}


Procedure Wratio(var plant:plantrec);
{ Called once for each plant.
 wsdarray can hold up to 10 recent values of wsd for running avg.}
var
	i:integer;
	ndaysavg:byte; {number of days to average wsd}
begin
	with plant do
	begin
	if (lai > 0.01)then
		begin
 			wsd:=MIN(Transpire/wdemand,1.0);
			if(wsd = 0.0)then  wsd:=0.00001;
			{fill wsdarray initially with  0.6?}
			if iwsd=0 then for i:=1 to 10 do wsdarray[i]:=1.0;

			{running average}
			ndaysavg:=3;
			inc(iwsd);
			if iwsd>ndaysavg then iwsd:=1;
			wsdarray[iwsd]:=wsd;
			wsd:=0.0;
			for i:=1 to ndaysavg do wsd:=wsd+wsdarray[i];
			wsd:=wsd/ndaysavg;
		end;
	end;{with plant}
end;


procedure wused(plant:plantrec);
{For one plant subtract water used from cells in the water array which
overlap with plant space}
{Each cell is 1/4 of a sq. meter.}
var
	ac:single;
	frac,wavail,wincell,wdecr:single;
	tdecr:single;
	i1,i2,j1,j2,i,j:integer;
begin
	with plant do
	begin
		wavail:=wav(sidel,sidea,sider,sideb);
		frac:=(sider-sidel)*(sideb-sidea); {fraction of 1 sq-meter}
		wavail:=wavail-(frac*totpwp);
{Set i1.., j1.. , the indeces of warray cells near this plant.}
		i1:=trunc(sidel*2)+2;
		i2:=minint(trunc(sider*2)+2, 22);
		j1:=trunc(sidea*2)+2;
		j2:=minint(trunc(sideb*2)+2, 22);
		tdecr:=0.0;
		{The i1.., j1.. are indeces of warray cells.}
		for i:=i1 to i2 do
		for j:=j1 to j2 do
		begin
			ac:=cellarea(i,j,sidel,sidea,sider,sideb); {area overlap in cell(i,j)}
			frac:=ac/0.25;{fraction of warray cell area in overlap} 
			with layer[1] do
			begin
				wincell:=frac*(warray[i,j]-totpwp*0.25);

				wdecr:=0.0;
				if wavail>0.0 then 
					{fraction of transp from cell i,j}
					wdecr:=transpire*wincell/wavail;
				warray[i,j]:=max(warray[i,j]-wdecr,0.0); {subtract water used}
				tdecr:=tdecr+wdecr;
			end;{layer1}
		end;{i,j}
	end;{plant}
	sumtransp:=sumtransp+tdecr;
end;


Procedure fieldevap;
{Called once daily to take evaporation from field soilw}
var
	ix,iy:integer;
	delcell:single;
begin
	delcell:=fieldevapsoil/4.0; {assumes that ritchi output is per 1sqm.}
	with layer[1] do
	for ix:=1 to 22 do for iy:=1 to 22 do 
   	begin
    	warray[ix,iy]:=warray[ix,iy]-delcell;
{check for min here}
   	end;
end; 


Procedure fieldprecip;
{Called once daily to add any precip to field soilw }
var
	ix,iy:integer;
	delcell,swmax:single;
begin

{The precip is per sq-m so each cell gets 1/4 of precip.}
	delcell:=precip/4.0;
	swmax:=Soilwmaxin/4.0;

	with layer[1] do
	for ix:=1 to 22 do for iy:=1 to 22 do 
   	begin
		{each cell limited to soilwmax/4.0} 
    	warray[ix,iy]:=min(warray[ix,iy]+delcell, swmax);
   	end;
end; 


procedure waterbalance;
{
	Update soilwater each day using field evap., precip, transpiration.
}
var
	i:word;
begin

{23sep93  allow evap and precip to operate over entire field.
 need to consider effects of local lai\shading}
	fieldevap;
	with layer[1] do
	if precip>0.0 then fieldprecip;
	for i:=1 to ncas do 
		wused(casPtrs[deck[i]]^); {23sep93  transpiration is taken locally for each plant.}
end; {waterbalance}

end.

