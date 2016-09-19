import WRF_Hydro_forcing as whf
import DataFiles as df
import WhfLog
import os
from ConfigParser import SafeConfigParser
import sys
import datetime
import getopt
import re
from ForcingEngineError import NCLError
from ForcingEngineError import MissingFileError
from ForcingEngineError import MissingDirectoryError
from ForcingEngineError import FilenameMatchError
from ForcingEngineError import UnrecognizedCommandError
from ForcingEngineError import SystemCommandError
from ForcingEngineError import InvalidArgumentError

"""Analysis_Assimilation_Forcing
Performs regridding and downscaling, then bias
correction, and layering/mixing of data products 
associated with the Analysis and Assimilation
forcing configuration.  Invokes methods in the
WRF_Hydro_forcing module and input parameters
that are defined in the wrf_hydro_forcing.parm
parameter/configuration file.  Logs to a log
file that is created in the same directory
from where this script is executed.  

"""


def forcing(config, action, prod, file):
    """Peforms the action on the given data
       product and corresponding input file.

       Args:
           config (string) : Config file name
           action (string):  Supported actions are:
                             'regrid' - regrid and downscale
           prod (string):  The first product [mandatory option]:
                            (MRMS, HRRR or RAP)
           file (string):  The file name (full path not necessary,
                            this is derived from the Python config/
                            param file and the YYYMMDD portion of 
                            the file name.

       Returns:
           None           Performs the indicated action on the
                          files based on the type of product and
                          any other relevant information provided
                          by the Python config/param file,
                          wrf_hydro_forcing.parm
 
 
    """

    # Read the parameters from the config/param file.
    parser = SafeConfigParser()
    parser.read(config)

    # Set up logging, environments, etc.
    forcing_config_label = "Anal_Assim"
    whf.initial_setup(parser,forcing_config_label)

    # Convert the action to lower case 
    # and the product name to upper case
    # for consistent checking
    action_requested = action.lower()
    product_data_name = prod.upper()
   
    # For analysis and assimilation, only 0hr, 3hr forecast fields from HRRR/RAP
    # are necessary. 3hr forecast files are already regridded and downscaled 
    # from the short-range configuration, so only 0hr forecast files are regridded/downscaled
    # here. In addition, MRMS data will be regridded, when available. 
    if action == 'regrid': 
        (date,modelrun,fcsthr) = whf.extract_file_info(file)
        # Usually check for forecast range, but only 0, 3 hr forecast/analysis data used
   
        # Check for HRRR, RAP, MRMS products. 
        WhfLog.info("Regridding and Downscaling for %s", product_data_name)

        if fcsthr == 0 and prod == "HRRR":
            downscale_dir = parser.get('downscaling', 'HRRR_downscale_output_dir_0hr')
            try:
                regridded_file = whf.regrid_data(product_data_name,file,parser,False, \
                                 zero_process=True)
            except (FilenameMatchError, NCLError ) as e:
                WhfLog.error("Unexpected filename format encountered while regridding 0hr HRRR")
                raise
            except NCLError:
                WhfLog.error("NCL error encountered while regridding 0hr HRRR")
                raise
            try:
                whf.downscale_data(product_data_name,regridded_file, parser,False, False, \
                                 zero_process=True)

            except (FilenameMatchError, NCLError ) as e:
                WhfLog.error("Unexpected filename format encountered while downscaling 0hr HRRR")
                raise
            except NCLError:
                WhfLog.error("NCL error encountered while downscaling 0hr HRRR")
                raise
      

            # Move downscaled file to staging area where triggering will monitor
            match = re.match(r'.*/([0-9]{10})/([0-9]{12}.LDASIN_DOMAIN1.nc)',regridded_file)
            if match:
                full_dir = downscale_dir + "/" + match.group(1)
                full_finished_file = full_dir + "/" + match.group(2)
                # File should have been created in downscale_data step.
                try:
                    whf.file_exists(full_finished_file)
                except UnrecognizedCommandError:
                    WhfLog.error("File move failed for regridded/downscaled 0hr HRRR , filename format unexpected")
                    raise
                try: 
                    whf.move_to_finished_area(parser, prod, full_finished_file, zero_move=True)
                except:
                    WhfLog.error('Unsupported/unrecognized command encountered while moving file to finished area.')
                    raise
            else:
                WhfLog.error("File name format is unexpected")
                raise FilenameMatchError("File name format is unexpected")
        elif fcsthr == 0 and prod == "RAP":
            downscale_dir = parser.get('downscaling', 'RAP_downscale_output_dir_0hr')
            try:
                regridded_file = whf.regrid_data(product_data_name,file,parser,False, \
                                 zero_process=True)
            except NCLError:
                WhfLog.error("NCL error while regridding 0hr RAP")
                raise
            except FilenameMatchError:
                WhfLog.error("Unexpected filename format encountered, cannot regrid 0hr RAP")
                raise

            try:
                whf.downscale_data(product_data_name,regridded_file, parser,False, False, \
                                   zero_process=True)
            except (NCLError) as e:
                WhfLog.error("NCL error encountered while regridding 0hr RAP")
                raise 

            # Move downscaled file to staging area where triggering will monitor
            match = re.match(r'.*/([0-9]{10})/([0-9]{12}.LDASIN_DOMAIN1.nc)',regridded_file)
            if match:
                full_dir = downscale_dir + "/" + match.group(1)
                full_finished_file = full_dir + "/" + match.group(2)
                # File should have been created in downscale_data step.
                try:
                    whf.file_exists(full_finished_file)
                except MissingFileError as mfe:
                    WhfLog.error("Missing file encountered while moving 0hr RAP file to staging area.")
                    raise 
                try:
                    whf.move_to_finished_area(parser, prod, full_finished_file, zero_move=True) 
                except UnrecognizedCommandError:
                    WhfLog.error("Unrecognized command error while trying to move 0hr RAP file to finished area")
                    raise
                except FilenameMatchError:
                    WhfLog.error("File name's format is unexpected.  Cannot move file to finished area")
                    raise
            else:
                WhfLog.error("File name's format is unexpected")
                raise FilenameMatchError('File name format is unexpected')
             
        elif prod == "MRMS":
            try:
                regridded_file = whf.regrid_data(product_data_name,file,parser,False)
            except NCLError:
                WhfLog.error("NCL error encountered while regridding MRMS")
                raise
            except FilenameMatchError:
                WhfLog.error("File name's format is unexpected, cannot regrid MRMS")
                raise
            # Move regridded file to staging area where triggering will monitor
            # First make sure file exists
            try:
                whf.file_exists(regridded_file)
            except MissingFileError as mfe:
                WhfLog.error("Missing file encountered while moving regridded MRMS file")
                raise
           
            try:
                whf.move_to_finished_area(parser, prod, regridded_file, zero_move=False)
            except UnrecognizedCommandError:
                WhfLog.error("Unrecognized command error while trying to move MRMS file to finished area")
                raise
            except FilenameMatchError:
                WhfLog.error("File name's format is unexpecte.  Cannot move file to finished area")
                raise
        else:
            WhfLog.error("Either invalid forecast hour or invalid product chosen")
            WhfLog.error("Only 00hr forecast files, and RAP or HRRR or MRMS are valid choices")
            raise InvalidArgumentError("Either invalid forecast hour %s or invalid product requested %s"%(fcsthr,prod))
    else: # Invalid action selected
        WhfLog.error("ERROR [Anal_Assim_Forcing]- Invalid action selected")
        raise UnrecognizedCommandError("Invalid action selection within Analysis and Assimilation regridding and downscaling")

