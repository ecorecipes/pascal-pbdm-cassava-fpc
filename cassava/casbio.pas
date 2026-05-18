{ Authors: 
- Andrew Paul Gutierrez (University of California, Berkeley / CASAS Global 
	(Center for Analysis of Sustainable Agriculture Systems) 
	<casas.kensington gmail.com>
- Luigi Ponti (ENEA - Agenzia nazionale per le nuove tecnologie, l'energia e 
	lo sviluppo economico sostenibile / CASAS Global) <quartese gmail.com>

Copyright: (C) CASAS Global (Center for the Analysis of Sustainable 
	Agricultural Systems)

SPDX-License-Identifier: GPL-3.0-or-later }

Unit Casbio;
interface
uses globals,Modutils;

Procedure Casdemand(var plant:plantrec);
Procedure CasRatio(var plant:plantrec);
Procedure Growth(var plant:plantrec);
Procedure Leaves(var plant:plantrec);
Procedure Rebran(np:integer;sdlsr,wsd:single);

Implementation
(*
Procedure needreserves(np:integer);
{
overdraft.  Allows reserves to be used .
}
var
	deficit:real;
begin
	textcolor(green);
	with casPtrs[np]^ do
	begin
	deficit:=-totph;

	if(reserves >= deficit)then
	begin
		reserves:=reserves-deficit;
		totph:=0.0;
        end
	else

	if(reserves+tuber) >= deficit then
	begin

		tuber := tuber+reserves-deficit;
		reserves := 0.0;
		totph:=0.0;
        end
	else
	begin

		done:=true;
	end;
	end;{casPtrs[]}

end; { needreserves }
*)

Procedure Growth(var plant:plantrec);
(*
 Given today's S/D, determine what portion of demands actually
 are realized as growth increments.
 Subtract those from the phosyn pool.
*)
var
	stemout,rootout:single;

begin
	with plant do
	begin
		glf := dl*sdlsr;
		{ grow  stems, roots, reserves}
		gf     := 0.0;
		gs     := ds    *sdlsr;{88}
		gr     := dr    *sdlsr;
		gtuber := dmtuber*sdlsr;
		gres   := dmres *sdlsr;
		{ Add increments to stems, roots, reserves. }
		reserves := reserves + gres;
		tuber := tuber + gtuber;
		{ Subtract growths from totph }
		totph := totph -(glf+gres+gs+gr+gtuber);
		if(totph < 0.0)then totph:=0.0;
		{any extra to reserves}
		reserves := reserves + totph;

		{ Age stems and roots }
		{ Add increments to stems, roots, reserves. }
		totph := 0.0;
		with casvar do
		begin
			DelayNoPLR(gs,stemout,stemwgt,delstem,dda,kstem);
			DelayNoPLR(gr,rootout,rootwgt,delroot,dda,kroot);
			totals:=sum(stemwgt,1,kstem)*delkstem;
			totalr:=sum(rootwgt,1,kroot)*delkroot;
		end;{casvar}
	end;{plant}
end; { Growth }


Procedure Rebran(np:integer;sdlsr,wsd:single);
{ branching decision }
begin
	with casvar do
	with casPtrs[np]^ do
	begin
		branchtime:=branchtime+dda;
		if(branchtime > (critera/sdlsr))then
		begin
			branch:=branch*3;
{			if(branch >= 3)then critera:=critera;}
			branchtime := 0.0;
			if(branch > 6)then branch:=6;
		end;
	end;{with casvar,casPtrs}
end; { Rebran }


Procedure Leaves(var plant:plantrec);
var
   	age,dwt,f,fshed,ri,rk,grl,decr,folinn : single;
	totoldstem,mort:single;
	kinc:single;
	i,j,k,k1,k2:byte;
begin
	{ growth of existing leaves and reallocation of N from old leaves }
	with plant do

	with casvar do
	begin
		ndwt:=0.0; {for single plant accounting check}
		F:=delkfol*exp(grlfmul*nsdlsr);
		for i:= 1 to kfol do
		begin
			if(folnum[i] > 0.0)then
			begin
				grl:=0.0;
				age:=(I-0.5)*delkfol;
	 			if(age <= 250.0)then grl:=0.0048*exp(0.0048*age) * 1.05;
				dwt := sdlsr*folnum[i]*grl*dda;
				folwgt[i]:=folwgt[i]+dwt;
				folnit[i]:=folnit[i]+dwt*ndlmul*nsdlsr*sdlsr;
				ndwt:=ndwt+dwt*ndlmul*nsdlsr*sdlsr;
				if folwgt[i]>0.0 then

				if(folnit[i]/folwgt[i] > 0.013)then
				begin
					{ reallocation of N from ageing leaves to reserves
					  N extraction from old leaves is inversely proportional to K
					  F  allows greater N use at low nsdlsr 
					}
					RI:=I*F;
					RK:=RI/delfol *0.025; {0.03}
					nres:=nres+RK*folnit[i]*delkfol;
					folnit[i]:=folnit[i]*(1.0-RK);
				end;
	
			end;
		end; { loop i:=1 to kfol }
		ndwt:=ndwt*delkfol;

		{ Call delay for leaves numbers, wgt }
		folinn:=(dda/16.5)*branch*cbfact*sdlsr  * 1.05;
		folinmass:=0.0005*folinn*dda;
		if sdlsr>0.0 then sumflin:=sumflin+folinn; {/sdlsr;}
		DelayNoPLR(folinn,fshed,folnum,delfol,dda,kfol);
		DelayNoPLR(folinmass,fshed,folwgt,delfol,dda,kfol);
		if gmthisplant	then DelayNoPLR(0.0, fshed, gmfood,delfol, dda,kfol);

		kinc:=kfol/12.0;
		k2:=0;
		for j:=1 to 12 do
		begin
			k1:=k2+1;
			k2:=round(j*kinc);
			if k2>kfol then k2:=kfol;
			LeafMass12[j]:=0.0;
			for k:=k1 to k2 do	LeafMass12[j]:=LeafMass12[j]+folwgt[k];
			leafmass12[j]:=leafmass12[j]*delkfol;
		end;

		{update reserves}
		reserves:=reserves+0.2*fshed*delkfol;

		{20% of shed leaves are petioles--take from last half of stem array. }
		{transform leaf mass decrement to stem rate:}
		decr:=0.2*fshed*delkfol/delkstem;
		j:=(kstem div 2)+1;
		decr:=decr/((kstem-j)+1); {apportion among last half of stem array}

		totoldstem:= sum(stemwgt,j,kstem);
		if totoldstem>0.0 then
		begin
			mort:=(1.0-(decr/totoldstem));
			if mort<0.0 then mort:=0.0;
			for i:=j to kstem do stemwgt[i]:=stemwgt[i]*mort;
		end;
		dlfmass:=sum(folwgt,1,kfol)*delkfol-totall;
		totall:=sum(folwgt,1,kfol)*delkfol;
		tfolnum:=sum(folnum,1,kfol)*delkfol;

	end; {with casvar,plant}
end; {leaves}


Procedure Casdemand(var plant:plantrec);
var
	i,kk : integer;
	age,grl,folinn : single;
begin
	with casvar do
	with plant do
	begin
	{ leaf demand}
		dl:=0.0;
		kk:=trunc(250.0/delkfol);
		for i:=1 to kk do
			if(folnum[i]>0.0)then
			begin
				{ age = mid of each bin in fol arrays       }
				age:=(I-0.5)*delkfol;
{				grl:=grl1*expo(grl2*age);}
				grl:=0.0048*expo(0.0048*age) *1.05;
				dl:= dl+ folnum[i]*grl*dda;
			end;

		folinn:=(dda/16.5)*branch*cbfact * 1.05;
		folinmass:=0.0005*folinn*dda;


		dl := dl*delkfol + folinmass;
		{ stem, root and reserve demands }
		dr:= drmul * dl;
		ds := dsmul1*dl;
		ds := ds + (dsmul2*dl-ds)*tdda/dms2time ;
		if(tdda > dms2time)then ds := dsmul2*dl;
		dmres := dmresmul*dl;

		{tuber demands }
		dmtuber:= dl*dmtb1;

		dmtuber:=dmtuber+ (dmtb2*dl-dmtuber)*tdda/dmt2time;
		if(tdda > dmt2time)then dmtuber := dmtb2*dl;
		dmlsr := dl + ds + dr + dmres+ dmtuber;
{
 When sdlsr > brathr (branch threshold) new branches
 are formed. (Branch is count of branches, is set in rebran.)

 costs------------------------------------------------------------------
 cost of maintenance respiration (temperature dep. function of active wgt)
}
		activ := totall + sum(stemwgt,1,(kstem div 10)) +
		 sum(rootwgt,1,(kroot div 10)) +
		 tuber*0.01;
		{  costmr from rice }
	 	costmr := 0.01*activ* power(2.0, 0.1*(tmean-20.0));
		{ cost of light respiration (as a fraction of total demand) }
		costlr := 0.0032125+0.0066875*tmean;
		{ cost of photosynthesis as a fraction of growth demand }
		{ cost of photosynthesis will be adjusted in subroutine supply. }
		costph := 0.273;
		{ demand rate per day degree   }
		b := (dmlsr*(1+costph)+costmr)*(1+costlr);
		b:= b*wsd*nsdlsr;
		{ adjust demand for gm damage }
		leaftot:= totall+ sum(gmfood,1,kfol)*delkfol;
		if leaftot>0.0 then b:=b*totall/leaftot ; 
	end;{with}
end; {demand}


Procedure CasRatio(var plant:plantrec);
{
 Update the supply/demand ratio.
	 Dmlsr   -	 combined demand of leaves,stems,roots
	 sdlsr   -	 S/D for leaves, stems, roots
	 totph   -	 supply
}
var
	dmtot : single;
begin
  with plant do
  begin
	sdlsr:=1.0;
	
	{ total S/D ratio }
	dmtot:=dmlsr;

	if(totph < dmtot)then
	begin
		resinc:=min(0.05*reserves,(dmtot-totph));
		totph:=totph+resinc;
		reserves:=reserves-resinc;
		if dmtot>0.0 then sdlsr := min(totph/dmtot,1.0);
	end;

  end;{casplant}
end; {casratios}
end.
