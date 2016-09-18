#! /bin/ksh

########################################################################################
# Script: compile.ksh
#
# Purpose: To compile MADIS2LITTLER (madis_to_little_r.f90) code
#
#  Required libraries:
#  1. MADIS API library: MADIS_EXTERNAL = Directory that contains "madislib.a"
#  2. netCDF library: NETCDF = Directory that contains "libnetcdf.a"
#
#  Final output: madis_to_little_r.exe
#
# May 2009:  Ruifang Li - for compilation and run in csh
# July 2009: Meral Demirtas - cleaned and organized only for compilation in ksh
# Oct 2013:  Mike Kavulich - polished up and added new compile options
# Feb 2014:  Mike Kavulich - Fixed incorrect location for madislib.a
#
########################################################################################


########################################################################################
#                                                                                      #
#   YOU SHOULD ONLY HAVE TO MODIFY THESE TWO VALUES! (MADIS_EXTERNAL AND NETCDF_LIB)   #
#                                                                                      #
########################################################################################

  # Define required libs. 
  # This script looks for madislib.a in ${MADIS_EXTERNAL}, libnetcdf.a in ${NETCDF_LIB}
  MADIS_EXTERNAL=/glade/u/home/kavulich/libs/madis-4.2_ifort/lib/
  NETCDF_LIB=/glade/apps/opt/netcdf/4.3.0/intel/12.1.5/lib/


# AGAIN, YOU SHOULD NOT HAVE TO MODIFY ANYTHING BEYOND THIS LINE
########################################################################################


# Quit if no compiler specified
if [[ $# -eq 0 ]];then
   print "\nYou must specify a compiler!\n"
   print "Usage: ./compile.ksh [ifort|pgf90|gfortran]\n"
   exit
fi



# Link MADIS API library file due to their weird naming convention

  ln -sf ${MADIS_EXTERNAL}/madislib.a ./libmadis.a

#####################################################################
# IFORT
if [[ $1 = ifort ]];then
  print "Compiling MADIS2LITTLER with $1\n"


  # Compile: it looks for madislib.a in ${MADIS_EXTERNAL}, libnetcdf.a in ${NETCDF_LIB}

  ifort  -o da_advance_time.exe da_advance_time.f90
  ifort  -c -free module_output.F
  ifort  -c madis_to_little_r.f90
  ifort  -o madis_to_little_r.exe madis_to_little_r.o module_output.o -L. -lmadis -L${NETCDF_LIB} -lnetcdf


#####################################################################
# PGI
elif [[ $1 = pgf90 ]];then
  print "Compiling MADIS2LITTLER with $1\n"


  # Compile: it looks for madislib.a in ${MADIS_EXTERNAL}, libnetcdf.a in ${NETCDF_LIB}

  pgf90  -o da_advance_time.exe da_advance_time.f90
  pgf90  -c -Mfree module_output.F
  pgf90  -c madis_to_little_r.f90
  pgf90  -o madis_to_little_r.exe madis_to_little_r.o module_output.o -L. -lmadis -L${NETCDF_LIB} -lnetcdf


#####################################################################
# GFORTRAN
elif [[ $1 = gfortran ]];then
  print "Compiling MADIS2LITTLER with $1\n"


  # Compile: it looks for madislib.a in ${MADIS_EXTERNAL}, libnetcdf.a in ${NETCDF_LIB}

  gfortran  -o da_advance_time.exe da_advance_time.f90
  gfortran  -c -ffree-form module_output.F
  gfortran  -c madis_to_little_r.f90
  gfortran  -o madis_to_little_r.exe madis_to_little_r.o module_output.o -L. -lmadis -L${NETCDF_LIB} -lnetcdf
  

#####################################################################
# INVALID COMPILER SELECTED
else
  print "\nInvalid compiler specified: $1\n"
  print "Supported options: ifort, pgf90, gfortran\n"
fi



if [[ -e "madis_to_little_r.exe" ]];then
  print "Success!\n"
else
  print "Error: madis_to_little_r.exe not created\n"
fi




