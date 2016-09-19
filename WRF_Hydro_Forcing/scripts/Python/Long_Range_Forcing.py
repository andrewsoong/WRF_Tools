import WRF_Hydro_forcing as Whf
import WhfLog
import os
import sys
import datetime
import getopt
import DataFiles as df
from ConfigParser import SafeConfigParser
from ForcingEngineError import MissingFileError
from ForcingEngineError import MissingDirectoryError
from ForcingEngineError import NCLError  
from ForcingEngineError import SystemCommandError
from ForcingEngineError import FilenameMatchError

"""Long_Range_Forcing
Performs multi-step process of applying bias-correction to CFSv2 using
NLDAS cdf matching, combine the bias-corrected NetCDF files into one
NetCDF file which is then regridded to the conus IOC domain. A final
step of downscaling the data using high-resolution topography data
takes place.
"""

#-----------------------------------
# Logan Karsten
# National Center for Atmospheric Research
# Research Applications Laboratory
# karsten@ucar.edu
# 303-497-2693
#-----------------------------------

# Inputs to wrapper configuration are as follows:
# 1.) CFSv2 file 

def forcing(configFile,file_in):
    """ Args:
	1.) configFile (string): The config file with all 
	    the settings.
        2.) file (string): The file name. The full path is 
            not necessary as full paths will be derived from
            parameter directory paths and datetime information.
        Returns:
	None - Performs indicated bias correction, regridding,
               and downscaling of CFSv2 data. Any errors are
               trapped and passed back to the driver.
    """

    WhfLog.debug("file_in = %s", file_in)

    # Obtain CFSv2 forcing engine parameters.
    parser = SafeConfigParser()
    parser.read(configFile)

    # Set up logging environments, etc.
    forcing_config_label = "Long_Range"
    try:
        Whf.initial_setup(parser,forcing_config_label)
    except:
        raise

    out_dir = parser.get('layering','long_range_output') 
    tmp_dir = parser.get('bias_correction','CFS_tmp_dir')

    if (not df.makeDirIfNeeded(out_dir)):
        raise MissingDirectoryError('Dir %s cannot be created', out_dir)
    if (not df.makeDirIfNeeded(tmp_dir)):
        raise MissingDirectoryError('Dir %s cannot be created', tmp_dir)

    # Define CFSv2 cycle date and valid time based on file name.
    (cycleYYYYMMDD,cycleHH,fcsthr,em) = Whf.extract_file_info_cfs(file_in)
    em_str = str(em)

    # Pull path to NCL bias correction module file. Export this as an 
    # environmental variable NCL refers to later. 
    nclBiasMod = parser.get('exe','CFS_bias_correct_mod')
    os.environ["CFS_NCL_BIAS_MOD"] = nclBiasMod

    # Establish datetime objects
    dateCurrent = datetime.datetime.today()
    dateCycleYYYYMMDDHH = datetime.datetime(year=int(cycleYYYYMMDD[0:4]),
                          month=int(cycleYYYYMMDD[4:6]),
                          day=int(cycleYYYYMMDD[6:8]),
                          hour=cycleHH)
    dateFcstYYYYMMDDHH = dateCycleYYYYMMDDHH + \
                         datetime.timedelta(seconds=fcsthr*3600)

    # Determine if this is a 0hr forecast file or not.
    if dateFcstYYYYMMDDHH == dateCycleYYYYMMDDHH:
        fFlag = 1 
    else:
        fFlag = 0 
    # Establish final output directories to hold 'LDASIN' files used for
    # WRF-Hydro long-range forecasting. If the directory does not exist,
    # create it.
    out_path = out_dir + "/Member_" + em_str.zfill(2) + "/" + \
               dateCycleYYYYMMDDHH.strftime("%Y%m%d%H")

    try:
        Whf.mkdir_p(out_path)
    except:
        raise

    in_fcst_range = Whf.is_in_fcst_range("CFSv2",fcsthr,parser)

    if in_fcst_range:
        # First, bias-correct CFSv2 data and generate hourly files 
        # from six-hour forecast
        WhfLog.info("Bias correcting for CFSv2 cycle: " + \
                     dateCycleYYYYMMDDHH.strftime('%Y%m%d%H') + \
                     " CFSv2 forecast time: " + dateFcstYYYYMMDDHH.strftime('%Y%m%d%H'))
        try:
            Whf.bias_correction('CFSV2',file_in,dateCycleYYYYMMDDHH,
                                dateFcstYYYYMMDDHH,parser, em = em)
        except (MissingFileError,NCLError):
            raise

        # Second, regrid to the conus IOC domain
        # Loop through each hour in a six-hour CFSv2 forecast time step, compose temporary filename 
        # generated from bias-correction and call the regridding to go to the conus domain.
        if fFlag == 1:
            begCt = 6 
            endCt = 7
        else:
            begCt = 1
            endCt = 7
        for hour in range(begCt,endCt):
  	    dateTempYYYYMMDDHH = dateFcstYYYYMMDDHH - datetime.timedelta(seconds=(6-hour)*3600)
               
            fileBiasCorrected = tmp_dir + "/CFSv2_bias_corrected_TMP_" + \
                                dateCycleYYYYMMDDHH.strftime('%Y%m%d%H') + "_" + \
                                dateTempYYYYMMDDHH.strftime('%Y%m%d%H') + ".M" + \
                                em_str.zfill(2) + ".nc"
            WhfLog.info("Regridding CFSv2 to conus domain for cycle: " + \
                         dateCycleYYYYMMDDHH.strftime('%Y%m%d%H') + \
                         " forecast time: " + dateTempYYYYMMDDHH.strftime('%Y%m%d%H'))
            try:
                fileRegridded = Whf.regrid_data("CFSV2",fileBiasCorrected,parser)
            except (MissingFileError,NCLError):
                raise

            # Double check to make sure file was created, delete temporary bias-corrected file
            try:
                Whf.file_exists(fileRegridded)
            except MissingFileError:
                raise	
            cmd = "rm -rf " + fileBiasCorrected
            status = os.system(cmd)
            if status != 0:
		raise SystemCommandError('Command %s failed.'%cmd)

  
        # Third, perform topography downscaling to generate final
        # Loop through each hour in a six-hour CFSv2 forecast time step, compose temporary filename
        # generated from regridding and call the downscaling function.
        for hour in range(begCt,endCt):
            dateTempYYYYMMDDHH = dateFcstYYYYMMDDHH - datetime.timedelta(seconds=(6-hour)*3600)

            WhfLog.info("Downscaling CFSv2 for cycle: " +
                         dateCycleYYYYMMDDHH.strftime('%Y%m%d%H') +
                         " forecast time: " + dateTempYYYYMMDDHH.strftime('%Y%m%d%H'))
            fileRegridded = tmp_dir + "/CFSv2_bias_corrected_TMP_" + \
                            dateCycleYYYYMMDDHH.strftime('%Y%m%d%H') + "_" + \
                                dateTempYYYYMMDDHH.strftime('%Y%m%d%H') + \
                                "_regridded.M" + em_str.zfill(2) + ".nc"
            LDASIN_path_tmp = tmp_dir + "/" + dateTempYYYYMMDDHH.strftime('%Y%m%d%H') + "00.LDASIN_DOMAIN1.nc"
            LDASIN_path_final = out_path + "/" + dateTempYYYYMMDDHH.strftime('%Y%m%d%H') + "00.LDASIN_DOMAIN1"
            try:
                Whf.downscale_data("CFSv2",fileRegridded,parser, out_path=LDASIN_path_tmp, \
                                   verYYYYMMDDHH=dateTempYYYYMMDDHH)
            except (MissingFileError,FilenameMatchError,NCLError,SystemCommandError):
                raise
            # Double check to make sure file was created, delete temporary regridded file
            try:
                Whf.file_exists(LDASIN_path_tmp)
            except MissingFileError:
                raise
            # Rename file to conform to WRF-Hydro expectations
            cmd = "mv " + LDASIN_path_tmp + " " + LDASIN_path_final
            status = os.system(cmd)
            if status != 0:
                raise SystemCommandError('Command %s failed.'%cmd)
            try:
                Whf.file_exists(LDASIN_path_final)
            except MissingFileError:
                raise
            cmd = "rm -rf " + fileRegridded
            status = os.system(cmd)
            if status != 0:
                raise SystemCommandError('Command %s failed.'%cmd)
       
	WhfLog.info("Long_Range processing for %s%d Forecast Hour: %d Ensemble: %s",
                cycleYYYYMMDD, cycleHH, fcsthr, em_str)
    else:
        # Skip processing this file. Exit gracefully with a 0 exit status.
        WhfLog.info("Requested file is outside max fcst for CFSv2")

if __name__ == "__main__":
    forcing(sys.argv[1:])
