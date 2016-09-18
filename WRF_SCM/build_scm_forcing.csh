#!/bin/csh
# sets environment and command-line arguments for the ncl script
#
# NOTES/TODO: 
# 1.  Need to make the cdl file have the correct number layers - get from met_em* file. 

set ensSize = 100 # ensemble size
set forceCDL = forcing_file.cdl # forcing file cdl
set metPath = ./ARM_BAMEX # path to met_em files
set simLength = 86400 # length of simulation in seconds
set forcingInterval = 1800 # seconds, negative if don't need to interpolate
# following in C-syle indexing (starts at 0)
set xll = 0; # lower left x index of mass grid square containing SCM
set yll = 0; # lower left y index of mass grid square containing SCM
set randSeed1 = 29 # these will be used to set the seed (not used for ensSize=0)
set randSeed2 = 376201
set centerDate = "" # valid initialization date or empty
#set centerDate = "2003-05-03" # valid initialization date
set centerTime = "12:00:00"
#set forceArcDir = ./WRF-SCM-files/$centerDate
set forceArcRoot = /media/disk/jphacker/WRF-SCM-files

# END OF USER MODIFICATIONS

# check for existence of ncl script
if ( ! -e build_scm_forcing.ncl ) then
  echo REQUIRES NCL SCRIPT build_scm_forcing.ncl
  exit 1
endif

# check for existence of cdl file
if ( ! -e $forceCDL ) then
  echo REQUIRES CDL FILE $forceCDL
  exit 1
endif

# if not a specified date then make them all
if ( $centerDate == "" ) then
  set initList = ( `ls ${metPath}/met_em*${centerTime}.nc` )
else
  set initList = ( ${metPath}/met_em.d01.${centerDate}_${centerTime}.nc )
endif

setenv SIMLENGTH $simLength
setenv METPATH $metPath
setenv XLL $xll
setenv YLL $yll
setenv RANDSEEDa $randSeed1
setenv RANDSEEDb $randSeed2
if ( $forcingInterval > 0 ) setenv FORCING_INTERVAL $forcingInterval

# big loop thru dates
foreach centerFile ( $initList )

  set centerBase = `basename $centerFile .nc`
  set centerDate = `echo $centerBase | cut -c 12-30`

  setenv CENTER_DATE $centerDate

  # strip out base name of forcing file template
  set fNameRoot = `basename $forceCDL .cdl`

  set forceArcDir = $forceArcRoot/$centerDate
  if ( ! -d forceArcDir ) mkdir -p $forceArcDir

  # if more than 0 perturbations, copy then call ncl script
  @ imember = 1
  while ( $imember <= $ensSize )

    set cmember = $imember
    if ( $imember < 1000 ) set cmember = 0$cmember
    if ( $imember < 100  ) set cmember = 0$cmember
    if ( $imember < 10   ) set cmember = 0$cmember

    set forcingFile = ${fNameRoot}_${cmember}.nc
    ncgen -o $forcingFile $forceCDL

    # call NCL script
    setenv FORCE_FILE_NAME $forcingFile
    setenv ENSEMBLE_MEMBER $imember
    ncl < build_scm_forcing.ncl

    if ( $status ) then
      echo FAILED on ensemble member $imember
      exit 1
    endif

    # time interpolate if needed
    if ( $forcingInterval > 0 ) then
      ncl < time_interpolate_forcing.ncl
      /bin/mv -f forcing_temp.nc $forcingFile
    endif
  
    if ( $status ) then
      echo FAILED on time interpolation for ensemble member $imember
      exit 1
    endif

    # rename and concatenate some of the output
    cat surface_init.txt > $forceArcDir/input_sounding_${cmember}
    cat profile_init.txt >> $forceArcDir/input_sounding_${cmember}
    /bin/cp -f soil_init.txt $forceArcDir/input_soil_${cmember}
    /bin/mv -f $forcingFile $forceArcDir

    @ imember ++
  end

  # finally, create the unperturbed one
  set forcingFile = ${fNameRoot}.nc
  ncgen -o $forcingFile $forceCDL

  setenv FORCE_FILE_NAME $forcingFile
  setenv ENSEMBLE_MEMBER 0

  ncl < build_scm_forcing.ncl

  if ( $status ) then
    echo FAILED on control
    exit 1
  endif

  # time interpolate if needed
  if ( $forcingInterval > 0 ) then
    ncl < time_interpolate_forcing.ncl
    /bin/mv -f forcing_temp.nc $forcingFile
  endif

  if ( $status ) then
    echo FAILED on time interpolation for control
    exit 1
  endif

 
  # rename and concatenate some of the output
  cat surface_init.txt > $forceArcDir/input_sounding
  cat profile_init.txt >> $forceArcDir/input_sounding
  /bin/cp -f soil_init.txt $forceArcDir/input_soil
  /bin/mv -f $forcingFile $forceArcDir

end # big loop through init dates

echo SUCCESS
exit 0


