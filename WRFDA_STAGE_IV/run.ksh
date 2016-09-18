#! /bin/sh -x
#-----------------------------------------------------------------------
# 1. Purpose: To convert NCEP Stage IV data into the WRFDA-readable ASCII format.
# 2. Input and nessary setting: 
#    - NCEP ST4 DATA,           # Named as, ST4.2008020518.06h  
#    - DATA DIR,                # NCEP ST4 data directory
#    - WRFDA DIR,               # da_advance_time.exe will be used. 
#    - INITIAL_DATE,            # Start date of converting period
#    - FINAL_DATE,              # Final date of converting period
#    - CYCLE_PERIOD             # 60min, for hourly accumulated data 
#                               # 360min, for 6-hourly accumulated data 
#    - ACC_PERIOD               # 06h, 6-HOURLY ACCUMULATED PRECIP. Used in "FILE_SUFFIX"
#                               # 01h, HOURLY ACCUMULATED PRECIP. Used in "FILE_SUFFIX"  
#  
# 3. Output: 
#    - ob.rain.yyyymmddhh.xxh   # ob.rain.2008020518.06h
#  
#-----------------------------------------------------------------------
# SET PATH
#-----------------------------------------------------------------------

export DAT_DIR=/karri/users/jban/ncepst4_data
export WRFDA=/karri/users/jban/WRFDA

#-----------------------------------------------------------------------
# SET TIME
#-----------------------------------------------------------------------

export INITIAL_DATE=2008020518        
export FINAL_DATE=${INITIAL_DATE} 
# export FINAL_DATE=2008020618 
export CYCLE_PERIOD=360min   # 60min   
export ACC_PERIOD=06h        # 01h    

#-----------------------------------------------------------------------
# Do not need change below
#-----------------------------------------------------------------------
export ADVANCE_EXE_DIR=$WRFDA/var/build
export DATE=$INITIAL_DATE

while test $DATE -le $FINAL_DATE; do

echo " Doing job for " ${DATE}   
export YEAR=`echo $DATE | cut -c1-4`
export YY=`echo $DATE | cut -c3-4`
export MONTH=`echo $DATE | cut -c5-6`
export DAY=`echo $DATE | cut -c7-8`
export HOUR=`echo $DATE | cut -c9-10`
export MINUTE=`echo $DATE | cut -c11-12`

export FILE_SUFFIX=${YEAR}${MONTH}${DAY}${HOUR}.${ACC_PERIOD}   

#----------------------------------------------------------------------

export CYCLE_PERIOD2=1sec
export TIME=`${ADVANCE_EXE_DIR}/da_advance_time.exe ${DATE} -${CYCLE_PERIOD2} `
echo " Doing job for " ${TIME}   

export YEAR=`echo $TIME | cut -c1-4`
export YY=`echo $TIME | cut -c3-4`
export MONTH=`echo $TIME | cut -c5-6`
export DAY=`echo $TIME | cut -c7-8`
export HOUR=`echo $TIME | cut -c9-10`
export MINUTE=`echo $TIME | cut -c11-12`
export SECOND=`echo $TIME | cut -c13-14`

export DATA_TIME=${YEAR}-${MONTH}-${DAY}_${HOUR}:${MINUTE}:${SECOND}

#----------------------------------------------------------------------

./write_rainobs.exe  ${FILE_SUFFIX}  ${DATA_TIME}  ${DAT_DIR}

#-----------------------------------------------------------------------

echo " job done for  "  $DATE   
export DATE=`${ADVANCE_EXE_DIR}/da_advance_time.exe ${DATE} ${CYCLE_PERIOD} `

done

#-----------------------------------------------------------------------

exit
