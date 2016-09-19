#!/bin/bash

./run_AA_Layering.bash &
./run_LongRange.bash &
./run_Regrid_GFS.bash &
./run_Regrid_HRRR.bash &
./run_Regrid_MRMS.bash &
./run_Regrid_RAP.bash &
./run_ShortRangeLayering.bash &

exit 0
