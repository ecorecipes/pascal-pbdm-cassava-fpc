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

Unit modutils;
(*
Procedures and Functions used in all models programs.
*)
interface
uses globals,sysutils;
type
	SINGLE100100 = array[1..100, 1..100] of single; //used for 2d delay
	i100         = array[1..100] of integer;

Var
	ok:boolean;

Function Asin(Arg:single) : single;
Procedure Caland(year,Jday:integer; var MONTH,NDAY:byte; var ok:boolean);
Function Celsius(fahr:single):single;
Function damage(LarvaPerBoll:single; itype:integer):single;
Procedure Daydegrees(iday:integer; base:single; var dda,ddb:single);
Procedure Datetime;
Function Daylength (latitudeRadians: single; Jday: integer): single;
FUNCTION DAYLIT(JULDAY:integer; LatitudeDegrees:single):single; //benno's rice

Procedure DelayExEarly(vin		: single;
			var exearly: single;     {early exit from interior cell}
			var Vout 	: single;     {flow out from last cell}
			var R    	: single100;  {R array}
			del      	: single;     {Mean time through R}
			dt       	: single;     {Amount of time to process}
			k        	: integer;	  {number of substages in R}
			kearly		: integer);	  {early exit cell}

Procedure DelayNoPlr(viN: single;     {input increment}
		var Vout : single;             {flow out}
		var r    : array of single;  	{open-array r array}
		del      : single;     			{Mean time through r}
		DT       : single;     			{Amount of time to process}
		k        : integer); 			{number of substages in r}

Procedure DelayWithPlr(viN: single;    {input increment}
		var Vout,           			{flow out}
		Shed     : single;    			{attrition from array}
		var r    : single100; 			{r array}
		Plr      : single100; 			{Attrition array}
		del      : single;    			{Mean time through r}
		DT       : single;    	 		{Amount of time to process}
		k        : integer); 			{number of substages in r}

Procedure Delay2d(incol1,inrow1       : single100;   {input increments}
		var outcolvector : single100;   {flow out}
		var outrowvector : single100;   {flow out }
		var	r2d 		: single100100; {the 2d array}
		ddpara      	: single;     	{parasite dd today}
		delparasite     : single;		{Mean time for parasites}
		kparasite		: integer;		{number of substages for parasite}
		ddhost      	: single;     	{fruit dd today}
		delhost     	: single;		{Mean time for fruit ageing}
		khost		  	: integer);		{number of substages for fruit}

