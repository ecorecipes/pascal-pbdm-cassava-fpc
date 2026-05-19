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

Procedure keyrespond(var ch:char);
var
	iohelp:boolean;
	xl,yt:integer;
{This is called if a key is pressed while model is running.}
begin
	iohelp:=false;
	if ch= #0 then
	begin
		ch:=readkey;
		if ch=#59 then iohelp:=true; {func1}
	end
	else ch:=upcase(ch);
{	iomode:1text,2plants,3Nit,4Water,5Tuber,6MB,7EL,8ED,9GM...}
	xl:=0;yt:=320;

	case ch of
	'T' : begin
			textmode(origmode);
			iomode:=1;
			GraphicMode:=false;
        	wshow:=false;
	        nshow:=false;
			tshow:=false;
			mbshow:=false;
			tx0:=false;
			tx1:=false;
			tx5:=false;
			tx6:=false;
			tx7:=false;
		end;
	'P' : begin
			if iomode<>2 then
			begin
				iomode:=2;
				setupgraph;
				showfield;
				newgraph:=true;
				showplants;
				iomenu(xl,yt,ch);
				GraphicMode:=true;
	        	wshow:=false;
		        nshow:=false;
				tshow:=false;
				mbshow:=false;
			end;
		end;
	'B' : begin	
			if iomode<>5 then
			begin
				for i:=1 to ncas do with casptr[deck[i]]^ do biomasscolr:=0;

				iomode:=5;
				setupgraph;
				showfield;
				newgraph:=true;
				showtubers;
				GraphicMode:=false;
    	    	wshow:=false;
	    	    nshow:=false;
				tshow:=true;
				mbshow:=false;
				iomenu(xl,yt,ch);
			end;
		  end;
	'N' : begin
			if iomode<>3 then
			begin
				iomode:=3;
				reseto2d(old2d);
				setupgraph;
				nshow:=true;
				showdist(narray,old2d,'N');
		        GraphicMode:=false;
    		    wshow:=false;
				GraphicMode:=false;
        		tshow:=false;
				mbshow:=false;
				iomenu(xl,yt,ch);
			end;
		end;
	'W' : begin
			if iomode<>4 then
			begin
				iomode:=4;
				reseto2d(old2d);
				setupgraph;
				showdist(layer[1].warray,old2d,'W');
				wshow:=true;
    		    GraphicMode:=false;
	        	nshow:=false;
			    tshow:=false;
			    mbshow:=false;
				iomenu(xl,yt,ch);
			end;
		end;
	'M' : begin
			if iomode<>6 then
			begin
				iomode:=6;
				setupgraph;
				showfield;
				newgraph:=true;
				showcmb;
				wshow:=false;
    		    GraphicMode:=false;
	        	nshow:=false;
			    tshow:=false;
			    mbshow:=true;
				iomenu(xl,yt,ch);
			end;
		end;
	'G' : begin
			if iomode<>9 then
			begin
				iomode:=9;
				setupgraph;
				showfield;
				newgraph:=true;
				showgm;
				wshow:=false;
    		    GraphicMode:=false;
	        	nshow:=false;
			    tshow:=false;
			    mbshow:=false;
				iomenu(xl,yt,ch);
			end;
		end;
	'E' : begin
			iomode:=7;
			writeln('E. lopezi numbers');
			writeln('soon');
		end;
	'C' : begin end;	{Continue}
	'Q' : begin
			modelday:=ndays;
			iyr:=nyears;
		end;
	'S' : begin {stop (pause, 'X' : resume)}
			repeat
				ch:=readkey;
				Keyrespond(ch);
			until ((ch='X')or(ch='Q'));
		end;
	'?','H' : iohelp:=true;
	end; {end case}
	if iohelp then
	begin
		xl:=0;yt:=320;
		iomenu(xl,yt,ch);
		keyrespond(ch);
	end;
end;


