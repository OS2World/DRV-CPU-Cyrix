setlocal

set path=d:\ddkpros\tools;%PATH%
set include=d:\ddkpros\pmsrc\src\inc;%INCLUDE%
set lib=d:\ddkpros\pmsrc\src\lib;%LIB%

masm /Zi /l /n cyrix;
link /Co /Map cyrix, cyrix.sys, cyrix.map, os2, cyrix;
mapsym cyrix

endlocal

