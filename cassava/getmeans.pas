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

{$n+,e-}
unit means;
interface
uses glob50,util50;

procedure  GetMeans(	var plantarray:plantptrarray;
			var mbarray:mptrarray;
			var edptr:edparray;
			var elptr:elparray;
			var gmarray:gmptrarray;
			var p1array:predarray;
			var p2array:predarray;
			var hjptrs : hjarray;
			np:integer);
implementation


procedure GetMeans(var plantarray:plantptrarray;np:integer);
{
From a plant population of size NP represented in PLANTARRAY,
record the means of variables such as fruit mass, leaf mass, etc. in the plantarray cell 101.

}
var
	f,t,l,la,ln,s,sd,ws,ns,rs,d,r,nit:single;
	i:word;
begin
	d:=0.0;
	f:=0.0;
	t:=0.0;
	l:=0.0;
	la:=0.0;
	ln:=0.0;
	nit:=0.0;
	ns:=0.0;
	r:=0.0;
	s:=0.0;
	sd:=0.0;
	rs:=0.0;
	ws:=0.0;

	for i:=1 to np do
	begin
	{total each var}
	{The first np entries of array 'deck' have indeces of plant locations.}
		with plantarray[i]^ do
		begin
			t:=t+tuber;
			l:=l+totall;
			ln:=ln+tfolnum;
			r:=r+totalr;
			s:=s+totals;
			la:=la+lai;
			rs:=rs+reserves;
			nit:=nit+nres;
			ns:=ns+nsdlsr;
			sd:=sd+sdlsr;
			ws:=ws+wsd;
			sqdm:=sqdm+sqdmpl;
		end;
	end;
	{store means in plant 101.}
	with plantarray[101]^ do
	begin
		tuber   := t/nsamp;
		totall  := l/nsamp;
		totalr  := r/nsamp;
		tfolnum := ln/nsamp;
		totals  := s/nsamp;

		lai     := la/nsamp;
		reserves:= rs/nsamp;
		nres    := nit/nsamp;
		nsdlsr  := ns/nsamp;
		sdlsr   := sd/nsamp;
		wsd     := ws/nsamp;
		sqdmpl  := sqdm/nsamp;
	end;

	if gmin then
	begin
		for k:=1 to 4 do begin gmt[k]:=0.0; end;
		for k:=1 to 1 do 
		begin
			p1t[k]:=0.0;
			p2t[k]:=0.0;
		end;

		{accumulate gm totals in temporary variables.}
		for i:=1 to np do
		begin
			if gmin then
			with gmarray[i]^ do  { if gmgo then}
			begin
				for k:=1 to 4 do gmt[k]:=gmt[k]+gmnums[k];
			end;

			if p1in then with p1array[i]^ do p1t[1]:=p1t[1]+predreport; {Predreport is set in Preds.pas.}
			if p2in then with p2array[i]^ do p2t[1]:=p2t[1]+predreport;
		end;
	
		{store means in array cell 101.}
		if gmin then with gmptrs[101]^ do
		begin
			gmtot:=0.0;
			for k:=1 to 4 do 
			begin
				gmnums[k]:=gmt[k]/np;
				gmtot:=gmtot+gmnums[k];
			end;
		end;

		if p1in then
		with p1array[101]^ do
		begin
			predreport:=p1t[1]/np;
		end;
		if p2in then
		with p2array[101]^ do
		begin
			predreport:=p2t[1]/np;
		end;
	end; {if gmin}

	if hjin) then
	begin
		for k:=1 to 3 do hjt[k]:=0.0;

		{accumulate sample totals in temporary variables.}
		for i:=1 to np do
		begin
			if plantarray[i]^.hjthisplant then
			with hjptrs[i]^ do
			begin
				hjt[1]:=hjt[1]+	hjegnm;
				hjt[2]:=hjt[2]+ hjlarn;
				hjt[3]:=hjt[3]+ hjadnm;
			end;
		end;

		{store means in array cell 101.}
		if (hjin) then with hjptrs[101]^ do
		begin
			hjegnm:=hjt[1]/np;
			hjlarn:=hjt[2]/np;
			hjadnm:=hjt[3]/np;
		end;
	end;

	if cmbin then 
	begin
		for k:=1 to 6 do mbt[k]:=0.0;

		for k:=1 to 3 do 
		begin
			edt[k]:=0.0;
			elt[k]:=0.0;
		end;

		mb5size:=0.0;
		for i:=1 to np do
		{accumulate totals in temporary variables.}
		begin
			with plantarray[i]^ do
			begin	
				if cmbthisplant then {are cmb on it?}
				with mbarray[i]^ do if cmbgo then   {are they active?}
				begin
					for k:=1 to 2 do mbt[k]:=mbt[k]+mbn[k];

					{combine larva stages 3 and 4}
					mbt[3]:=mbt[3]+mbn[3];
					mbt[4]:=mbt[4]+mbn[4];
					mbt[3]:=mbt[3]+mbt[4];

					for k:=5 to 6 do mbt[k]:=mbt[k]+mbn[k];
				
					if elthisplant then 
					with elptr[i]^ do
					begin
						for k:=1 to 3 do elt[k]:=elt[k]+elnum[k];
						elsexratio:=elsexratio+sexratio;
					end;

					if edthisplant then
					with edptr[i]^ do
					begin
						for k:=1 to 3 do edt[k]:=edt[k]+ednum[k];
						edsexratio:=edsexratio+sexratio;
					end;

					if mbsize[5]>0.0 then mb5size:=mb5size+mbsize[5];

				end; {with mbarray[i]^ do if cmbgo then}

			end; {with plantarray[i]^ do}

		end;

		{store means in array cell 101.}
		with mbarray[101]^ do
		begin
			for k:=1 to 6 do mbn[k]:=mbt[k]/np;
			{remove 4 from 3:} mbn[3]:=(mbt[3]-mbt[4])/np;
		end;

		if edin then
		with edptr[101]^ do for k:=1 to 3 do ednum[k]:=edt[k]/np;

		if elin then
		with elptr[101]^ do for k:=1 to 3 do elnum[k]:=elt[k]/np;

	end;{if cmbin}
