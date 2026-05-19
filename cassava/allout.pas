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

Procedure AllPlantsOut;
Var
	i:integer;
	CasPlant:plantrec;
	mb1,mb2,mb34,mb5,mb6,el1,el2,el3,ed1,ed2,ed3,hjE,hjL,hjA:single;
begin
	for i:=1 to ncas do if casloc[i].aplant then
	begin
		with mbptr[i]^ DO
		 BEGIN
			 mb1:=mbn[1];
			 mb2:=mbn[2];
			 mb34:=mbn[3]+mbn[4];
			 mb5:=mbn[5];
			 mb6:=mbn[6];
		end;


		with elptr[i]^ do begin el1:=elnum[1]; el2:=elnum[2]; el3:=elnum[3]; end;	
		with edptr[i]^ do begin ed1:=ednum[1]; ed2:=ednum[2]; ed3:=ednum[3]; end;	
		with hjptrs[i]^ do begin hje:=hjegnm; hjl:=hjlarn; hja:=hjadnm; end;
		CasPlant:=casptr[i]^;
		with CasPlant do
	 	begin
		  write(Allplantsfile,ModelDate:8:0,tb,jday,tb,i:3,tb,x:8:3,tb,y:8:3,tb,tdda:9:2,tb,totall+totals:9:3,tb,tuber:9:3,tb);
		  write(Allplantsfile,sumflin:8:3,tb,sdlsr:8:3,tb,branch:4,tb,nav(CasPlant),tb);

		  write(AllPlantsfile,mb1:8:3,tb,mb2:8:3,tb,mb34:8:3,tb,mb5:8:3,tb,mb6:8:3,tb,el1:8:3,tb,el2:8:3,tb,el3:8:3,tb);
		  writeln(AllPlantsfile,ed1:8:3,tb,ed2:8:3,tb,ed3:8:3,tb,hjE:8:3,tb,hjL:8:3,tb,hjA:8:3);
	  	end;
	end;
end;

	

{
		write(AllPlantsfile,'jday index x y dd lf+stem tuber sumflin sd*10 ');
		write(AllPlantsfile,'Branches soiln soilw ');
		writeln(AllPlantsfile,'mb1  mb2  mb34 mb5  mb6 el1  el2  el3 ed1  ed2  ed3  hjE  hjL hjA');
}