Procedure delayTV(viN      	: single;     {input increment}
                 var Vout 	: single;   {flow out}
                 var r    	: single100;
                 del      	: single;   {Mean time through r, given current conditions (today's del)}
		 var delp 			: single;   {previous deltat's del}
                 DT       	: single;   {Amount of time to process}
                 k        	: integer); {number of substages in r}

Function dot(var a,b : single100; { [1..N] OF single, N<=k }
   	             n   : integer) : single;
Function Expo(arg:single):single;
Function Fahr(celsius:single):single;
Function FFDD(T,Tpeak: real):real;
Function FFTemperature(T,Tlow,THigh: single):single;
Function Fran(var rvar:single;percentpm:integer):single;
Procedure Fill(var a:single100; k:integer; v:single);
Procedure Getdailywx;
Procedure GISirngck(ivar,ilO,iHi:integer; Str:string);
Procedure GISrngchk(v,rlo,rhi:single; Str:string);
Procedure Holdit;
Procedure irngck(ivar,ilO,iHi:integer; Str:string);
Function  Julian(Month,day,Year:integer):integer;
Function  log10(x:single) : single;
Function  NonZero(a:single100; k:integer) : Boolean;
Function  Power(base,exponent : single): single;
Function  rdate(Year,day:integer):single;
	
Procedure ReportError(errormessage:string);
Function max(r1,r2:single):single;
Function min(r1,r2:single):single;
Function maxint(i1,i2:integer):integer;
Function minint(i1,i2:integer):integer;
Function maxw(w1,w2:word):word;
Function minw(w1,w2:word):word;
Function RandNorm(mean,stdev:single):single;

Procedure rngchk(v,rlo,rhi:single; Str:string);
Function runav(v : single; var r:single100; var i:integer; n:integer):single;
Procedure Shufl(var deck:i100;n:integer);
Function SingleDot(A: array of single;B:array of single; n:integer):single;
Function SingleSum(A: array of single; m,n:word):single;
Function Sum(var a   : single100;
                 m,n : integer                    ) : single;
Function Sum2dcolumn(r2d:single100100;kol,k:integer) : single;
Function Sum2drow(r2d:single100100;jrow,k:integer) : single;
Function SumReal(A: array of real; m,n:word):real;
{Procedure Setprn(iprn,ifun:integer);}
Procedure wdwvec(     Xl:single;      {left edge of window}
   	                  xr:single;      {right edge of window}
       	              k :integer;     {k substages in array}
           	          del:single;     {total range covered by array}
               	  var v:single100);   {array}
Procedure Xrdate(wd:single;j,year:integer;var month,nday:byte);

Function Zerone(x:single):single;
implementation

Function Asin(Arg:single) : single;
{
Returns inverse Sine Function in radians.
after Programs for Scientists and Engineers, Alan r. Miller
(Used in daydegree Procedure.)
}
begin
     if (arg<-1.0) or (arg>1.0)then
     begin
	ReportError(' Asin Function argument out of range.');
          halt(1);
     end;
     if arg = 0.0 then Asin:=0.0
     else
     if arg = 1.0 then Asin:=pi/2.0
     else
     if arg = -1.0 then Asin:= -pi/2.0
     else
        Asin := arctan(arg/sqrt(1.0-sqr(arg)));
end; {Asin}


Procedure Caland(year,Jday:integer; var Month,Nday:byte; var ok:boolean);
{
Given inputs of year and julian day return corresponding Month and day.
}
var i:integer;
const
	days : array[1..13] of integer = (0,31,59,90,120,151,181,212,243,273,304,334,365);
	ldays: array[1..13] of integer = (0,31,60,91,121,152,182,213,244,274,305,335,366);
begin
	ok:=true;
	if (year mod 4)=0 then
	begin {leapyear}
		iF(Jday < 1) or (Jday > 366)then Ok:=False
		else
		begin
			i:=1;
			repeat
				i:=i+1;
			until ldays[i] >= Jday;
			Month:=i-1;
			Nday:=Jday-ldays[Month];
		end;
	end {leapyear}
	else
	begin
		iF(Jday < 1) or (Jday > 365)then Ok:=False
		else
		begin
			i:=1;
			repeat
				i:=i+1;
			until days[i]>=Jday;
			Month:=i-1;
			Nday:=Jday-days[Month];
		end;
	end;
end; {caland}

Function Celsius(fahr:single):single;
begin
	Celsius:=(fahr-32.0)*0.55556;
end;

Function damage(LarvaPerBoll:single; itype:integer):single;
{
Estimate damage to cotton yield and quality by PBW and BW as a Function of larva per boll.
(LarvaPerBoll originally was called zeta.)
}
begin
		damage:=1.0;
		if(LarvaPerBoll>0.0)then
		case itype of
			1: damage:=zerone(1.-0.05 * LarvaPerBoll); {PBW-survivorship of yield}
	{8/3/05}2: damage:=(1.145-0.006*expo(3.185+0.115*LarvaPerBoll)); {PBW-survivorship of yield & quality}
			3: damage:=zerone(1.0 - 0.06105599 * LarvaPerBoll);  {PBW -survivorship of lint}
			4: damage:=zerone(1.0 - 0.08407368 * LarvaPerBoll); {PBWsurvivorship of seed }
		end;
end;

Procedure Daydegrees(iday:integer; base:single; var dda,ddb:single);
{
 Compute day degrees above and below a base temp for one day.
 Assume a sine curve of temperature through max and min Temps.

 Temps - Array with daily max and min Temps.
 DDA - Day degrees above Base
 DDB - Day degrees below Base
 Base - Base or threshold temperature
 Tmax - Today's max
 Tmin - Today's min
 Tmean - Today's mean
 TmaxPr - Yesterday's max
 Pi4 - Constant representing 1./4.*Pi
}

var idm,i:integer;
    TmaxPr,TX,Trange:single;
    Y,Y8,C,Alpha:single;
    ok:boolean;
{ Tmax,Tmin,Tmean,Temps[..,..],i are declared in Globals.inc}
Const
	Pi4 = 0.079577472;

begin
   DDA:=0;
   DDB:=0;
   Tmax:=  Temps[iday,1];	//	*(0.9+random*(0.2));
   Tmin:=  Temps[iday,2];	//	*(0.9+random*(0.2));
   idm:=iday-1;
   iF (idm<1) then idm:=1;
   TmaxPr:=Temps[idm,1];
   TX:= TmaxPr;

   for i:=1 to 2 do
   begin
		ok:=true;
      iF i=2 then TX:=Tmax;
      Trange:=Tmin-TX;
      iF (Trange>=0.0) then Trange:=-0.001;
      Y:=(TX+Tmin)-(2*Base);
      iF (Tmin>=Base) then
      begin
         DDA:=DDA+Y*0.25;
         Ok:=False;
      end;
      iF (TX<=Base) then
      begin
         DDB:=DDB-Y*0.25;
         Ok:=False;
      end;
      iF Ok then
      begin
         Alpha:=Asin(Y/(Trange));
         C:=Pi4*((TX-Tmin)*Cos(Alpha)-Y*Alpha);
         Y8:=0.125*Y;
         DDA:=DDA+C+Y8;
         DDB:=DDB+C-Y8;
      end;  {if Ok }
   end;    {for i:=1 to 2}

end;  {Daydegrees }

FUNCTION DAYLIT(JULDAY:integer; LatitudeDegrees:single):single; //benno Graf rice model
//	******************************
//	This subroutine calculates the hours of daylight for a given date
//	and latitude.
//	Compute the declination
var
	kdaysn:integer;
	ralat,decl,sunriz,twilit:single;
begin
      KDAYSN:=JULDAY-81;
      IF(JULDAY<81)then KDAYSN:=365+KDAYSN;
      DECL:=0.4064*SIN(6.2832*KDAYSN/365.0);

//	Compute the photoperiod
      RALAT  := LatitudeDegrees*3.1416/180.0;
      TWILIT:=-0.833333*3.1416/180.0;
      SUNRIZ:=(SIN(TWILIT)-SIN(RALAT)*SIN(DECL))/(COS(RALAT)*COS(DECL));
      SUNRIZ:=(1.5707963268-ASIN(SUNRIZ))/0.0174533;
      DAYLIT:=(SUNRIZ/15.0)*2.0;
END;

Procedure Datetime;
{ Write system date and time to output.}
//commented out for gis runs.
begin
(*
	Writeln('Date: ' + DateToStr(Date));
	Writeln('Time: ' + TimeToStr(Time));
*)
end;

Function Atan(x,y:single):single;
{Arctan in degrees}
const pi180 = 57.2957795;
var a:real;
begin
	if x=0.0 then
	  if y=0.0 then Atan:=0.0
	  else Atan:=90.0
	else {x<>0}
	  if y=0.0 then Atan :=0.0
	  else {x and y <>0}
	    begin
	      a:=arctan(abs(y/x))*pi180;
	      if x>0.0 then
		if y>0.0 then Atan :=a {x,y>0}
		  else Atan:=-a {x>0,y<0}
	      else {x<0}
	        if y>0.0 then Atan:=180.0-a {x<0, y>0}
	        else Atan := 180.0+a; {x,y <0}
	    end; {else begin}
end; {Function Atan}

Function Arccos(x:single):single;
{Arccosine in degrees}
begin
	if x=0.0 then Arccos:=90.0
	else
	  if x=1.0 then Arccos:=0.0
	  else
	    if x= -1.0 then Arccos:=180.0
	    else Arccos := Atan(x/sqrt(1.0-sqr(x)),1.0)
end;

Function Daylength (LatitudeRadians: single; Jday: integer): single;
{
Calculate Daylength in hours, after the Function of 
Penning de Vries and van Laar. 
*** serious error in this calculation -- USE Beno's daylit function instead
}
VAR
   delta,inter,beta,gamma: real;

begin
	{PI:= 3.1415;}
   gamma:= LatitudeRadians * (PI / 180.0);
   beta := -0.833 * (PI / 180.0);
   delta:= -23.4 * Cos (2.0 * PI * (Jday + 10.0) / 365.0) * (PI / 180.0);
   inter:= (Sin (beta) - Sin (gamma) * Sin (delta)) / (Cos (gamma) * Cos(delta));
   Daylength:= (24.0 / PI * Arccos (inter))/60.0;

//d:= (24.0 / PI * Arccos (inter))/60.0;
//writeln('lat,day:',latituderadians:9:3,Jday:4);
//writeln('P de V  dayl=', Daylength:9:3); readln;
END;


Procedure Delay0(Vin      : single;     {input increment (comes in as number)}
                 var Vout : single;     {flow out (out as a rate)}
                 var R    : single100;  {R array}
                 DEL      : single;     {Mean time through R}
                 DT       : single;     {Amount of time to process}
                 K        : integer); {number of substages in R}
(*
 Use this version when the entire day's dd is processed in one call
 and there is no attrition.
 *)
var
	j,i,idt: integer;
        a,Dtkdel: single;
begin
	Vout := 0.0;
        if dt>0.0 then
        begin
			Vin:=Vin/dt;
        	dtkdel:=dt*k/del;
        	IDT := trunc(1.+(2.*Dtkdel));
	        A := Dtkdel / IDT;   { A = flow rate from one substage to next }
 
			for j := 1 to idt do
			begin
				Vout := Vout + A*R[K];
				for i := K downto 2 do
					r[i] := r[i] + A*(r[I-1]-r[i]);
				R[1] := R[1] + A*(Vin- R[1]);
            end;  {For j}
        end; {If dt>0.0}
end; { Procedure Delay0}


Procedure DelayNoPlr(Vin  : single;     {input increment}
                 var Vout : single;     {flow out}
                 var r    : array of single;  {open-array r array}
                 del      : single;     {Mean time through r}
                 DT       : single;     {Amount of time to process}
                 k        : integer);   {number of substages in r}
(*
 Use this version when the entire day's dd is processed in one call
 and there is no attrition.
 Array r is an open array so it's first cell is number 0. Change loops so
 indexing goes from 0 to k-1.
*)
var
	idt,i,j : integer;
        a : single;
	km:word; 
begin
	km:=k-1;

	Vout := 0.0;
        if dt>0.0 then
        begin
        	idt := trunc(1.+(2.0*DT*(k/del)));
	        A := (DT / (del/k)) / iDT;   { A = flow rate from one substage to next }
 
			for j := 1 to idt do
			begin
				Vout := Vout + A*r[km];
				for i := km downto 1 do
					r[i] := r[i] + A*(r[i-1]-r[i]);
				r[0] := r[0] + A*((Vin/Dt)- r[0]);
   		         end;  {for j}
        end; {if dt>0.0}
end; { Procedure DelayNoPlr}


Procedure delay2d(incol1,inrow1: single100;   {input increments}
				var outcolvector : single100;   {flow out}
				var outrowvector : single100;   {flow out }
				var	r2d    	: single100100; {the 2d array}
				ddpara      : single;     {parasite dd today}
				delparasite : single;		{Mean time for parasites}
				kparasite	: integer;	{number of substages for parasite}
				ddhost      : single;     {fruit dd today}
				delhost     : single;		{Mean time for fruit ageing}
				khost		: integer);	{number of substages for fruit}
(*
 2d delay - for parasitoids growing inside hosts.
 They move across rows as they age, they move across columns as the
 hosts age.  When they move out of the last row (>age max of parasite stage)
 they become adults and join the adult pool outside.
 Oviposit inputs are through the input array inRow1. Which column of ovip
 input is determined by the age preference of the parasite for host. 
 outrowvector will have all old parasites ageing out.
 outcolvector will represent the oldest host age. 
 *)

var
	i,j,kol,krow,iddpara,iddhost : integer;
	a : single;
begin
	for i:=1 to kparasite do outcolvector[i]:=0.0;
	for i:=1 to khost do outrowvector[i]:=0.0;
	if ddpara>0.0 then
	begin
		{Age paras 'downward' in each column: each column is treated as
		 a separate R array to delay.}
		iddpara := trunc(1.+(2.*ddpara*(kparasite/delparasite)));
		a := (ddpara / (delparasite/kparasite)) / iddpara;   { a = flow rate from one substage to next }
		for kol:=1 to khost do
		begin
			for j := 1 to iddpara do
			begin
				outrowvector[kol] := outrowvector[kol] + a*r2d[kparasite,kol];
				for i := kparasite downto 2 do
					r2d[i,kol] := r2d[i,kol] + a*(r2d[i-1,kol]-r2d[i,kol]);
				{inputs into row 1 of r2d}
				r2d[1,kol] := r2d[1,kol] +
					a*((inrow1[kol]/ddpara)- r2d[1,kol]);
		    end;
		end;
	end; {if ddpara>0.0}

	if ddhost>0.0 then
	begin
		{Age hosts 'left to right' in each row: each row is treated as
		 a separate R array to delay.}
		iddhost := trunc(1.+(2.*ddhost*(khost/delhost)));
		a := (ddhost / (delhost/khost)) / iddhost;  
		for krow:=1 to kparasite do
		begin
			for j := 1 to iddhost do
			begin
				outcolvector[krow] := outcolvector[krow] + a*r2d[krow,khost];
				for i := khost downto 2 do
				begin
					r2d[krow,i] := r2d[krow,i] + a*(r2d[krow,i-1]-r2d[krow,i]);
					if r2d[krow,i]<0.0 then r2d[krow,i]:=0.0;
				end;	
				{possible inputs into col 1 of r2d (not in def/para system)}
				r2d[krow,1] := r2d[krow,1] + a*((incol1[krow]/ddhost)- r2d[krow,1]);
			end;
		end;
	end; {If ddhost>0.0}
end; { Procedure delay2d}


Function log10(x:single):single;
{Common log of x}
{x must be positive}
begin
	log10:=0.0;
	if x>0.0 then log10:=ln(x)/ln(10.0)

end;


Function NonZero(a:single100; k:integer) : Boolean;
{ NonZero is true if any element of array A is NonZero.}
var i:integer;
begin
	i:=1;
	while (i<k+1) and (a[i]=0.0) do inc(i);
	NonZero := (i<k+1);
end;

Procedure DelayExEarly(Vin		: single;
			var ExEarly: single;     {early exit from interior cell}
			var Vout 	: single;    {flow out from last cell}
			var R    	: single100; {R array}
			del      	: single;    {Mean time through R}
			dt       	: single;    {Amount of time to process}
			k        	: integer;	 {number of substages in R}
			kearly		: integer);	 {early exit cell}
{
 Standard delay except values transiting between cells kearly and kearly+1 are
 intercepted and returned as variable ExEarly  (exit early).
}
var
	i,j,idt : integer;
        a : single;
begin
	ExEarly:=0.0;
	Vout := 0.0;
	if dt>0.0 then
	begin
		idt := trunc(1.+(2.*dt*(k/del)));
		A := (dt / (del/k)) / idt;   { A = flow rate from one substage to next }

		for j := 1 to idt do
		begin
			Vout := Vout + A*R[k];
			ExEarly := ExEarly + a*r[kearly];
			for i := k downto 2 do
				if i<>(kearly+1) then r[i] := r[i] + A*(r[i-1]-r[i])
				else r[i] := r[i] + A*(0.0-r[i]);
			R[1] := R[1] + A*((Vin/dt)- R[1]);
		end;  {For j}
	end; {If dt>0.0}
end; { Procedure delayExEarly}


Procedure DelayWithPlr(Vin      : single;    {input increment}  {Formerly called Del2.  08/23/2002}
               var Vout,           {flow out}
               Shed     : single;    {attrition from array}
               var r    : single100; {r array}
               Plr      : single100; {Attrition array}
               del      : single;    {Mean time through r}
               DT       : single;   {Amount of time to process}
               k        : integer); {number of substages in r}
var
	idt 	: integer;
	i,j		: byte;
    a,shd 	: single;
begin
	Shed := 0.0;
	Vout := 0.0;
        if dt>0.0 then
        begin
  		Vin:=Vin/dt;
  	    	iDT := trunc(1.+(2.*DT*(k/del)));
	        A := (DT / (del/k)) / iDT;   { A = flow rate from one substage to next }

		iF(NonZero(Plr,k))then
                {Plr is NonZero = attrition is done here}
                for J := 1 to idt do
                begin
	    		Vout := Vout + A*r[k];
        		for i := k downto 2 do
			begin
				r[i] := r[i] + A*(r[i-1]-r[i]);
				shd := a*plr[i]*r[i];
				Shed := Shed+shd;
				r[i] := r[i]-shd;
			end;
                	iF(J = 1)then r[1] := r[1]+A*(Vin*iDT-r[1])
		         else r[1] := r[1] - A* r[1];
	                shd := a*plr[1]*r[1];
        	        Shed := Shed+shd;
                	r[1] := r[1]-shd;
		end  {for J}
		else
                {Plr is zero = no attrition is done }
		for j := 1 to idt do
		begin
			Vout := Vout + A*r[k];
			for i := k downto 2 do
				r[i] := r[i] + A*(r[i-1]-r[i]);
			r[1] := r[1] + A*(Vin- r[1]);
		end;  {for j}
	end; {if dt>0.0}
end; { Procedure DelayWithPlr}

Procedure DelayTV(Vin      : single;     {input increment}
                 var Vout : single;     {flow out}
                 var r    :single100;
                 del      : single;     {Mean time through r, given current conditions (today's del)}
		 var delp : single;     {previous deltat's del}
                 DT       : single;     {Amount of time to process}
                 k        : integer); {number of substages in r}
(*
 Time varying delay.  
 Use this version when the entire day's dd is processed in one call
 and there is no attrition.
 *)
var
	idt,i,j : integer;
        a : single;
	deld:single;
begin
	Vout := 0.0;

        if dt>0.0 then
        begin
        	iDT:= trunc(1.+(2.*DT*(k/del)));
	        A:= ((DT*k)/ del) / iDT;   { A = flow rate from one substage to next }
 		deld:=(del-delp)/((dt*k)+delp/k);
		for j := 1 to idt do
		begin
			Vout := Vout + A*r[k];
			for i := k downto 2 do
				r[i] := r[i] + A*(r[i-1]-r[i])*(1.0+deld);
			r[1] := r[1] + A*((Vin/Dt)- r[1])*(1.0+deld);
  	         end;  {for j}
        end; {if dt>0.0}
	delp:=del;
end;

Function Dot(var a,b : single100; { [1..N] OF single, N<=k } n   : integer) : single;
(*
Dot Product of 2 arrays:
 Sum the products of corresponding entries of 2 arrays.
*)
var X:single;
    i:integer;
begin
     X:=0.;
     for i := 1 to n do  x:= x + a[i]*b[i];
     Dot := x;
end; 


Function Expo(arg:single):single;
{limit argument to exp Function. 14mar90}
//Limits tested again 10/03/06 using Pentium(R) 4.
//No limit on neg arg.  Slightly higher on pos arg.
var a:single;
begin
     a:=arg;
     if a>88.6 then a:=88.6;
     expo:=exp(a);
end;

Function Fahr(celsius:single):single;
begin
	fahr:=9.0*celsius/5.0 +32.0;
end;

Function FFDD(T,Tpeak: real):real;
{
 Returns a value between 0 and 1 from a Function shaped like a symmetrical hump (parabola)
 with the peak at x=Tpeak, tails  at x=0, x=Tpeak*2.
 If tpeak=0.0 returns 0.0;
 }
begin
	if Tpeak=0.0 then FFDD:=0.0 else
	FFDD:=max(0.0, 1.0-sqr((T-Tpeak)/Tpeak));
end;

Function FFTemperature(T,Tlow,THigh: single):single;
{
 Returns a value between 0 and 1 from a Function shaped like a symmetrical hump (parabola)
 with the maximum at the midrange of Tlow and THigh.  The Function is 0 at Tlow and THigh.
}
var
	A:single; //half the difference between Tlow and THigh
begin
	A:=(THigh-Tlow)/2.0;
	if((T<=Tlow)or(t>=THigh))  then FFTemperature:=0.0 else
	FFTemperature:=max(0.0, 1.0-sqr(   (T-Tlow-A)/A) );	//  9/18/06
end;

Function Fran(var rvar:single;percentpm:integer):single;
{Return as random value between rvar-percentpm and rvar+percentpm.}
var
	pcnt:single;
begin
	pcnt:=percentpm/100.0;
	fran:=	rvar*((1.0-pcnt) + 2*random*pcnt);
end;

Procedure Fill(var a:single100; k:integer; v:single);
//Fill cells 1 to k of a single100 array with the value v.
var i:integer;
begin
	for i:= 1 to k do a[i]:=v;
end;

Procedure GetDailyWx;
var
	idn:integer;
	Tmin2:real;
begin
	solrad:=solar[modelday];
	precip:=rain[modelday];
	rhmean:=relhum[modelday];
	wind:=winds[modelday];

//Compute Tmean using today's min, today's max and tomorrow's min.
	iDn:=modelday+1;
	iF (iDn>Ndays) then iDn:=Ndays;
	Tmin2:=Temps[iDn,2];
	Tmean:=(Tmin+Tmin2)/2.0;
	Tmean:=(Tmean+Tmax)/2.0;
//Compute Tmean using today's min, today's max  //3/13/07
	Tmean:=(TmIn+Tmax)/2.0;

end;

Procedure Holdit;
//Suspend console output until user presses Enter.
begin
	write('To continue press Enter. ');
	readln;
end;


Procedure GISirngck(ivar,ilO,iHi:integer; Str:string);
{ Check valid range  of  integer variable }
begin
	iF(ivar<ilo) or (ivar>ihi)then begin
		reporterror('Input integer out of range');
		runok:=False;
		exit;
	end;
end;

Procedure GISrngchk(v,rlo,rhi:single; Str:string);
{ Check valid range  of single variable }
begin
	iF(v<rlo) or (v>rhi)then begin
		reporterror('Input real or single variable out of range');
		runok:=False;
		exit;
	end;
end;

Procedure irngck(ivar,ilo,ihi:integer; Str:string);
{ Check valid range  of  integer variable }
begin
	iF(ivar<ilo) or (ivar>ihi)then begin
		Writeln(str);
		writeln(' Has value ',ivar);
		writeln(' valid range is between ',ilo,' and ',ihi);
		halt(1);
	end;
end;

Function Julian(Month,day,Year:integer):integer;
{Return the Julian date for day, Month, year arguments.
 There are some range checks on args.  if one is out of range a message
 is written and the value of the Function is zero.}

Const
	iNCr   : array[1..12] of integer=(0,31,59,90,120,151,181,212,243,273,304,334);
	lNCr   : array[1..12] of integer=(0,31,60,91,121,152,182,213,244,274,305,335);

{changed 6/2009 by APG to accomodate Delphi6}
{	MrANGE : array[1..12] of integer=(31,28,31,30,31,30,31,31,30,31,30,31);}
var
	x,xx:single;
	vs:string;
	MrANGE : array[1..12] of integer;
begin
	Julian:=0;
{changed 6/2009 by APG to accomodate Delphi6}
MrANGE [1]:=31;
MrANGE [2]:=28;
MrANGE [3]:=31;
MrANGE [4]:=30;
MrANGE [5]:=31;
MrANGE [6]:=30;
MrANGE [7]:=31;
MrANGE [8]:=31;
MrANGE [9]:=30;
MrANGE [10]:=31;
MrANGE [11]:=30;
MrANGE [12]:=31;

	iF(Year<0) or (Year>10000)then	
	begin
		str(year:8,vs);	
		reporterror(' Invalid year in Julian Function: '+vs);
{		Writeln(' invalid year ',Year);}
		Exit;
	end;
	iF not (Month in [1..12]) then
	begin
		str(Month:8,vs);	
		reporterror(' Invalid Month in Julian Function: '+vs);

		Exit;
	end;
{	if (year MOD 4)= 0 then Mrange[2]:= 29 else Mrange[2]:= 28;}
{changed 6/2009 by APG to accomodate Delphi6}
	xx:= year MOD 4;
	if xx = 0 then Mrange[2]:= 29 else Mrange[2]:= 28;
{ writeln('xx=',xx:8:3); readln;}

	if not (Day in [1..Mrange[Month]] )then
	begin
		str(day:8,vs);	
		reporterror(' Invalid day in Julian Function: '+vs);
{		Writeln(' invalid day value ',Day);}
		exit;
	end;
	x := int(30.57 * Month) +day-30;
	if Month>2 then if int(year/4)=year/4 then x:=x-1 else x:=x-2;
	Julian:=trunc(x);
end; { Julian }

Function Power(Base,exponent : single): single;
(* exponentiation : power := Base**exponent *)
begin
     if Base=0.0 then power:=0.0 else
     Power:=expo(exponent * ln(Base));
end; {Power}


Function RandNorm(mean,stdev:single):single;
{Produce random numbers with a Normal (Gaussian) distribution.}
{Mean and standard deviation (sigma) are args.}
{Uses uniform distribution rand Function in turbo.}
{From Turbo Pascal for Scientists and Engineers. p26}
var
	i:byte;
	sum:single;
begin
	sum:=0.0;
	for i:=1 to 12 do sum:=sum+random;
	randnorm:=(sum-6.0)*stdev+mean;
end;

Function rdate(Year,day:integer):single;
{ 
Return date in 'linear form' used by Excel (nr of days since 01/01/1900).
Day is julian day.
If year is yy assume 19yy.
The variable x1 must be of type real or greater precision.
}

var
	x1:real;
begin
	x1:=(365.25 * (Year mod 100)) + Day + 0.251;
	if year=2000 then x1:=(365.25 *  100) + Day + 0.251;
	if year>2000 then
	begin
		x1:=(365.25 * (Year mod 1000)) + Day + 0.251;
		x1:=x1+36525;
	end;
	rdate := round(x1);
//writeln('x1=',x1:9:0);
end;

Procedure ReportError(errormessage:string);
{Write error message to error log file - not to dos window.}
var
	NowTime: TDateTime; 
	id:string[20];
begin
	NowTime:=now;
	id:=location;
	writeln(errorlogfile,DateTimeToStr(NowTime),' ',id,' ',errormessage);
end;

Function max(r1,r2:single):single;
//Returns the max of 2 args.
begin
	if r2>r1 then max:=r2 else max:=r1;
end;

Function min(r1,r2:single):single;
//Returns the min of 2 args.
begin
	if r2<r1 then min:=r2 else min:=r1;
end;

Function maxint(i1,i2:integer):integer;
begin
	if i2>i1 then maxint:=i2 else maxint:=i1;
end;

Function minint(i1,i2:integer):integer;
begin
	if i2<i1 then minint:=i2 else minint:=i1;
end;

Function maxw(w1,w2:word):word;
begin
	if w2>w1 then maxw:=w2 else maxw:=w1;
end;

Function minw(w1,w2:word):word;
begin
	if w2<w1 then minw:=w2 else minw:=w1;
end;

Procedure rngchk(v,rlo,rhi:single; Str:string);
{ Check valid range  of single variable }
begin
	iF(v<rlo) or (v>rhi)then begin
		Writeln(str);
		writeln(' Has value ',v);
		writeln(' valid range is between ',rlo,' and ',rhi);
		halt(1);
	end;
end;

Function runav(v : single; var r:single100; var i: integer; n:integer):single;
{
	Do running average of most recent n values of v.
	Array r holds up to n values.
	I is most recent index into r.
}
begin
	if i>n then i:=1;
	r[i]:=v;
	runav:=sum(r,1,n) / n;
end;

Procedure Shufl(var deck:i100;n:integer);
(*
	Deck is an array of integers of length 100.
	n is the number of cells to deal with.
	Return array Deck with the first N cells containing integers from
	1 to n shuffled.
*)
var
	i,j:integer;
	hit:boolean;
	bool:array[1..100]of boolean;
begin
	for i:=1 to n do bool[i]:=False;
	for i:=1 to n do deck[i]:=0;

	for i:=1 to n do
	begin
		j:=trunc(n*random)+1;
		hit:=False;
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

Function SingleDot(A: array of single;B:array of single; n:integer):single;
(*
 Dot product of 2 single arrays.
 Sum the products of corresponding entries of 2 arrays 
*)
var X:single;
    i:integer;
begin
     X:=0.0;
    for i := 0 to n-1 do
	begin
	  x:= x + a[i]*b[i];
	end;

     SingleDot := x;
end; 

Function SingleSum(A: array of single; m,n:word):single;
(*
Sum the entries of an array from index m to n.
A is an open-array parameter so m and n are decremented by 1.
*)
var
	i:integer;
	s:single;
begin
	s:=0.0;
	for i:=m-1 to n-1 do s:=s+a[i];
	SingleSum:=s;
end;

Function SumReal(A: array of real; m,n:word):real;
(*
Sum the entries of an array from index m to n.
A is an open-array parameter so m and n are decremented by 1.
*)
var
	i:integer;
	s:real;
begin
	s:=0.0;
	for i:=m-1 to n-1 do s:=s+a[i];
	SumReal:=s;
end;

Function Sum(var a   : single100;
                 m,n : integer                    ) : single;
(*
 Sum the entries of an array.
 m and n must be <= constant k.
*)
var i : word;
	Temp : single;
begin
   temp:=0.;
   for i := m to n do temp:= temp + a[i];
   Sum:=temp;
end; {Function Sum}
	
Function Sum2dcolumn(r2d:single100100;kol,k:integer) : single;
(*
 Sum the entries of column kol of a 2d array.
*)
var
	i:integer;
	sum2d:single;
begin
	Sum2d:=0.0;
	for i:=1 to k do Sum2d:=Sum2d+r2d[i,kol];
	Sum2dColumn:=Sum2d;
end;

Function Sum2drow(r2d:single100100;jrow,k:integer) : single;
(*
 Sum the entries of row 'jrow' of a 2d array.
*)
var
	i:integer;
	sum2d:single;
begin
	Sum2d:=0.0;
	for i:=1 to k do Sum2d:=Sum2d+r2d[jrow,i];
	Sum2drow:=Sum2d;
end;

Procedure Wdwvec(     xl:single;      {left edge of window}
                      xr:single;      {right edge of window}
                      k :integer;   {k substages in array}
                      del:single;     {total range covered by array}
                  var  v:single100);  {array}
(*
Window vector is our name for the array created here in the argument v.
All cells will be zero except for those between the cells representing xl (left edge) and xr (right edge).
The cells between xl and xr are set to 1.0.  This non-zero span is the 'window'.
This v array is used in many places in our models to select cells in the window in other arrays.
One of these arrays may represent age of an organism.  The max age would be the argument 'del'.
Each cell would represent 1/k * del.
The edges (xl,xr) are real numbers so they might represent a value that falls within the range of a single
cell.  In this case the edge cell of the window is assigned a value between 0 and 1.
cke 10/26/06
*)

var delkloc,xrloc,xlr,xrl,fracl,fracr:single;
var kl,kr,i:integer;

begin
	if xl>xr then
	begin
		reporterror(' Invalid arguments to wdwvec.');
	end;
	delkloc:=del/k;
	iF(xr <= del)then xrloc := xr else xrloc := del;
	kl:=trunc(xl/delkloc) + 1;
	iF(kl>k)then kl:=k;
	kr:=trunc(xrloc/delkloc)+1;
	iF(kr>k)then kr:=k;
	iF(kl=kr)then
	begin {all in one bin}
		Fill(v,k,0.0);
		v[kl]:=(xrloc-xl)/delkloc;
	end
	else
	begin
		xlr:=kl*delkloc; {value at right edge of left bin}
		xrl:=(kr-1)*delkloc; {value at left edge of right bin}
		fracl:=(xlr-xl)/delkloc;
		fracr:=(xrloc-xrl)/delkloc;
		for i:=1 to k do
	        	iF(i=kl)              then  v[i]:=fracl else
	       		iF((kl<i) and (i<kr)) then  v[i]:=1.0   else
	        	iF(i=kr)              then  v[i]:=fracr else
	                                  	    v[i]:=0.0;
	end;
end; {Procedure wdwvec}

Procedure Xrdate(wd:single;j,year:integer;var Month,Nday:byte);
{ Extract date from RDATE format} {Is there a Y2K version?}
var
	r:single;
begin
	r:=wd;
	year:=trunc(r/365.25);
	j:= trunc(r -(year*365.25));
	caland(year,j,Month,Nday,ok);
end;

Function Zerone(x:single):single;
{	Function Zerone(X)
 Scissor to 0 <= X <= 1
}
begin
	if x<0 then zerone:=0.0 else
	if x<1.0 then zerone:=x else
	zerone:=1.0;
end;
end.

