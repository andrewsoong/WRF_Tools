#!/bin/bash
# run all steps of WPS to convert CAM output to WRF initial and
# boundary conditions; see comments at header of fortran file in this
# directory for more info.  to run this, use crest, not swell, and the
# following command:
# cd ~/WRF_Mauricio/; \rm ~/WRF_Mauricio/Output/run_produce_periodic_yeary_bndry_conditions.out; nohup run_produce_periodic_yeary_bndry_conditions.bash > Output/run_produce_periodic_yeary_bndry_conditions.out&

# echo commands to screen:
set -o verbose

run=2005       # dorian's case number: 2003, 2004 or 2005
yr_start=2003  # start year in the CAM2WRF.input file.  should be 2003
mkdir Output/$run

year=0  # standard value is 0; to do only year n, specify here n-1
while [ $year -ne 10 ]  # standard value is 10; to do only year n, specify here n
do
    # move to work directory at the beginning of the loop and set some variables:
    cd ~/WRF_Mauricio/;
    year=$(( $year + 1 ))
    echo ' year=' $year
    echo '==========='
    outdir='/home/eli/WRF_Mauricio/Output/'$run'/'$year
    outdir_intermediate='/home/eli/WRF_Mauricio/Output/'$run'/'$year'/intermediate'
    echo "outdir=" $outdir
    logfile=$outdir'/log'
    mkdir $outdir
    mkdir $outdir_intermediate
    yr=$(( $yr_start+$year-1))
    yrp1=$(( $yr_start+$year))
    yrp2=$(( $yr_start+$year+1))

    # is this a leap-year?
    if (( $yrp1==2004 )) || (( $yrp1==2008 )) || (( $yrp1==2012 )); then
	leap="-leap"
    else
	leap=""
    fi
    echo "leap=" $leap
    
    # prepare input file for FORTRAN program:
    cat Input/CAM2WRF-$run$leap.input | sed "s/\"2004-/\"${yrp1}-/g" | sed "s/\"2003-/\"${yr}-/g" > Input/CAM2WRF.input;

    # prepare input file for real.exe program:
    cat Output/namelist.input-1yr | sed "s/= 2004/= ${yrp1}/g" | sed "s/= 2003/= ${yr}/g" > Output/namelist.input;

    # prepare input file for metgrid.exe program:
    cat Output/namelist.wps-1yr | sed "s/2004-07-01_00:00:00/${yrp1}-07-01_00:00:00/g" | sed "s/2003-07-01_00:00:00/${yr}-07-01_00:00:00/g" > Output/namelist.wps

    # create a file with start and end dates for this year:
    head -1  Input/CAM2WRF.input > $outdir/start_end_dates.txt
    tail -1  Input/CAM2WRF.input >> $outdir/start_end_dates.txt

    # clean results of previous runs:
    cd ~/WRF_Mauricio/Output/; \rm CAM2WRF?.log metgrid.log FILE\:* met_em.* wrfbdy_d01 wrfinput_d01

    # CAM to intermediate format:
    cd ~/WRF_Mauricio/; ifort -c -CB -par_report0 -vec_report0 -I/opt/netcdf-3.6.0-p1/include/ CAM_netcdf_to_WRF_intermediate.f90; ifort CAM_netcdf_to_WRF_intermediate.o -L/opt/netcdf-3.6.0-p1/lib/ -lnetcdf; ./a.out > CAM2WRF.my_out

    # intermediate to netcdf:
    cd ~/WRF_Mauricio/Output/; ./metgrid.exe > metgrid.my_out

    # final step: produce initial and boundary condition files: note
    # that I copied real.exe and its namelist input file to the
    # Output/ directory:
    cd ~/WRF_Mauricio/Output/; ./real.exe > real.my_out

    # move output files:
    cd ~/WRF_Mauricio/Output/;
    \mv *.log CAM2WRF.my_out metgrid.my_out real.my_out wrfbdy_d01 wrflowinp_d01 wrfinput_d01 namelist.input namelist.wps $outdir;

    # save a copy of the metgrid intermediate files:
    \mv FILE\:* met_em* $outdir_intermediate
    #\rm FILE\:* met_em*

done
