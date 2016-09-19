#!/bin/bash

#rm State.*Regrid.txt
while true
do
    python Regrid_Driver.py HRRR ../../parm/wrf_hydro_forcing.dave
    sleep 60
done
exit 0