def anal_assim_layer(cycleYYYYMMDDHH,fhr,action,config):
    """ Analysis and Assimilation layering
        Performs layering/combination of RAP/HRRR/MRMS
        data for a particular analysis and assimilation
        model cycle and forecast hour.

        Args:
            cycleYYYYMMDDHH (string): Analysis and assimilation
                                      model cycle date.
            fhr (string): Forecast hour of analysis and assimilation 
                          model cycle. Possible values are -2, -1, 0.
            action (string): Specifying which layering to do, given
                             possible available model data. Possible 
                             values are "RAP", "RAP_HRRR", and
                             "RAP_HRRR_MRMS".
            config (string) : Config file name
        Returns: 
            None: Performs specified layering to final input directory
                  used for WRF-Hydro.
    """

    # Determine specific layering route to take
    str_split = action.split("_")
    process = len(str_split)

    # Determine specific date/time information used for composing regridded
    # file paths. 
    yearCycle = int(cycleYYYYMMDDHH[0:4])
    monthCycle = int(cycleYYYYMMDDHH[4:6])
    dayCycle = int(cycleYYYYMMDDHH[6:8])
    hourCycle = int(cycleYYYYMMDDHH[8:10])
    fhr = int(fhr)
 
    dateCurrent = datetime.datetime.today()  
    cycleDate = datetime.datetime(year=yearCycle,month=monthCycle,day=dayCycle, \
                hour=hourCycle)
    validDate = cycleDate + datetime.timedelta(seconds=fhr*3600)
    fcstWindowDate = validDate + datetime.timedelta(seconds=-3*3600) # Used for 3-hr forecast

    # HRRR/RAP files necessary for fluxes and precipitation data.
    # Obtain analysis and assimiltation configuration parameters.
    parser = SafeConfigParser()
    parser.read(config)
    out_dir = parser.get('layering','analysis_assimilation_output')
    tmp_dir = parser.get('layering','analysis_assimilation_tmp')
    qpe_parm_dir = parser.get('layering','qpe_combine_parm_dir')
    hrrr_ds_dir_3hr = parser.get('downscaling','HRRR_finished_output_dir')
    hrrr_ds_dir_0hr = parser.get('downscaling','HRRR_finished_output_dir_0hr')
    rap_ds_dir_3hr = parser.get('downscaling','RAP_finished_output_dir')
    rap_ds_dir_0hr = parser.get('downscaling','RAP_finished_output_dir_0hr')
    mrms_ds_dir = parser.get('regridding','MRMS_finished_output_dir')
    layer_exe = parser.get('exe','Analysis_Assimilation_layering')
    ncl_exec = parser.get('exe', 'ncl_exe')

    # in case it is first time, create the output dirs
    df.makeDirIfNeeded(out_dir)
    df.makeDirIfNeeded(tmp_dir)

    # Sanity checking
    try:
        whf.dir_exists(out_dir)
        whf.dir_exists(tmp_dir)
        whf.dir_exists(qpe_parm_dir)
        whf.dir_exists(hrrr_ds_dir_3hr)
        whf.dir_exists(hrrr_ds_dir_0hr)
        whf.dir_exists(rap_ds_dir_3hr)
        whf.dir_exists(rap_ds_dir_0hr)
        whf.dir_exists(mrms_ds_dir)
        whf.file_exists(layer_exe)
    except MissingDirectoryError:
        WhfLog.error("Missing directory during preliminary checking of Analysis Assimilation layering")
        raise
    

    # Establish final output directories to hold 'LDASIN' files used for
    # WRF-Hydro long-range forecasting. If the directory does not exist,
    # create it.
    out_path = out_dir + "/" + cycleDate.strftime("%Y%m%d%H")

    whf.mkdir_p(out_path)

    # Compose necessary file paths  
    hrrr0Path = hrrr_ds_dir_0hr + "/" + validDate.strftime("%Y%m%d%H") + \
                "/" + validDate.strftime("%Y%m%d%H") + "00.LDASIN_DOMAIN1.nc"
    hrrr3Path = hrrr_ds_dir_3hr + "/" + fcstWindowDate.strftime("%Y%m%d%H") + \
                "/" + validDate.strftime("%Y%m%d%H") + "00.LDASIN_DOMAIN1.nc"     
    rap0Path = rap_ds_dir_0hr + "/" + validDate.strftime("%Y%m%d%H") + \
                "/" + validDate.strftime("%Y%m%d%H") + "00.LDASIN_DOMAIN1.nc"
    rap3Path = rap_ds_dir_3hr + "/" + fcstWindowDate.strftime("%Y%m%d%H") + \
                "/" + validDate.strftime("%Y%m%d%H") + "00.LDASIN_DOMAIN1.nc"
    mrmsPath = mrms_ds_dir + "/" + validDate.strftime("%Y%m%d%H") + \
                "/" + validDate.strftime("%Y%m%d%H") + "00.LDASIN_DOMAIN1.nc"
    hrrrBiasPath = qpe_parm_dir + "/HRRR_NLDAS-CPC_bias-corr_m" + \
                   validDate.strftime("%m") + "_v9_wrf1km.grb2"
    hrrrWgtPath = qpe_parm_dir + "/HRRR_wgt_m" + \
                  validDate.strftime("%m") + "_v8_wrf1km.grb2"
    mrmsBiasPath = qpe_parm_dir + "/MRMS_radonly_NLDAS-CPC_bias-corr_m" + \
                   validDate.strftime("%m") + "_v9_wrf1km-sm60.grb2"
    mrmsWgtPath = qpe_parm_dir + "/MRMS_radonly_wgt_m" + \
                  validDate.strftime("%m") + "_v8_wrf1km.grb2"
    rapBiasPath = qpe_parm_dir + "/RAPD_NLDAS-CPC_bias-corr_m" + \
                  validDate.strftime("%m") + "_v9_wrf1km.grb2"
    rapWgtPath = qpe_parm_dir + "/RAPD_wgt_m" + \
                 validDate.strftime("%m") + "_v8_wrf1km.grb2"

    # Sanity checking on parameter data
    try:
        whf.file_exists(hrrrBiasPath)
        whf.file_exists(hrrrWgtPath)
        whf.file_exists(mrmsBiasPath)
        whf.file_exists(mrmsWgtPath)
        whf.file_exists(rapBiasPath)
        whf.file_exists(rapWgtPath) 
    except MissingFileError:
        WhfLog.error("Missing file encountered while checking parameter data for AA")
        raise


    # Compose output file paths
    LDASIN_path_tmp = tmp_dir + "/" + validDate.strftime('%Y%m%d%H') + "00.LDASIN_DOMAIN1_TMP.nc"
    LDASIN_path_final = out_path + "/" + validDate.strftime('%Y%m%d%H') + "00.LDASIN_DOMAIN1"
    # Perform layering/combining depending on processing path.
    if process == 1:    # RAP only
        WhfLog.info("Layering and Combining RAP only for cycle date: " + \
                     cycleDate.strftime("%Y%m%d%H") + " valid date: " + \
                     validDate.strftime("%Y%m%d%H"))
        # Check for existence of input files
        try:
            whf.file_exists(rap0Path)
            whf.file_exists(rap3Path)
        except MissingFileError :
            WhfLog.error("Missing RAP files for layering")
            raise
            
    elif process == 2:  # HRRR and RAP only 
        WhfLog.info("Layering and Combining RAP and HRRR for cycle date: " + \
                     cycleDate.strftime("%Y%m%d%H") + " valid date: " + \
                     validDate.strftime("%Y%m%d%H"))
        # Check for existence of input files
        try:
            whf.file_exists(rap0Path)
            whf.file_exists(rap3Path)
            whf.file_exists(hrrr0Path)
            whf.file_exists(hrrr3Path)
        except MissingFileError:
            WhfLog.error("Missing RAP or HRRR files for layering")
            raise
    elif process == 3:  # HRRR, RAP, and MRMS
        WhfLog.info("Layering and Combining RAP/HRRR/MRMS for cycle date: " + \
                     cycleDate.strftime("%Y%m%d%H") + " valid date: " + \
                     validDate.strftime("%Y%m%d%H"))
        # Check for existence of input files
        try:
            whf.file_exists(rap0Path)
            whf.file_exists(rap3Path)
            whf.file_exists(hrrr0Path)
            whf.file_exists(hrrr3Path)
            whf.file_exists(mrmsPath)
        except MissingFileError:
            WhfLog.error("Missing RAP or HRRR or MRMS files for layering")
            raise
           
    else:  # Error out
        WhfLog.error("Invalid input action selected, invalid layer combination provided in AA.")
        raise UnrecognizedCommandError

    hrrrB_param = "'hrrrBFile=" + '"' + hrrrBiasPath + '"' + "' "
    mrmsB_param = "'mrmsBFile=" + '"' + mrmsBiasPath + '"' + "' "
    rapB_param = "'rapBFile=" + '"' + rapBiasPath + '"' + "' "
    hrrrW_param = "'hrrrWFile=" + '"' + hrrrWgtPath + '"' + "' "
    mrmsW_param = "'mrmsWFile=" + '"' + mrmsWgtPath + '"' + "' "
    rapW_param = "'rapWFile=" + '"' + rapWgtPath + '"' + "' "
    hrrr0_param = "'hrrr0File=" + '"' + hrrr0Path + '"' + "' "
    hrrr3_param = "'hrrr3File=" + '"' + hrrr3Path + '"' + "' "
    rap0_param = "'rap0File=" + '"' + rap0Path + '"' + "' "
    rap3_param = "'rap3File=" + '"' + rap3Path + '"' + "' "
    mrms_param = "'mrmsFile=" + '"' + mrmsPath + '"' + "' "
    process_param = "'process=" + '"' + str(process) + '"' + "' "
    out_param = "'outPath=" + '"' + LDASIN_path_tmp + '"' + "' "
     
    cmd_params = hrrrB_param + mrmsB_param + rapB_param + \
                 hrrrW_param + mrmsW_param + rapW_param + \
                 hrrr0_param + hrrr3_param + rap0_param + rap3_param + \
                 mrms_param + process_param + out_param
    cmd = ncl_exec + " -Q " + cmd_params + " " + layer_exe
    status = os.system(cmd)

    if status != 0:
        WhfLog.error("Error in combinining NCL program")
        raise NCLError("NCL error encountered while combining in AA")
   
    # Double check to make sure file was created, delete temporary regridded file
    whf.file_exists(LDASIN_path_tmp)
    # Rename file to conform to WRF-Hydro expectations
    cmd = "mv " + LDASIN_path_tmp + " " + LDASIN_path_final
    status = os.system(cmd)
    if status != 0:
        WhfLog.error("Failure to rename " + LDASIN_path_tmp)
    try:
        whf.file_exists(LDASIN_path_final)
    except MissingFileError:
        WhfLog.error("Missing LDASIN_path_final file")
        raise
    cmd = "rm -rf " + LDASIN_path_tmp 
    status = os.system(cmd)
    if status != 0:
        WhfLog.error("Failure to remove " + LDASIN_path_tmp)
        raise SystemCommandError

if __name__ == "__main__":
    forcing()
