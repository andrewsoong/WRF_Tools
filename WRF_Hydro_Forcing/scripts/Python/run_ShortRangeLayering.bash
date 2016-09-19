#!/bin/bash

while true
do
    python ShortRangeLayeringDriver.py ../../parm/wrf_hydro_forcing.dave
    sleep 60
done
exit 0
