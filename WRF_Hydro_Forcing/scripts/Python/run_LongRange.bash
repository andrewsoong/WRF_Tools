#!/bin/bash

#rm State.AnalysisAssimLayering.txt
while true
do
    python LongRangeRegridDriver.py ../../parm/wrf_hydro_forcing.dave
    sleep 60
done
exit 0
