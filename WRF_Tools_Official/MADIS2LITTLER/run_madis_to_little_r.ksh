#! /bin/ksh -aeu

#######################################################################################
# Script: run_madis_to_little_r.ksh
#
# Purpose: To convert MADIS data into "little_r" format that OBSPROC uses
#
#  Input required: date and run directory information
#		Usage: madis_to_little_r.exe $ANALYSIS_DATE MADIS2LITTLE_R_DIR/
#		Format of required input: ANALYSIS_DATE=2007-04-23_18:00:00.0000   
#       	MADIS2LITTLE_R_DIR=The path that you want to save little_r data
#
#
# Meral Demirtas, NCAR/DATC
# Ruifang Li: Added Canadian's SAO, SATWND 3h observation types.    10/19/2009 
# Ruifang Li: Added mesoent type.                                   06/2010  
# Ruifang Li: Added MAP, NPN, SATWND 1h observationi types.         03/2011  
# Mike Kavulich: Updated for release                                10/2013
#######################################################################################


# MADIS_DATA, MADIS_STATIC are used in MINIT subroutine of madis_to_little_r.f90
# MADIS_DATA is the MADIS observation root directory (as described in README)
# MADIS_STATIC directory includes template file for each of MADIS observation types
# It it under MADIS API/static
export MADIS_DATA=/glade/p/work/kavulich/WORKDIR/MADIS2LITTLER/data
export MADIS_STATIC=/glade/u/home/kavulich/libs/madis-4.2_ifort/static


# Specify the MADIS types. TRUE is to convert this type to little_r, otherwise set to FALSE
#
# If METAR=TRUE, it will convert METAR, SAO, MESO, COOP observation to little_r if 
# these observation are available in the right directory, otherwise it only converts 
# the available types.
#
# YOU ONLY SHOULD SET TO "TRUE" OBSERVATION TYPES THAT ARE AVAILABLE IN THE "MADIS_DATA" DIRECTORY
export METAR=TRUE
export MARINE=FALSE
export GPSPW=FALSE
export ACARS=FALSE
export RAOB=FALSE
export NPN=FALSE
export MAP=FALSE
export SATWND=FALSE


# Time info
# SDATE is the start time, EDATE is the end time. INTERVAL unit is hour
SDATE=2013101718
EDATE=2013101800
INTERVAL=1


# Directory info
# CODE_DIR should contain madis_to_little_r.exe and da_advance_time.exe
# MADIS2LITTLE_R_DIR will be the location of the converted little_r obs
CODE_DIR=/glade/p/work/kavulich/WORKDIR/MADIS2LITTLER/WORKDIR/update_42
MADIS2LITTLE_R_DIR=${MADIS_DATA}/little_r_obs



#######################################################
# It should not be necessary to edit beyond this line #
#######################################################


DATE=$SDATE
while test $DATE -le  $EDATE; do

    # Define the working directory
    export WORKING_DIR=${MADIS2LITTLE_R_DIR}/${DATE}

    # Prepare sub-dirs for each obs types

    if [[ ! -d WORKING_DIR ]]; then
       if [[ (${METAR} = 'TRUE') ]]; then
          mkdir -p ${WORKING_DIR}/metar
       fi
    
       if [[ (${ACARS} = 'TRUE') ]]; then
          mkdir -p ${WORKING_DIR}/acars
       fi

       if [[ (${MARINE} = 'TRUE') ]]; then
          mkdir -p ${WORKING_DIR}/maritime
       fi
 
       if [[ (${GPSPW} = 'TRUE') ]]; then
          mkdir -p ${WORKING_DIR}/gpspw
       fi
 
       if [[ (${RAOB} = 'TRUE') ]]; then
          mkdir -p ${WORKING_DIR}/raob
       fi
 
       if [[ (${SATWND} = 'TRUE') ]]; then
          mkdir -p ${WORKING_DIR}/HDW
       fi
      
       if [[ (${NPN} = 'TRUE') ]]; then
          mkdir -p ${WORKING_DIR}/npn
       fi
 
       if [[ (${MAP} = 'TRUE') ]]; then
          mkdir -p ${WORKING_DIR}/map
       fi
 
    fi

    # Set input date required by the executable
    ANALYSIS_DATE=$(${CODE_DIR}/da_advance_time.exe $DATE 0 -w).0000
    FILE_DATE="$(echo $ANALYSIS_DATE  | cut -c1-13)" 

    # Run the code
    if [[ (${METAR} = 'TRUE') || (${RAOB} = 'TRUE') || (${ACARS} = 'TRUE') || (${SATWND} = 'TRUE') \
       || (${MARINE} = 'TRUE') || (${NPN} = 'TRUE') || (${MAP} = 'TRUE') || (${GPSPW} = 'TRUE')]]; then 
       ${CODE_DIR}/madis_to_little_r.exe $ANALYSIS_DATE ${WORKING_DIR}/
    else
       echo 'Please specify at least one obs to convert. EXIT ....'
       exit
    fi
    
    # Get the next date 
    DATE=$(${CODE_DIR}/da_advance_time.exe $DATE $INTERVAL)

done

echo 'MADIS2LITTLER complete!'
exit
