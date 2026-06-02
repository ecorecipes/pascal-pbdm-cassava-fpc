Unit setupcas;
interface
uses globals,Modutils,rng;
Procedure setupcasxy;

implementation
Procedure setupcasxy;
var
	xmeters,ymeters,rowdx:single;
	i,xdots,ylines:integer;
	nplantinrow: integer;

begin
{
	Choose xy pairs for all 100 locations even though <100 plants
	may be present.
	Create a matrix of xy pairs representing locations of plant
	centers of 100 plants.  They will be stored in Casloc which is an
	array of 100 locrec records.  Each record has an xy pair and a boolean
	variable 'aplant' indicating if a plant is here or not.
	X and y are determined by rowspacing and plantspacing and can be
	perturbed randomly to a degree set by the input variables Pspacedist
	and Rspacedist (plant and row spacing variation distributions).

	rowspacing = m between rows.  Read from setup file.
	plantspacing = m between plants.  Read from setup file.
	The graphic output is of a 10mx10m sample of the field.
	This is a rectangle 460x460 lines on screen.
}
	xmeters:=10.0;
	ymeters:=10.0;
	xdots:=460;
	ylines:=460;
	ylinespermeter:= round(ylines/ymeters); {46}
	xdotspermeter:= round(xdots/xmeters); {46}
	{allow margins of plantspacing/2 }
	plantsperrow:=round((xmeters-plantspacing)/plantspacing+1);
	
	left:=179;
	right:=left+460;
	top:=0;
	bottom:=460;
	{x,y locations for each cas plant}
	nplantinrow:=0;
	nrows:=0;
	for i:=1 to 100 do with casloc[i] do begin x:=0.0; y:=0.0; end;

	for i:=1 to 100 do
	begin
		with casloc[i] do 
		begin
			{set x locations within row  (spacing=~1.5 = 1.4 to 1.6).}
			{nplantinrow counts which plant in row this one is.}
			{first plant is spaced 1/2 normal spacing   to center on screen.}
			inc(nplantinrow);
			if(nplantinrow>plantsperrow)then nplantinrow:=1;
			x:=plantspacing*(nplantinrow-0.5)+
			 pspacedist*plantspacing*(random*2.0-1.0);
			
			{set  rowddx every plantsperrow plants  (0.8 to 0.9)}
			if (i mod plantsperrow)=1 then 
			begin
				inc(nrows);
				rowdx:=rowspacing*(nrows-0.5)+
				rspacedist*rowspacing*(random*2.0-1.0);
			end;

			{allow slight y variation of each plant}
			y := rowdx  + pspacedist*(random*1.0-0.5);

			{keep the plant centers within the displaying field:}
			if y<0.0 then y:=0.0;
			if y>10.0 then y:=10.0;
			if x<0.0 then x:=0.0;
			if x>10.0 then x:=10.0;
		end; {casloc[i]}
	end;
end;
end.

