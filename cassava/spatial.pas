{
  Reconstructed Free Pascal replacement for the lost Delphi spatial.dcu.

  The interface is inferred from call sites in water.pas, nitr.pas, and
  cassava.pas plus symbol names recovered from spatial.dcu.
}

unit spatial;

interface

uses globals;

function cellarea(i,j:integer; l,t,r,b:single):single;
function inwind(xl,xr,ya,yb,left,right,top,bottom:integer):boolean;
procedure Setsides;

implementation

uses modutils;

function cellarea(i,j:integer; l,t,r,b:single):single;
{ Compute overlap area between query rectangle (l,t,r,b) and grid cell (i,j).
  Grid cells are 0.5 m wide; cell index 2 spans 0.0..0.5 m (index 1 is guard). }
var
	nl,nt,nr,nb:single;
	h,w:single;
begin
	nl:=i*0.5-1.0;
	nr:=i*0.5-0.5;
	nt:=j*0.5-1.0;
	nb:=j*0.5-0.5;

	w:=0;
	if l>=nl then w:=min(r,nr)-l;
	if (l<nl) and (r<=nr) then w:=r-nl;
	if (l<nl) and (r>nr) then w:=nr-nl;

	h:=0;
	if t>=nt then h:=min(b,nb)-t;
	if (t<nt) and (b<=nb) then h:=b-nt;
	if (t<nt) and (b>nb) then h:=nb-nt;

	cellarea:=w*h;
end;

function inwind(xl,xr,ya,yb,left,right,top,bottom:integer):boolean;
begin
	inwind:=((xl<right) and (left<xl) and (ya>top) and (ya<bottom)) or
			((xl<right) and (left<xl) and (yb>top) and (yb<bottom)) or
			((xr<right) and (left<xr) and (ya>top) and (ya<bottom)) or
			((xr<right) and (left<xr) and (yb>top) and (yb<bottom));
end;

{ Reconstructed from spatial.dcu disassembly. Block order (l,a,r,b), the
  sibling-vs-neighbour-centre clamp conditions, and the 0.2 (far-side inset)
  and 0.1 (centre half-gap) constants are taken verbatim from the DCU; see
  PORTING_NOTES.md "scattered-mode limoverlap reconstruction". }
procedure limoverlap(i:integer; var limitl,limitr,limita,limitb:single);
var
	j,k:integer;
	thisx,thisy,dx,dy:single;
begin
	thisx:=casPtrs[i]^.x;
	thisy:=casPtrs[i]^.y;

	for j:=1 to ncas do
	begin
		k:=deck[j];
		if k<>i then
		with casPtrs[k]^ do
		if (limitl<sider) and (limita<sideb) and
		   (limitr>sidel) and (limitb>sidea) then
		begin
			dx:=abs(thisx-x);
			dy:=abs(thisy-y);

			if (thisx>x) and (dx>=dy) then
			begin
				if (i-k)=1 then limitl:=max(limitl,sider)
				else limitl:=max(limitl,sider-0.2);
				if (limita<=y) and (limitb>=y) then
					limitl:=max(limitl,x+0.1);
				limitl:=min(limitl,thisx-0.1);
			end;

			if (thisy>y) and (dy>=dx) then
			begin
				if (i-k)=plantsperrow then limita:=max(limita,sideb)
				else limita:=max(limita,sideb-0.2);
				if (limitl<=x) and (limitr>=x) then
					limita:=max(limita,y+0.1);
				limita:=min(limita,thisy-0.1);
			end;

			if (thisx<x) and (dx>=dy) then
			begin
				if (k-i)=1 then limitr:=min(limitr,sidel)
				else limitr:=min(limitr,sidel+0.2);
				if (limita<=y) and (limitb>=y) then
					limitr:=min(limitr,x-0.1);
				limitr:=max(limitr,thisx+0.1);
			end;

			if (thisy<y) and (dy>=dx) then
			begin
				if (k-i)=plantsperrow then limitb:=min(limitb,sidea)
				else limitb:=min(limitb,sidea+0.2);
				if (limitl<=x) and (limitr>=x) then
					limitb:=min(limitb,y-0.1);
				limitb:=max(limitb,thisy+0.1);
			end;
		end;
	end;
end;

procedure findscatlims(i:integer; var limitl,limitr,limita,limitb:single);
begin
	with casPtrs[i]^ do
	begin
		limitl:=x-(maxwidth*0.5);
		limitr:=x+(maxwidth*0.5);
		limita:=y-(maxwidth*0.5);
		limitb:=y+(maxwidth*0.5);
	end;
	limoverlap(i,limitl,limitr,limita,limitb);
end;

