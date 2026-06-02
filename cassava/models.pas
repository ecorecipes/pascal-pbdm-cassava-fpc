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

Unit models;
interface
uses globals,Modutils,water,Hyperaspis,mb,para,casbio,bio,gmite,preds,nitr,output,rng;

procedure plantsloop;
implementation

Procedure Cascmb(np:integer);
{Called daily from Plantsloop.  Here the cassava and cmb models are called.}
var
	sl,sa,sr,sb:single;
	soilw1meter:single;
	cptr:plantptr;
	rx:single;

	mblarv:single;
begin
	cptr:=casPtrs[np];

	with cptr^ do	if (not done) then
	begin
{
Soilw1meter is the water available under a 1 sq-meter area centered on
the current plant.  This is used to modify emergence time based on water.
Call Wav with sides of rectangle centered on this plant.
}
		sl:=x-0.5;sa:=y-0.5;sr:=sl+1.0;sb:=sa+1.0;
		soilw1meter:=wav(sl,sa,sr,sb);
        	if emerging then
	        begin
        	    with layer[1] do h2odelay:=(soilw1meter-pwp)/(soilwmax-pwp);
	            if h2odelay<0.4 then h2odelay:=0.4;
        	    if h2odelay>1.0 then h2odelay:=1.0;

	        end;
{	if (tdda>=200.0/h2odelay)then}
	if (tdda>=100.0/h2odelay)then
	        begin
			CasDemand(cptr^);
			Ndemand(cptr^,casvar);
			{Calculate F1,F2,F3 = root depth in 3 layers.}
			{Currently not used. feb 96}
			{Rootfractions(casvar,casdensity,cptr^);}

			resinc:=tuber*0.0025;
			tuber:=tuber-resinc;
			totph:=0.0;

			Supply(lai,solrad,casdensity,b,costmr,costlr,
			casvar.costph,resinc,wsd,nsdlsr,totph,pcost,sqdmpl);

			usereserves(cptr^,np);
			if (not done)then
			begin
				Nsupply(cptr^,nuptkpot);
				if cmbthisplant then with mbPtrs[np]^ do
				begin
					{Mbstart is the actual start date of this population.}
					cmbgo:=((ModelDate>mbstart) and (not cmbfin));
					if(cmbgo)then
					begin
						{mealy bug may reduce totph,res,tubr}
						Cmbmod(np,totph,reserves,tuber);
						UseReserves(cptr^,np);
					end;
				
					mbdays:=mbdays+mbn[1]+mbn[2]+mbn[3]+mbn[4]+mbn[5]+mbn[6];

					if (elthisplant and cmbgo) then
						with elPtrs[np]^ do eldays:=eldays+elnum[1]+elnum[2]+elnum[3];
					if (edthisplant and cmbgo) then
						with edPtrs[np]^ do eddays:=eddays+ednum[1]+ednum[2]+ednum[3];
				end;

				Transpiration(cptr^); {get transpiration for each plant}
				Wratio(cptr^);
	
				{Allow random immigrations after d1cmb the earliest cmb
				 start date.}

				{does this plant receive immigrants?}
		             	if (cmbin and (ModelDate>d1cmb))then
				begin
					rx:=random;
					if(rx<=mbimmigprob)then Cmbimmig(cptr^,np);
				end;

				if (cmbin)then with cptr^ do with mbPtrs[np]^ do
    				if (cmbgo and (edin or elin)) then
				begin
					mblarv:=mbn[3]+mbn[4];
					{Ed or El start when mb larva numbers > mbLevEdStart,mbLevElStart.}
					if(edin and (mblarv>mbLevEdStart))then goed:=true;
					if(elin and (mblarv>mbLevelStart))then goel:=true;

				  	paras(np,goel,goed,mbn);
    				end;

				Nratio(cptr^,nuptkpot);

				CasRatio(cptr^);
				sdavg:=sdavg+sdlsr;
				if (sdlsr > 0.0)then Rebran(np,sdlsr,wsd);
				Growth(cptr^);
				Leaves(cptr^);

				Nplant(cptr^,casvar);
				nused(cptr^);                        
			end;{not done}

		end; { if (tdda>=200.0/h2odelay)}
	end; {cptr^}
end;


procedure plantsloop;
{
Called daily to loop through calls to each model - cassava (and insects).
}

var
	i,np:integer;
begin
	nuptk:=0.0;
	sdavg:=0.0;
	
	for i:=1 to ncas do
	begin
		np:=deck[i];
		if casloc[np].aplant then
		begin

			cascmb(np); {cassava and cmb [+el,ed] models}
			
			{
			 If Green mite is included in this run and its start date has
			 been reached call green mite routine.
			 }

			if(gmin and (ModelDate>gmstartday))then
			begin
				greenmite(np);
			
				with gmptrs[np]^ do
				begin
					{Check for gm totwgt big enough to attract start of Taripo,Tmanihoti.}
					if (Taripoin and (gmtotwgt>gmWgtTaripoStart))then goTaripo:=true;
					if (Tmanihotiin and (gmtotwgt>gmWgtTmanihotiStart))then goTmanihoti:=true;
				end;
					if((Taripoin)or(Tmanihotiin))then greenpreds(np);
			end;

			if hjin then hjmod(np);

		end; {aplant here}
	end;{np 1,ncas}
end; {plantsloop}
end. {unit}
