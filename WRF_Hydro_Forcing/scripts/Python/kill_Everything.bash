#!/bin/bash

/rap/bin/snuff run_AA_Layering.bash
/rap/bin/snuff run_LongRange.bash
/rap/bin/snuff run_Regrid_GFS.bash
/rap/bin/snuff run_Regrid_HRRR.bash
/rap/bin/snuff run_Regrid_MRMS.bash
/rap/bin/snuff run_Regrid_RAP.bash
/rap/bin/snuff run_ShortRangeLayering.bash

exit 0
