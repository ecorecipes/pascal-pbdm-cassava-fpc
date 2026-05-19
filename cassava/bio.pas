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

Unit bio;
interface
uses globals,Modutils;

Procedure Getlai(totall,sqdmpl,tdda,dmgmle:single;var lai:single);
Procedure Getlais;
procedure rootfractions(variety:varietyrec;density:single;var plant:plantrec);
Procedure Usereserves(var plant:plantrec;np:integer);
Procedure Supply(lai,solrad,density,b,costmr,costlr,costph,resinc,wsd,nsdlsr:single;
		 var totph,pcost:single;sqdmpl:single);

Implementation

Procedure Getlai(totall,sqdmpl,tdda,dmgmle:single;var lai:single);
{LAI for one plant}
begin
	lai:=0.0;
	if totall > 0.0 then
	begin
{
		Leaf Area Index
		lai    = (leaf area of plant)/(ground area of plant)
		dmgmle = decimeter/(gm leaf)
		totall = total leaf mass

		sqdmpl = sq decimeter/plant
	       space available for light supply is area bounded by midpoint
    	   between edges of this plant and its neighbors. (Setsides)
}
		lai := (totall*dmgmle)/sqdmpl;
		{ lai is zero before emergence:}
		if((tdda<100.0)or(lai<=0.0))then lai:=0.0;
	end; {totall>0}
end; {getlai}


Procedure Getlais;
{Compute Fieldlai to be used in Ritchie and saved in means file.}
var 
	totlfmass,totsqdmpl:single;
	i:integer;
begin
	totlfmass:=0.0;
	totsqdmpl:=0.0;
	for i:=1 to ncas do with casvar do with casPtrs[deck[i]]^ do 
	begin
		{
		For lai calculation include leaf damaged by green mite.  It still
		produces shadow.
		}
		leaftot:=totall;
		if gmthisplant then leaftot:= totall+ sum(gmfood,1,kfol)*delkfol;
		getlai(leaftot,sqdmpl,tdda,casvar.dmgmle,lai);
		totlfmass:=totlfmass+leaftot;
		totsqdmpl:=totsqdmpl+sqdmpl;
		{maxlai is the running max lai of one plant.}
		maxlai:=max(maxlai,lai);
	end;
	if totsqdmpl>0.00001 then fieldlai:=(totlfmass*casvar.dmgmle)/totsqdmpl;
end;


Procedure Usereserves(var plant:plantrec;np:integer);
(*
Check for overdraft.  Allow reserves to be used .
*)
var
	deficit:single;

begin
	with plant do
	begin
		if totph<0.0 then
		begin
			deficit:=-totph;
			if (reserves >= deficit)then
			begin
				reserves:=reserves-deficit;
				totph:=0.0;
	        end
			else
			if((id='cas') and ((reserves+tuber) >= deficit)) then
			begin
				tuber := tuber+reserves-deficit;
				reserves := 0.0;
				totph:=0.0;
			end
			else

			begin
				done:=true;
			end;
		end;
	  end;{with plant}

end; { Usereserves }


Procedure Supply(lai,solrad,density,b,costmr,costlr,costph,resinc,wsd,nsdlsr:single;
         var totph,pcost:single;sqdmpl:single);
{*
 Calculate the supply of photosynthate per plant based on leaf area per
 decimeter, light in watts and plant demand. Resolve costlr and costmr here.
*}
var
   a,grams,phosyn,phosyn1:single;
begin
    a:= 1.0-expo(-0.8047*lai);       {F-G search area}

	//kilocalories/sq cm/ day :=> g carbohydrate/ plant/ day
	//LOOMIS AND WILLIAMS (1963)
	grams  := solrad/3.875;

	grams:=grams*sqdmpl/100.0; {adjust grams by area of plant}
	{adjust by light area or smaller plant area?}
		

	phosyn := b*wsd*nsdlsr * (1.0 - expo(-a*grams/b)); {b= G-B max demand}
	phosyn1:= phosyn;
	phosyn := phosyn/(1.0+costlr);
	phosyn1     := phosyn1+resinc;             { reserve increment (tuber in cas)}
	phosyn := phosyn+resinc;
	phosyn := (phosyn-costmr);
	phosyn := phosyn/(1.0+costph);
	pcost  := phosyn1-phosyn;
	totph  := totph+phosyn;
end; {supply}


Procedure Rootfractions(variety:varietyrec;density:single;var plant:plantrec);
{
    Rootdepth is a function of varietal maxdepth and current ratio
    of lai to varietal lai max.
    Variables f1,f2,f3 are computed for each plant to represent
    the fraction of each soil layer penetrated by the root.
    Not used Feb 96.
}

begin
    with plant do
    begin
        rootdepth:=max(rootdepth,variety.maxdepth*lai/variety.laimax);
        rootdepth:=min(rootdepth,variety.maxdepth); {?}
		{rootdepth:=variety.maxdepth;}

		if rootdepth <= layer[1].bottom then
		begin
			f3:=0.0;
			f2:=0.0;
			f1:=rootdepth/layer[1].bottom;
		end
		else
		if rootdepth <= layer[2].bottom then
		begin
			f3:=0.0;
			f2:=(rootdepth-layer[2].top)/(layer[2].bottom-layer[2].top);
			f1:=1.0;
		end
		else				
		if rootdepth>layer[2].bottom then
		begin
			f3:=(rootdepth-layer[3].top)/(layer[3].bottom-layer[3].top);
			f2:=1.0;
			f1:=1.0;
		end;
	end;{with plant}
end; {rootfractions}
end.
