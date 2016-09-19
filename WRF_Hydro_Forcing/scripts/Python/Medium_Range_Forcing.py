import WRF_Hydro_forcing as whf
import WhfLog
import os
import sys
from ConfigParser import SafeConfigParser
import optparse
import re
from ForcingEngineError import FilenameMatchError
from ForcingEngineError import SystemCommandError
from ForcingEngineError import MissingFileError
from ForcingEngineError import NCLError

"""Medium_Range_Forcing
Performs regridding,downscaling, bias
correction (if needed), and layering/mixing 
of data products associated with the Medium Range
forcing configuration.  Invokes methods in the
WRF_Hydro_forcing module and input parameters
that are defined in the wrf_hydro_forcing.parm
parameter/configuration file.  Logs to a log
file that is created in the same directory
from where this script is executed.

"""
def forcing(configFile, action, prod, file, prod2=None, file2=None):
    """Peforms the action on the given data
       product and corresponding input file.

       Args:
           configFile (string): name of file with settings
           action (string):  Supported actions are:
                             'regrid' - regrid and downscale
                             'bias'   - bias correction 
                                        (requires two 
                                        products and two files)
                             'layer'  - layer (requires two
                                        products and two files)
           prod (string):  The first product [mandatory option]:
                            (GFS)
           file (string):  The file name (full path not necessary,
                            this is derived from the Python config/
                            param file and the YYYMMDD portion of 
                            the file name.

          prod2 (string):   The second product (????), default
                            is None. Required for layering.
          file2 (string):   The second file name, required for 
                            layering, default is None.
       Returns:
           None           Performs the indicated action on the
                          files based on the type of product and
                          any other relevant information provided
                          by the Python config/param file,
                          wrf_hydro_forcing.parm
 
 
    """


    # Read the parameters from the config/param file.
    parser = SafeConfigParser()
    try:
        parser.read(configFile)
    except (NoSectionErrorException, DuplicateSectionErrorException,\
            DuplicateOptionErrorException,MissingSectionHeaderErrorException,\
            ParsingErrorException) as e:
        raise

    # Set up logging, environments, etc.
    forcing_config_label = 'Medium_Range'
    whf.initial_setup(parser,forcing_config_label)


    # Extract the date, model run time, and forecast hour from the file name
    # Use the fcsthr to process only the files that have a fcst hour less than
    # the max fcst hr defined in the param/config file.
    
    
    # Convert the action to lower case 
    # and the product name to upper case
    # for consistent checking
    action_requested = action.lower()
    product_data_name = prod.upper()
    regridded_dir = parser.get('regridding','GFS_output_dir')
    downscale_dir = parser.get('downscaling','GFS_downscale_output_dir')
    finished_downscale_dir = parser.get('downscaling','GFS_finished_output_dir')
    final_dir = parser.get('layering','medium_range_output')
    if action == 'regrid': 
        (date,modelrun,fcsthr) = whf.extract_file_info(file)
        # Determine whether this current file lies within the forecast range
        # for the data product (e.g. if processing RAP, use only the 0hr-18hr forecasts).
        # Skip if this file has a forecast hour greater than the max indicated in the 
        # parm/config file.
        in_fcst_range = whf.is_in_fcst_range(prod, fcsthr, parser)

        if in_fcst_range:
            # Check for RAP or GFS data products.  If this file is
            # a 0 hr fcst and is RAP or GFS, substitute each 0hr forecast
            # with the file from the previous model run and the same valid
            # time.  This is necessary because there are missing variables
            # in the 0hr forecasts (e.g. precip rate for RAP and radiation
            # in GFS).
 
            WhfLog.info("Regridding and Downscaling for %s", product_data_name)
            # Determine if this is a 0hr forecast for RAP data (GFS is also missing
            # some variables for 0hr forecast, but GFS is not used for Medium Range
            # forcing). We will need to substitute this file for the downscaled
            # file from a previous model run with the same valid time.  
            # We only need to do this for downscaled files, as the Medium Range 
            # forcing files that are regridded always get downscaled and we don't want
            # to do this for both the regridding and downscaling.
            if fcsthr == 0 and prod == 'GFS':
                WhfLog.info("Regridding (ignoring f0 GFS files) %s: ", file )
                try:
                    regridded_file = whf.regrid_data(product_data_name, file, parser, True)
                except (FilenameMatchError,NCLError,MissingFileError) as e:
                    WhfLog.error('Failure:regridding of GFS (ignore 0hr fcst) file: ' + file)
                    WhfLog.error(e) 
                    raise
                try:
                    whf.downscale_data(product_data_name,regridded_file, parser, True, True)                
                except (MissingFileError, SystemCommandError,\
                        NCLError) as e:
                    WhfLog.error('Downscaling GFS failed: ' + e)
                    raise

                match = re.match(r'.*/([0-9]{10})/([0-9]{12}.LDASIN_DOMAIN1.nc)',regridded_file)
                if match:
                    ymd_dir = match.group(1)
                    file_only = match.group(2)
                    downscaled_dir = downscale_dir + "/" + ymd_dir
                    downscaled_file = downscaled_dir + "/" + file_only
                    # Check to make sure downscaled file was created
                    try:
                        whf.file_exists(downscaled_file)
                    except MissingFileError as mfe:
                        WhfLog.error('Downscaling, non-existent downscaled file: ' + downscaled_file)
                        WhfLog.error(mfe)
                    try:
                        whf.rename_final_files(parser,"Medium_Range")
                    except FilenameMatchError as fme:
                        WhfLog.error('Failed to rename final files due to unexpected filename format: ' + fme) 
              
                    except UnrecognizedCommandError as uce:
                        WhfLog.error('Failed to rename final files due to unrecognized/unsupported request: ' + uce)
                else:
                    raise FilneameMatchError('MediumRangeForcing regridded_file %s has unexpected filename format'%regridded_file)
                # Remove empty 0hr regridded file if it still exists
                if os.path.exists(regridded_file):
                    cmd = 'rm -rf ' + regridded_file
                    status = os.system(cmd)
                    if status != 0:
                        WhfLog.error("Failure to remove empty file: " + regridded_file)
                        raise SystemCommandError('MediumRangeForcing failed to clean up regridded file %s'%(regridded_file))
            else:
                WhfLog.info("Regridding non-zero hour fcst%s: ", file )
                try:
                    regridded_file = whf.regrid_data(product_data_name, file, parser, False)
                except (FilenameMatchError, NCLError) as e:
                    WhfLog.error('Regridding failed for GFS non-zero fcst regrid file: ' + file) 
                    raise
          
                try:
                    whf.downscale_data(product_data_name,regridded_file, parser,True, False)                
                except (MissingFileError, SystemCommandError, NCLError):
                    raise

                match = re.match(r'.*/([0-9]{10})/([0-9]{12}.LDASIN_DOMAIN1.nc)',regridded_file)
                if match:
                    ymd_dir = match.group(1)
                    file_only = match.group(2)
                    downscaled_dir = downscale_dir + "/" + ymd_dir
                    downscaled_file = downscaled_dir + "/" + file_only
                    # Check to make sure downscaled file was created
                    try:
                        whf.file_exists(downscaled_file)
                    except MissingFileError:
                        raise
                    try:
                        whf.rename_final_files(parser,"Medium_Range")
                    except (FilenameMatchError, UnrecognizedCommandError) as e:
                        raise

                else:
                    raise FilenameMatchError('MediumRangeForcing renaming finished file failed, unexpected filename format for %s'%(regridded_file)) 
        else:
            # Skip processing this file, exiting...
            WhfLog.info("Skip processing, requested file is outside max fcst")
    else:
        WhfLog.info("Unsupported action requested. Only regridding (and downscaling) performed for Medium Range")

            


 
        
#--------------------------    
    
   
if __name__ == "__main__":
    forcing()
    

