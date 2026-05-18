# Pascal code for the cassava tri-trophic PBDM system

[![DOI](https://zenodo.org/badge/914567284.svg)](https://doi.org/10.5281/zenodo.17544160)

## Description

The meta population cassava GIS model was developed for scientific purposes and should not be used for commercial purposes. Copyright is held by the [Center for the Analysis of Sustainable Agricultural Systems](https://www.casasglobal.org/). The code has developer idiosyncrasies and is best used to develop similar code for other systems. The code is offered free access without warranty.

The repository has the following components to compile and run the model:

1. Delphi Pascal 3  `*.pas` files.
2. `modutils.pas` contains utilities (functions) called by the program (e.g., different version of distributed maturation time dynamics models).
3. The associated `*.DCU` files – note that the source codes for spatial.dcu was lost and the dcu is required for compiling.
4. The bat file to compile (`m.bat`) requires path corrections for your system.
5. The configuration file (cassava.ini) has all of the Boolean variables to run the various combinations of species in the model and the initial conditions (see additional notes in the file).
6. The run (r) file is in `rAfrica1980-2010windowscoarse.bat` with calls to specific locations (i.e., 1 or thousands of locations). An example call to one location is the following: `cassava cassava.ini 01 01 1980 12 31 1985 365 C:\models\wx\AgMERRA_wx_africa_coarse_1980-2010_windows\agmerra_0001_217_DZA_NF.txt`

The sub components of the location call line are:

- i. `cassava` is the simulation program,
- ii. `cassava.ini` is the setup file,
- iii. `01 01 1980 12 31 1985` says the start date is `01 01 1980` and the end date is `12 31 1985`
- iv. the path to weather data is `C:\models\wx\AgMERRA_wx_africa_coarse_1980-2010_windows\agmerra_0001_217_DZA_NF.txt`

If only one location is run (say on 15Aug2025), daily (or more coarse time intervals) output for that location can be specified in the `cassava.ini` file. If multiple locations are run (say 15,000 lattice cells across Africa) for say years 1980-2010, then at the end of every year, summary variables are appended to the text file `Summary.txt`, and yearly georeferenced summary variables are appended to text files `Cassava_15Aug25_00002`, ... , `Cassava_15Aug25_00010`, each of which contains that year’s results for all locations for that year. An example of tab delimited output for BEN_ikpinle.txt is illustrated below with the first line being the header line of variables and the second line are variable values.

Header:

`Model Date Time WxFile Long Lat JdStart JdEnd Month Day Year dd root stem leaf tuber leafnum sdlsr nsdlsr wsd sqdecmplt lai evapsoil fielddem avgev wvgwd gmtot TariNum TManNum mb1 mb2 mb3 mb4 mb5  mb6 ed1 ed2 ed3 el1 el2 el3`

Output line:

`CasGIS 15Aug25 8:07:28-PM C:\models\wx\agmerra_0011_332_BEN_ikpinle.txt 2.6250 7.1250 150 151 12 30 1991 3622 0.000 3.250 0.000 0.000 0.000 1.00  1.00 1.00 0.001 0.000 0.249 0.010 0.249 0.010 0.0682 0.0059 0.0000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.0000.000`

The `Summary.txt` file is used for statistical analyses and the means, std and coefficient of variation are computed for each location across `Cassava_15Aug25_00002`, ... , `Cassava_15Aug25_00010` and are used for GIS mapping. Once the run for one location is completed, the program re-initializes and goes to the next location in the `rAfrica1980-2010windowscoarse.bat` file for the next location to run. When all runs are completed, the program terminates.

Then the analysis can begin.

Andrew Paul Gutierrez

Luigi Ponti

## License

SPDX-License-Identifier: [GPL-3.0-or-later](https://spdx.org/licenses/GPL-3.0-or-later.html)

## Authors

- Andrew Paul Gutierrez (University of California, Berkeley / CASAS Global - Center for Analysis of Sustainable Agriculture Systems)
- Luigi Ponti (ENEA - Agenzia nazionale per le nuove tecnologie, l'energia e lo sviluppo economico sostenibile / CASAS Global)
