program spatial_probe;

uses spatial;

begin
	writeln('cellarea full=', cellarea(2, 2, 0.0, 0.0, 0.5, 0.5):0:6);
	writeln('cellarea quarter=', cellarea(2, 2, 0.25, 0.25, 0.75, 0.75):0:6);
	writeln('cellarea none=', cellarea(2, 2, 0.5, 0.5, 1.0, 1.0):0:6);
	writeln('inwind inside=', inwind(1, 3, 1, 3, 0, 10, 0, 10));
	writeln('inwind outside=', inwind(11, 12, 11, 12, 0, 10, 0, 10));
end.