(*
	{May save means and standard deviations in a file.}
	if savemeans then
	with plantarray[101]^ do
	begin
		write(meanfile,realday:9:0,tddfield:10:3);
		write(meanfile,totalr:10:3,stdev(r,rsq,totalr,nsamp):8:3);
		write(meanfile,totals:10:3,stdev(s,ssq,totals,nsamp):8:3);
		write(meanfile,totall:10:3,stdev(l,lsq,totall,nsamp):8:3);
		write(meanfile,tuber:10:3,stdev(t,tsq,tuber,nsamp):8:3);
		write(meanfile,tfolnum:10:3,stdev(ln,lnsq,tfolnum,nsamp):8:3);

		write(meanfile, sdlsr*100:8:3{,stdev(sd,sdsq,sdlsr,nsamp):8:3});
		write(meanfile,nsdlsr*100:8:3{,stdev(ns,nssq,nsdlsr,nsamp):8:3});
		write(meanfile,   wsd*100:8:3{,stdev(ws,wssq,wsd,nsamp):8:3});
		write(meanfile,solrad:8:3,precip*10:8:3,tmean*10:9:2);
		write(meanfile,fieldlai:8:3,fieldevapsoil:8:3,fielddem:8:3,
			avgev:9:3,avgwd:8:3,sqdmpl:8:3);

		write(meanfile,lai:8:3,stdev(la,lasq,lai,nsamp):8:3);
		write(meanfile,reserves:8:3,stdev(rs,rssq,reserves,nsamp):8:3);
		write(meanfile,nres:8:3,stdev(nit,nitsq,nres,nsamp):8:3);
		write(meanfile,nsdlsr:8:3,stdev(ns,nssq,nsdlsr,nsamp):8:3);
		write(meanfile,sdlsr:8:3,stdev(sd,sdsq,sdlsr,nsamp):8:3);
		write(meanfile,wsd:8:3,stdev(ws,wssq,wsd,nsamp):8:3);

		writeln(meanfile);

	end;
*)
	