procedure Setsides;
var
	i,k:word;
	dek:i100;
	limitl,limita,limitr,limitb:single;
	dist,maxmass,alpha,availarea,currentarea,demarea,suparea,newarea:single;
	newside,leafarea,newl,newr,newa,newb,neww,newh,hwratio,h,w:single;
begin
	if not scattered then
	begin
		shufl(dek,ncas);
		for i:=1 to ncas do deck[i]:=dek[i];
	end;

	for k:=1 to ncas do
	begin
		i:=deck[k];
		with casPtrs[i]^ do
		begin
			if glf<=0.0 then continue;

			if scattered then
				findscatlims(i,limitl,limitr,limita,limitb)
			else
			begin
				if i>jl then limitl:=casPtrs[jl]^.sider
				else limitl:=casPtrs[jl]^.sider-(jl-i+1)*plantspacing;
				if limitl>=x then limitl:=x-0.001;

				if i<jr then limitr:=casPtrs[jr]^.sidel
				else limitr:=casPtrs[jr]^.sidel+(i-jr+1)*plantspacing;
				if limitr<=x then limitr:=x+0.001;

				if i>ja then limita:=casPtrs[ja]^.sideb
				else limita:=casPtrs[ja]^.sideb-(((ja-i) div plantsperrow)+1)*rowspacing;
				if limita>=y then limita:=y-0.001;

				if i<jb then limitb:=casPtrs[jb]^.sidea
				else limitb:=casPtrs[jb]^.sidea+(((i-jb) div plantsperrow)+1)*rowspacing;
				if limitb<=y then limitb:=y+0.001;
			end;

			availarea:=(limitr-limitl)*(limitb-limita)*100.0;
			currentarea:=(sider-sidel)*(sideb-sidea)*100.0;
			suparea:=availarea-currentarea;
			if suparea<0.0 then suparea:=0.0;

			leafarea:=totall*casvar.dmgmle;
			if tdda<100.0 then leafarea:=max(leafarea,currentarea);

			newarea:=0.0;
			demarea:=leafarea-currentarea;
			if demarea>0.0 then
			begin
				alpha:=-0.01;
				newarea:=(1.0-Expo(suparea/demarea*alpha))*demarea;
				newarea:=currentarea+newarea;
			end;
			if demarea=0.0 then newarea:=currentarea;
			{ Shrink case: when demanded leaf area is below the current
			  footprint, the plant shrinks its footprint to the demanded
			  leaf area (newarea:=leafarea). Confirmed from the spatial.dcu
			  disassembly (setsides source line #384: MOV newarea,leafarea
			  when demarea<0). This only occurs when tdda>=100, i.e. mature
			  plants reducing footprint during senescence. }
			if demarea<0.0 then newarea:=leafarea;

			newarea:=newarea*0.01;
			w:=limitr-limitl;
			h:=limitb-limita;

			hwratio:=h/w;
			neww:=sqrt(newarea/hwratio);
			newh:=newarea/neww;

			newl:=x+(limitl-x)*(neww/w);
			newr:=x+(limitr-x)*(neww/w);
			newa:=y+(limita-y)*(newh/h);
			{ Original DCU uses neww/w here (not newh/h) — likely a bug
			  in the original source, but we replicate it for fidelity. }
			newb:=y+(limitb-y)*(neww/w);

			if (limitr-limitl)>=neww then
			begin
				if newr>limitr then
				begin
					sider:=limitr;
					sidel:=newl-(newr-limitr);
				end;
				if newl<limitl then
				begin
					sidel:=limitl;
					sider:=newr+(limitl-newl);
				end;
				if (newl>=limitl) and (newr<=limitr) then
				begin
					sidel:=newl;
					sider:=newr;
				end;
			end
			else
			begin
				sidel:=limitl;
				sider:=limitr;
				newh:=newarea/(sider-sidel);
				newa:=y-(newh*0.5);
				newb:=y+(newh*0.5);
			end;

			if (limitb-limita)>=newh then
			begin
				if newa<limita then
				begin
					sidea:=limita;
					sideb:=newb+(limita-newa);
				end;
				if newb>limitb then
				begin
					sideb:=limitb;
					sidea:=newa-(newb-limitb);
				end;
				if (newa>=limita) and (newb<=limitb) then
				begin
					sidea:=newa;
					sideb:=newb;
				end;
			end
			else
			begin
				sidea:=limita;
				sideb:=limitb;
			end;

			w:=((limitr-sider)*0.5+sider)-((sidel-limitl)*0.5+limitl);
			h:=((limitb-sideb)*0.5+sideb)-((sidea-limita)*0.5+limita);
			sqdmpl:=w*h*100.0;
		end;
	end;
end;

end.