end;
(*
procedure gmMEANS(plantarray:plantptrarray;
		var gmarray:gmptrarray;var p1array:predarray;var p2array:predarray;
		np:integer);
{
From a plant population of size NP which are represented in PLANTARRAY,
record the means of numbers of GM (+pred1,pred2).  Gmnums has the total numbers in 4 stages.
Record the means in arrays 101.
}
var
	gmt: array[1..4]of single;
	p1t,p2t: array[1..3]of single;
	gm5size,gm5sq:single;
	i,j,k,gmcount,gmcount5,p2count,p1count:integer;
begin

	{May save means and standard deviations in a file.}
	if savemeans then
	begin
		with gmarray[101]^ do
		begin
			with plantarray[101]^ do write(gmmeanfile,realday:5:0,tddfield:7:0);
			for i:=1 to 4 do
			begin
				s[i]:=gmt[i]/nsamp;
				stdv[i]:=stdev(gmt[i],gmsq[i],s[i],nsamp);
			end;
			for i:=1 to 4 do write(gmmeanfile,s[i]:11:1,' ');
			for i:=1 to 4 do write(gmmeanfile,stdv[i]:11:1,' ');
		end;

		if (p1in) then with p1array[101]^ do
	        begin
			s[1]:=p1t[1]/nsamp;
   			write(gmmeanfile,' ',s[1]:9:2,' ',stdev(p1t[1],p1sq[1],s[1],nsamp):9:2);
	        end;

		if (p2in) then with p2array[101]^ do
		begin
			s[1]:=p2t[1]/nsamp;
   			write(gmmeanfile,' ',s[1]:9:2,stdev(p2t[1],p2sq[1],s[1],nsamp):9:2);
		end;
		writeln(gmmeanfile,rhmean:8:2);

	end; {if savemeans}

end;

procedure HJmeans(plantarray:plantptrarray;var hjptrs : hjarray;,np:integer);
{
From a plant population of size NP  represented in PLANTARRAY,
record the means of numbers of GM (+pred1,pred2).
Gmnums has the total numbers in 4 stages.
Record the means in arrays 101.
}
var
	hjt : array[1..3]of single;
	i,j,k:integer;
	s:real;
begin

		{May save means and standard deviations in a file.}
		if savemeans then
		begin
			if (hjin) then with hjptrs[101]^ do
        		begin

				with plantarray[101]^ do write(hjmeanfile,realday:5:0,tddfield:6:0,' ');
				for i:=1 to 3 do
				begin
					s:=HJt[i]/nsamp;
					write(hjmeanfile,s:9:2,' ');
				end;
				for i:=1 to 3 do
				begin
					s:=HJt[i]/nsamp;
					write(hjmeanfile,stdev(HJt[i],HJsq[i],s,nsamp):9:2,' ');
				end;
				writeln(hjmeanfile);
	        	end;
		end; {if savemeans}


end;{HJMeans}

procedure incondx(plantarray:plantptrarray;nsamp,np:integer;
		var nsm,nstd,osm,ostd,wsm,wstd:single);
{
From a population of size NP which are represented in PLANTARRAY,
choose NSAMP plants at random and record the means of initial
conditions of SOILN, ORG, SOILW in the soil around the plant.
Return the means and stdevs.
}
var
	i,k,l:byte;
	nsoil,osoil,wsoil,ns,os,ws:single;
	nsoilsq,osoilsq,wsoilsq:single;
	sqdm,sqdmsq:single;
begin
	nsoil:=0.0;
	ns:=0.0;
	nsoilsq:=0;
	osoil:=0.0;
	os:=0.0;
	osoilsq:=0;
	wsoil:=0.0;
	ws:=0.0;
	wsoilsq:=0;

	if nsamp>0 then
	for i:=1 to nsamp do
	{total each var}
	{accumulate sum of squares for each var for computing stdev.}
	begin
		if nsamp=np then j:=i else j:=random(np)+1;
		with plantarray[deck[j]]^ do
		begin
			k:=round(x*2+2); l:=round(y*2+2); {map from field x,y to narray[k,l], etc.}
k:=maxint(0,k);k:=minint(k,22);			
l:=maxint(0,l);l:=minint(l,22);			
			ns:=narray[k,l]*4; {N in 1 sq meter around plant}
			nsoil:=nsoil+ns;
			if ns>0.0 then nsoilsq:=nsoilsq+sqr(ns);
			os:=oarray[k,l]*4; {Org N in 1 sq meter around plant}
			osoil:=osoil+os;
			if os>0.0 then osoilsq:=osoilsq+sqr(os);

			ws:=layer[1].warray[k,l]*4; {SOILW in 1 sq meter around plant}
			wsoil:=wsoil+ws;
			if ws>0.0 then wsoilsq:=wsoilsq+sqr(ws);

		end;
	end;

	{means}	
	nsm:=nsoil/nsamp;
	osm:=osoil/nsamp;
	wsm:=wsoil/nsamp;

	{stdevs}
	nstd:=stdev(nsoil,nsoilsq,nsm,nsamp);
	ostd:=stdev(osoil,osoilsq,osm,nsamp);
	wstd:=stdev(wsoil,wsoilsq,wsm,nsamp);
end; {incondx}

procedure mbMeans(plantarray:plantptrarray;
		var mbarray:mptrarray;var edptr:edparray;var elptr:elparray;
		np:integer);
{
From a plant population of size NP represented in PLANTARRAY,
record the means of numbers of MB, (el,ed). Record the means in arrays 101.
}
var
	mbt: array[1..6]of single;
	edt,elt: array[1..3]of single;
	mbsexratio,elsexratio,edsexratio,s,mb5size:single;
	i,j,k:integer;
	s1,s2,s3,s4,s5,s6:single;
begin


	{May save means and standard deviations in a file.}
	if ((savemeans)and(nsamp>0)) then
	begin
		with mbarray[101]^ do
		begin
			sexratio:=mbsexratio;
			write(mbmeanfile,realday:5:0,tddfield:6:0);


			s1:=mbt[1]/nsamp;
			stdv1:=stdev(mbt[1],msq[1],s1,nsamp);
			s2:=mbt[2]/nsamp;
			stdv2:=stdev(mbt[2],msq[2],s2,nsamp);
			s3:=mbt[3]/nsamp;
			stdv3:=stdev(mbt[3],msq[3],s3,nsamp); {s3 represents larv3+larv4}
			s5:=mbt[5]/nsamp;
			stdv5:=stdev(mbt[5],msq[5],s5,nsamp);
			s6:=mbt[6]/nsamp;
			stdv6:=stdev(mbt[6],msq[6],s6,nsamp);
			write(mbmeanfile,s1:9:1,' ',s2:9:1,' ',s3:9:1,' ',s5:9:1,' ',s6:9:1,' ');
			write(mbmeanfile,stdv1:9:1,' ',stdv2:9:1,' ',stdv3:9:1,' ',stdv5:9:1,' ',stdv6:9:1,' ');
			
			if mbcount5>0 then s:=mb5size/mbcount5 else s:=0.0;
			write(mbmeanfile,s:7:2,' ',stdev(mb5size,mb5sq,s,mbcount5):7:2);

		end;

		if ( elin) then with elptr[101]^ do
		begin
			s1:=elt[1]/nsamp;
			stdv1:=stdev(elt[1],elsq[1],s,nsamp);
			s2:=elt[2]/nsamp;
			stdv2:=stdev(elt[2],elsq[2],s,nsamp);
			s3:=elt[3]/nsamp;
			stdv3:=stdev(elt[3],elsq[3],s,nsamp);
			write(mbmeanfile,s1:9:2,' ',s2:9:2,' ',s3:9:2,' ',stdv1:9:2,' ',stdv2:9:2,' ',stdv3:9:2,' ');
			write(mbmeanfile,elsexratio:7:2,' ');
	        end;
		if (edin) then with edptr[101]^ do
        	begin
			s1:=edt[1]/nsamp;
			stdv1:=stdev(edt[1],edsq[1],s,nsamp);
			s2:=edt[2]/nsamp;
			stdv2:=stdev(edt[2],edsq[2],s,nsamp);
			s3:=edt[3]/nsamp;
			stdv3:=stdev(edt[3],edsq[3],s,nsamp);
			write(mbmeanfile,s1:9:2,' ',s2:9:2,' ',s3:9:2,' ',stdv1:9:2,' ',stdv2:9:2,' ',stdv3:9:2,' ');
			write(mbmeanfile,edsexratio:7:2);
	        end;
		writeln(mbmeanfile);
	end; {if savemeans}



end;{mbsample}

*)
end.
