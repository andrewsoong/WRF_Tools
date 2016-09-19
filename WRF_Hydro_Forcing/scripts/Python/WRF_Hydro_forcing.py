import os
import errno
import WhfLog
import re
import time
import optparse
import datetime
import shutil
import sys
from ConfigParser import SafeConfigParser
import DataFiles as df
import NCL_script_run as ncl
from ForcingEngineError import NCLError
from ForcingEngineError import FilenameMatchError
from ForcingEngineError import MissingDirectoryError
from ForcingEngineError import MissingFileError
from ForcingEngineError import ZeroHourReplacementError
from ForcingEngineError import UnrecognizedCommandError


# -----------------------------------------------------
#             WRF_Hydro_forcing.py
# -----------------------------------------------------

#  Overview:
#  This is a forcing engine for WRF Hydro. It serves as a wrapper
#  to the regridding and other processing scripts written in NCL.  
#  This script was created to conform with NCEP Central Operations
#  WCOSS implementation standards and as part of the workflow for
#  operating at the National Water Center (NWC).  Input variables 
#  to the NCL scripts are defined in a parm/config file: 
#  wrf_hydro_forcing.parm to reduce the requirement to set environment
#  variables for input file directories, output file directories,
#  etc. which are not always conducive in an operational setting.



def regrid_data( product_name, file_to_regrid, parser, substitute_fcst = False, \
                 zero_process = False):
    """Provides a wrapper to the regridding scripts originally
    written in NCL.  For HRRR data regridding, the
    HRRR-2-WRF_Hydro_ESMF_forcing.ncl script is invoked.
    For MRMS data MRMS-2-WRF_Hydro_ESMF_forcing.ncl is invoked.
    The appropriate regridding script is invoked for the file 
    to regrid.  The regridded file is stored in an output directory
    defined in the parm/config file.

    Args:
        product_name (string):  The name of the product 
                                e.g. HRRR, MRMS, NAM
        file_to_regrid (string): The filename of the
                                  input data to process.
        parser (ConfigParser):  The parser to the config/parm
                                file containing all defined values
                                necessary for running the regridding.
        substitute_fcst (bool):  Default = False If this is a 0 hr
                               forecast file, then skip regridding,
                               it will need to be replaced with
                               another file during the 
                               downscale_data() step.
        zero_process (bool): Optional argument used in analysis and
                             assimilation. It's used to indicate regridding
                             of 00hr forecast files, which do not regrid
                             fluxes and precipitation as they aren't in 
                             the files. 
    Returns:
        regridded_output (string): The full filepath and filename
                                   of the regridded file.  If the data
                                   product is GFS or RAP and it is the
                                   fcst 0hr file, then just create an
                                   empty file that follows the naming
                                   convention of a regridded file.

    """

    # Retrieve the values from the parm/config file
    # which are needed to invoke the regridding 
    # scripts.
    product = product_name.upper()
    ncl_exec = parser.get('exe', 'ncl_exe')

    if product == 'HRRR':
       wgt_file = parser.get('regridding', 'HRRR_wgt_bilinear')
       data_dir =  parser.get('data_dir', 'HRRR_data')
       regridding_exec = parser.get('exe', 'HRRR_regridding_exe')
       regridding_exec_0hr = parser.get('exe','HRRR_regridding_exe_0hr')
       #Values needed for running the regridding script
       output_dir_root = parser.get('regridding','HRRR_output_dir')
       output_dir_root_0hr = parser.get('regridding','HRRR_output_dir_0hr')
       dst_grid_name = parser.get('regridding','HRRR_dst_grid_name')
    elif product == 'MRMS':
       wgt_file = parser.get('regridding', 'MRMS_wgt_bilinear')
       data_dir =  parser.get('data_dir', 'MRMS_data')
       regridding_exec = parser.get('exe', 'MRMS_regridding_exe')
       #data_files_to_process = get_filepaths(data_dir)   
       #Values needed for running the regridding script
       output_dir_root = parser.get('regridding','MRMS_output_dir')
       dst_grid_name = parser.get('regridding','MRMS_dst_grid_name')
    elif product == 'GFS':
       wgt_file = parser.get('regridding', 'GFS_wgt_bilinear')
       data_dir =  parser.get('data_dir', 'GFS_data')
       regridding_exec = parser.get('exe', 'GFS_regridding_exe')
       #Values needed for running the regridding script
       output_dir_root = parser.get('regridding','GFS_output_dir')
       dst_grid_name = parser.get('regridding','GFS_dst_grid_name')
    elif product == 'RAP':
       wgt_file = parser.get('regridding', 'RAP_wgt_bilinear')
       data_dir =  parser.get('data_dir', 'RAP_data')
       regridding_exec = parser.get('exe', 'RAP_regridding_exe')
       regridding_exec_0hr = parser.get('exe','RAP_regridding_exe_0hr')
       #Values needed for running the regridding script
       output_dir_root = parser.get('regridding','RAP_output_dir')
       output_dir_root_0hr = parser.get('regridding','RAP_output_dir_0hr')
       dst_grid_name = parser.get('regridding','RAP_dst_grid_name')
    elif product == 'CFSV2':
       wgt_file = parser.get('regridding','CFS_wgt_bilinear')
       tmp_dir = parser.get('bias_correction','CFS_tmp_dir')
       regridding_exec = parser.get('exe','CFS_regridding_exe')
       dst_grid_name = parser.get('regridding','CFS_dst_grid_name')
       # Sanity check to make sure files/directories exist.
       file_exists(wgt_file)
       # Don't need to check temporary directory as this was done
       # in bias-correction step.
       try:
           file_exists(regridding_exec)
           file_exists(dst_grid_name)
       except MissingFileError as mfe:
           raise

    # If this is a 0hr forecast and the data product is either GFS or RAP, then do
    # nothing for now, it will need to be replaced during the
    # downscaling step.
    if substitute_fcst:
        try:
            (date,model,fcsthr) = extract_file_info(file_to_regrid)  
            data_file_to_regrid= data_dir + "/" + date + "/" + file_to_regrid 
        except FilenameMatchError as fme:
            # pass this exception up to the code that called it, so the
            # decision can be made by the original caller.
            raise
        (subdir_file_path,hydro_filename) = \
            create_output_name_and_subdir(product,data_file_to_regrid,data_dir)
        output_file_dir = output_dir_root + "/" + subdir_file_path
        if not os.path.exists(output_file_dir):
            mkdir_p(output_file_dir)
        outdir_param = "'outdir=" + '"' + output_file_dir + '"' + "' " 
        regridded_file = output_file_dir + "/" +  hydro_filename
        # Create an empty f0 file for now.
        with open(regridded_file,'a'):
            os.utime(regridded_file,None)
        return regridded_file  
        
    else:

        # Generate the key-value pairs for 
        # input to the regridding script.
        # The key-value pairs for the input should look like: 
        #  'srcfilename="/d4/hydro-dm/IOC/data/HRRR/20150723_i23_f010_HRRR.grb2"' 
        #  'wgtFileName_in=
        #     "d4/hydro-dm/IOC/weighting/HRRR1km/HRRR2HYDRO_d01_weight_bilinear.nc"'
        #  'dstGridName="/d4/hydro-dm/IOC/data/geo_dst.nc"' 
        #  'outdir="/d4/hydro-dm/IOC/regridded/HRRR/2015072309"'
        #  'outFile="201507241900.LDASIN_DOMAIN1.nc"' 
       
        if product == "CFSV2":
            # Check for existence of input file.
            try:
                file_exists(file_to_regrid)
            except MissingFileError as mfe:
                # re-throw up the call stack, the original
                # caller decides what should be done.
                raise
            
            path_split = file_to_regrid.split('.')
            # Compose output file name, which will be in temporary directory. 
            regridded_file = path_split[0] + "_regridded." + path_split[1] + \
                             "." + path_split[2]
            srcfilename_param =  "'srcfilename=" + '"' + file_to_regrid +  \
                                 '"' + "' "
            wgtFileName_in_param =  "'wgtFileName=" + '"' + wgt_file + \
                                    '"' + "' "
            dstGridName_param =  "'dstGridName=" + '"' + dst_grid_name + '"' + "' "
            outfilename_param = "'outfilename=" + '"' + regridded_file + \
                                '"' + "' "

            regrid_params = srcfilename_param + outfilename_param + \
                            dstGridName_param + wgtFileName_in_param
        else:
       	    (date,model,fcsthr) = extract_file_info(file_to_regrid)  
            data_file_to_regrid= data_dir + "/" + date + "/" + file_to_regrid 
            srcfilename_param =  "'srcfilename=" + '"' + data_file_to_regrid +  \
                                     '"' + "' "
            wgtFileName_in_param =  "'wgtFileName_in=" + '"' + wgt_file + \
                                        '"' + "' "
            dstGridName_param =  "'dstGridName=" + '"' + dst_grid_name + '"' + "' "
   
            # Create the output filename following the 
            # naming convention for the WRF-Hydro model 
            try:
                (subdir_file_path,hydro_filename) = \
                create_output_name_and_subdir(product,data_file_to_regrid,data_dir)
            except FilenameMatchError:
                raise
       
            # Create the full path to the output directory
            # and assign it to the output directory parameter
            if zero_process == True:
                output_file_dir = output_dir_root_0hr + "/" + subdir_file_path
            else: 
                output_file_dir = output_dir_root + "/" + subdir_file_path
 
            mkdir_p(output_file_dir)
            outdir_param = "'outdir=" + '"' + output_file_dir + '"' + "' " 
            regridded_file = output_file_dir + "/" + hydro_filename

            if product == "HRRR" or product == "NAM" \
               or product == "GFS" or product == "RAP":
               full_output_file = output_file_dir + "/"  
               # Create the new output file subdirectory
               outFile_param = "'outFile=" + '"' + hydro_filename+ '"' + "' "
            elif product == "MRMS":
               # !!!!!!NOTE!!!!!
               # MRMS regridding script differs from the HRRR and NAM scripts in that 
               # it does not accept an outdir variable.  Incorporate the output
               # directory (outdir) into the outFile variable.
               full_output_file = output_file_dir + "/"  + hydro_filename
               mkdir_p(output_file_dir)
               outFile_param = "'outFile=" + '"' + full_output_file + '"' + "' "

            regrid_params = srcfilename_param + wgtFileName_in_param + \
                        dstGridName_param + outdir_param + \
                        outFile_param
      
        if zero_process == True:
            regrid_prod_cmd = ncl_exec + " -Q "  + regrid_params + " " + \
                              regridding_exec_0hr
        else:
            regrid_prod_cmd = ncl_exec + " -Q "  + regrid_params + " " + \
                              regridding_exec
    
        WhfLog.debug("regridding command: %s",regrid_prod_cmd)

        # Measure how long it takes to run the NCL script for regridding.
        start_NCL_regridding = time.time()
        return_value = ncl.run(regrid_prod_cmd)
        end_NCL_regridding = time.time()
        elapsed_time_sec = end_NCL_regridding - start_NCL_regridding
        WhfLog.info("Time(sec) to regrid file  %s" %  elapsed_time_sec)
        
        if return_value != 0:
            WhfLog.error('The regridding of %s was unsuccessful, \
                          return value of %d', product,return_value)

            raise NCLError('NCL regridding of %s unsuccessful with return value %s'%(product,return_value))
    return regridded_file

def get_filepaths(dir):
    """Generates the file names in a directory tree
       by walking the tree either top-down or bottom-up.
       For each directory in the tree rooted at 
       the directory top (including top itself), it
       produces a 3-tuple: (dirpath, dirnames, filenames).
    
    Args:
        dir (string): The base directory from which we 
                      begin the search for filenames.
    Returns:
        file_paths (list): A list of the full filepaths 
                           of the data to be processed.

        
    """

    # Create an empty list which will eventually store 
    # all the full filenames
    file_paths = []

    # Walk the tree
    for root, directories, files in os.walk(dir):
        for filename in files:
            # add it to the list only if it is a grib file
            match = re.match(r'.*(grib|grb|grib2|grb2)$',filename)
            if match:
                # Join the two strings to form the full
                # filepath.
                filepath = os.path.join(root,filename)
                file_paths.append(filepath)
            else:
                continue
    return file_paths


    
def create_output_name_and_subdir(product, filename, input_data_file):
    """Creates the full filename for the regridded data which ties-in
       to the WRF-Hydro Model expected input: 
       (WRF-Hydro Model) basedir/<product>/YYYYMMDDHH/YYMMDDhh00_LDASIN_DOMAIN1.nc
       Where the HH is the model run time/init time in hours
       hh00 is the valid time in hours and 00 minutes and <product> is the
       name of the model/data product:  e.g. HRRR, NAM, MRMS, GFS, etc.
       The valid time is the sum of the model run time (aka init time) and the
       forecast time (fnnnn) in hours.  If the valid time exceeds 24 hours, the
       YYYYMMDD is incremented appropriately to reflect how many days into the
       future the valid time represents.

    Args:
        product (string):  The product name: HRRR, MRMS, or NAM.

        filename (string): The name of the input data file:
                           YYYYMMDD_ihh_fnnn_product.grb

        input_data_file (string):  The full path and name
                                  of the (input) data 
                                  files:
                                  /d4/hydro-dm/IOC/data/product/...
                                  This is used to create the output
                                  data dir and filename from the
                                  datetime, init, and forecast
                                  portions of the filename.

        output_dir_root (string): The root directory for output:
                                  /d4/hydro-dm/IOC/regridded/<product>
                                  Used to create the full path.

    Returns:
        
        year_month_day_subdir (string): The subdirectory under which the 
                                        processed files will be stored:
                                        YYYYMMDDHH/
                                        HH= model run hour

        hydro_filename (string):  The name of the processed output
                                  file:YYYYMMDDhh00.LDASIN_DOMAIN1      
                                  where hh is the valid time adjusted
                                  for 24-hour time.  Valid time is the
                                  sum of the fcst hour and the model 
                                  run (init time).
 
    """

    # Convert product to uppercase for easy, consistent 
    # comparison.
    product_name = product.upper() 

    if product == 'HRRR' or product == 'GFS' \
       or product == "NAM" or product == 'RAP':
        match =  re.match(r'.*/([0-9]{8})_i([0-9]{2})_f([0-9]{3,4}).*',filename)
        if match:
            year_month_day = match.group(1)
            init_hr = int(match.group(2))
            fcst_hr = int(match.group(3))
            valid_time = fcst_hr + init_hr
            init_hr_str = (str(init_hr)).rjust(2,'0')
            year_month_day_subdir = year_month_day + init_hr_str
        else:
            WhfLog.error("%s has an unexpected name." ,filename) 
            raise FilenameMatchError('%s has unexpected filename format'%filename)
 
    elif product == 'MRMS':
        match = re.match(r'.*([0-9]{8})_([0-9]{2}).*',filename) 
        if match:
           year_month_day = match.group(1)
           init_hr =  match.group(2)

           # Radar data- not a model, therefore no forecast
           # therefore valid time is the init time
           valid_time = int(init_hr)
           year_month_day_subdir = year_month_day + init_hr 
        else:
           WhfLog.error("MRMS data filename %s has an unexpected file name.",\
                        filename) 
           raise FilenameMatchError('%s has unexpected filename format'%filename)

   
    if valid_time >= 24:
        num_days_ahead =  valid_time/24
        # valid time in 24 hour time
        valid_time_str =  str(valid_time%24)
        valid_time_corr = valid_time_str.rjust(2,'0')
        updated_date = get_past_or_future_date(year_month_day, num_days_ahead)
        # Assemble the filename and the full output directory path
        hydro_filename = updated_date + valid_time_corr + "00.LDASIN_DOMAIN1.nc" 
    else:
        # Assemble the filename and the full output directory path
        valid_time_str = (str(valid_time)).rjust(2,'0')
        hydro_filename = year_month_day + valid_time_str + "00.LDASIN_DOMAIN1.nc" 

    return (year_month_day_subdir, hydro_filename)




def mkdir_p(dir):
    """Provides mkdir -p functionality.
    
       Args:
          dir (string):  Full directory path to be created if it
                         doesn't exist.
       Returns:
          None:  Creates nested subdirs if they don't already 
                 exist.

    """
    try:
       os.makedirs(dir)
    except OSError as exc:
        if exc.errno == errno.EEXIST and os.path.isdir(dir):
            pass
        else:
            raise            


def downscale_data(product_name, file_to_downscale, parser, downscale_shortwave=False,
                   substitute_fcst=False,out_path='./',verYYYYMMDDHH='1900010100', \
                   zero_process = False):
    """Performs downscaling of data by calling the necessary
    NCL code (specific to the model/product).  There is an
    additional option to downscale the short wave radiation, SWDOWN.  
    If downscaling SWDOWN (shortwave radiation) is requested  
    then a second NCL script is invoked (topo_adj.ncl).  This second 
    NCL script invokes a Fortran application (topo_adjf90.so, 
    built from topo_adj.f90). 

    NOTE:  If the additional downscaling
    (of shortwave radiation) is requested, the adj_topo.ncl script
    will "clobber" the previously created downscaled files.


    Args:
        product_name (string):  The product name: ie HRRR, NAM, GFS, etc. 
      
        file_to_downscale (string): The file to be downscaled, this is 
                                 the full file path to the regridded
                                 file.

        parser (ConfigParser) : The ConfigParser which can access the
                                Python config file wrf_hydro_forcing.parm
                                and retrieve the file names and locations
                                of input.

        downscale_shortwave (boolean) : 'True' if downscaling of 
                                shortwave radiation (SWDOWN) is 
                                requested; invoke topo_adj.ncl, 
                                the NCL wrapper to the Fortan
                                code.
                                Set to 'False' by default.

        substitute_fcst (boolean) : 'True'- if this is a zero hour 
                                  forecast, then copy the downscaled 
                                  file from a previous model run with 
                                  the same valid time and rename it.
                                  'False' by default.
        out_path (string) : Optional output file path string to specify
                            the output path. This is more geared towards 
                            CFSv2 downscaling.
        verYYYYMMDDHH (string) : Optional string representing datetime
                                 of data being downscaled. Used for shortwave
                                 radiation downscaling calculations.
        zero_process (bool): Optional argument used in analysis and
                             assimilation. It's used to indicate regridding
                             of 00hr forecast files, which do not regrid
                             fluxes and precipitation as they aren't in
                             the files.
                                  
    Returns:
         None

        
    """

    # Read in all the relevant input parameters based on the product: 
    # HRRR, NAM, GFS, etc.
    product = product_name.upper() 
    lapse_rate_file = parser.get('downscaling','lapse_rate_file')
    ncl_exec = parser.get('exe', 'ncl_exe')
    

    if product  == 'HRRR':
        data_to_downscale_dir = parser.get('downscaling','HRRR_data_to_downscale')
        hgt_data_file = parser.get('downscaling','HRRR_hgt_data')
        geo_data_file = parser.get('downscaling','HRRR_geo_data')
        downscale_output_dir = parser.get('downscaling', 'HRRR_downscale_output_dir')
        downscale_output_dir_0hr = parser.get('downscaling', 'HRRR_downscale_output_dir_0hr')
        downscale_exe = parser.get('exe', 'HRRR_downscaling_exe')
        downscale_exe_0hr = parser.get('exe', 'HRRR_downscaling_exe_0hr')
    elif product == 'GFS':
        data_to_downscale_dir = parser.get('downscaling','GFS_data_to_downscale')
        hgt_data_file = parser.get('downscaling','GFS_hgt_data')
        geo_data_file = parser.get('downscaling','GFS_geo_data')
        # GFS data is used only in Medium Range Forcing, the final destination
        # will be in the Medium Range forcing configuration directory, whose information
        # is located in the [layering] section of the param/config file.
        downscale_output_dir = parser.get('downscaling', 'GFS_downscale_output_dir')
        downscale_exe = parser.get('exe', 'GFS_downscaling_exe')
    elif product == 'RAP':
        data_to_downscale_dir = parser.get('downscaling','RAP_data_to_downscale')
        hgt_data_file = parser.get('downscaling','RAP_hgt_data')
        geo_data_file = parser.get('downscaling','RAP_geo_data')
        downscale_output_dir = parser.get('downscaling', 'RAP_downscale_output_dir')
        downscale_output_dir_0hr = parser.get('downscaling', 'RAP_downscale_output_dir_0hr')
        downscale_exe = parser.get('exe', 'RAP_downscaling_exe')
        downscale_exe_0hr = parser.get('exe', 'RAP_downscaling_exe_0hr')
    elif product == 'CFSV2':
        hgt_data_file = parser.get('downscaling','CFS_hgt_data')
        geo_data_file = parser.get('downscaling','CFS_geo_data')
        downscale_exe = parser.get('exe','CFS_downscaling_exe')
    else:
        WhfLog.info("Requested downscaling of unsupported data product %s", product)
 
     
    # If this is a fcst 0hr file and is either RAP or GFS, then search for
    # a suitable replacement since this file will have one or more 
    # missing variable(s).
    # Otherwise, proceed with creating the request to downscale.
 
    if substitute_fcst:
        # Find another downscaled file from the previous model/
        # init time with the same valid time as this file, then 
        # copy to this fcst 0hr file.
        try:
            replace_fcst0hr(parser, file_to_downscale,product)
        except:
            raise

    else:
        # Downscale as usual
        if product == "CFSV2":
            # Double check to make sure input file exists
            try:
                file_exists(file_to_downscale)
            except:
                raise

            # Create input NCL command components
            input_file1_param = "'hgtFileSrc=" + '"' + hgt_data_file + '"' + "' "
            input_file2_param = "'hgtFileDst=" + '"' + geo_data_file + '"' + "' "
            input_file3_param = "'inFile=" + '"' + file_to_downscale + '"' + "' "
            input_file4_param = "'outFile=" + '"' + out_path + '"' + "' "
            lapse_file_param =  "'lapseFile=" + '"' + lapse_rate_file + '"' + "' "
            time_param = "'verYYYYMMDDHH=" + '"' + verYYYYMMDDHH.strftime("%Y%m%d%H") + '"' + "' "
            downscale_params =  input_file1_param + input_file2_param + \
                      input_file3_param + input_file4_param + lapse_file_param + \
                      time_param 
            downscale_cmd = ncl_exec + " -Q " + downscale_params + " " + downscale_exe 
        else:

            if not file_to_downscale:
                WhfLog.debug("No File to downscale!!!")
                raise MissingFileError('No file to downscale')

            WhfLog.debug("File to downscale = %s", file_to_downscale)
            match = re.match(r'(.*)([0-9]{10})/([0-9]{8}([0-9]{2})00.LDASIN_DOMAIN1.*)',file_to_downscale)
            if match:
                yr_month_day_init = match.group(2)
                regridded_file = match.group(3)
                valid_hr = match.group(4)
            else:
                WhfLog.error("regridded file's name: %s is an unexpected format",\
                             file_to_downscale)
  
                raise FilenameMatchError('%s has an unexpected filename format'%file_to_downscale)
            if zero_process == True:
                full_downscaled_dir = downscale_output_dir_0hr + "/" + yr_month_day_init
            else: 
                full_downscaled_dir = downscale_output_dir + "/" + yr_month_day_init  
            full_downscaled_file = full_downscaled_dir + "/" +  regridded_file

            # Create the full output directory for the downscaled data if it doesn't 
            # already exist. 
            if not os.path.exists(full_downscaled_dir):
                mkdir_p(full_downscaled_dir) 
    
            # Create the key-value pairs that make up the
            # input for the NCL script responsible for
            # the downscaling.
            input_file1_param = "'inputFile1=" + '"' + hgt_data_file + '"' + "' "
            input_file2_param = "'inputFile2=" + '"' + geo_data_file + '"' + "' "
            input_file3_param = "'inputFile3=" + '"' + file_to_downscale + '"' + "' "
            lapse_file_param =  "'lapseFile=" + '"' + lapse_rate_file + '"' + "' "
            output_file_param = "'outFile=" + '"' + full_downscaled_file + '"' + "' "
            downscale_params =  input_file1_param + input_file2_param + \
                      input_file3_param + lapse_file_param +  output_file_param
            if zero_process == True:
                downscale_cmd = ncl_exec + " -Q " + downscale_params + " " + downscale_exe_0hr
            else:  
                downscale_cmd = ncl_exec + " -Q " + downscale_params + " " + downscale_exe
    
        # Downscale the shortwave radiation, if requested...
        # Key-value pairs for downscaling SWDOWN, shortwave radiation.
        if downscale_shortwave:
            WhfLog.info("Shortwave downscaling requested...")
            downscale_swdown_exe = parser.get('exe', 'shortwave_downscaling_exe') 
            swdown_output_file_param = "'outFile=" + '"' + \
                                       full_downscaled_file + '"' + "' "
    
            swdown_geo_file_param = "'inputGeo=" + '"' + geo_data_file + '"' + "' "
            swdown_params = swdown_geo_file_param + " " + swdown_output_file_param
            downscale_shortwave_cmd = ncl_exec + " -Q " + swdown_params + " " \
                                      + downscale_swdown_exe 
            WhfLog.info("SWDOWN downscale command: %s", downscale_shortwave_cmd)
  
            # Crude measurement of performance for downscaling.
            # Wall clock time used to determine the elapsed time
            # for downscaling each file.
            start = time.time()
    
            #Invoke the NCL script for performing a single downscaling.
            return_value = ncl.run(downscale_cmd)
            swdown_return_value = ncl.run(downscale_shortwave_cmd)
            end = time.time()
            elapsed = end - start
    
            # Check for successful or unsuccessful downscaling
            # of the required and shortwave radiation
            if return_value != 0 or swdown_return_value != 0:
                WhfLog.error('The downscaling of %s was unsuccessful, \
                             return value of %d', product,return_value)
                # Remove regridded file and downscaled file 
                cmd = 'rm -rf ' + file_to_downscale
                status = os.system(cmd)
                if status != 0:
                    WhfLog.error('Failed to remove ' + file_to_downscale)
                # If output file was generated, remove it as it's corrupted/incomplete
                if os.path.exists(full_downscaled_file):
                    cmd = 'rm -rf ' + full_downscaled_file 
                    status = os.system(cmd)
                    if status != 0:
                        WhfLog.error('Failed to remove ' + full_downscaled_file)
                raise NCLError('NCL downscaling of %s failed with return value %s'%(product,return_value))
            else: # Remove regridded file as it's no longer needed
                cmd = 'rm -rf ' + file_to_downscale
                status = os.system(cmd)
                if status != 0:
                    WhfLog.error('Failed to remove ' + file_to_downscale)
                    raise SystemCommandError('Could not remove %s'%file_to_downscale)
                    
            return
    
        else:
            # No additional downscaling of
            # the short wave radiation is required.
    
            # Crude measurement of performance for downscaling.
            start = time.time()
    
            #Invoke the NCL script for performing the generic downscaling.
            return_value = ncl.run(downscale_cmd)
            end = time.time()
            elapsed = end - start
            WhfLog.info("Elapsed time (sec) for downscaling: %s",elapsed)
    
            # Check for successful or unsuccessful downscaling
            if return_value != 0:
                # Unsuccessful downscaling, perform clean-up operations.
                # Remove regridded file and downscaled SW file
                cmd = 'rm -rf ' + file_to_downscale
                status = os.system(cmd)
                if status != 0:
                    WhfLog.error('Failed to remove ' + file_to_downscale )
                    raise SystemCommandError('Cleaning unsuccessful downscaling, failed to remove file %s'%file_to_downscale) 
                # If output file was generated, remove it as it's corrupted/incomplete
                if os.path.exists(full_downscaled_file):
                    cmd = 'rm -rf ' + full_downscaled_file
                    status = os.system(cmd)
                    if status != 0:
                      WhfLog.error('Failed to remove ' + full_downscaled_file)
                      raise SystemCommandError('Failed to remove corrupted/incomplete output file and path %s'%full_downscaled_file)
                # Raise exception for failed NCL downscaling
                WhfLog.error('The downscaling of %s was unsuccessful, \
                             return value of %d', product,return_value)
                raise NCLError('NCL downscaling for %s unsuccessful with return value %s', product, return_value)
            else: # Remove regridded file as it's no longer needed
                cmd = 'rm -rf ' + file_to_downscale
                status = os.system(cmd)
                if status != 0:
                    WhfLog.error('Failed to remove ' + file_to_downscale)
                    raise SystemCommandError('Finished with regridded files, failed to remove %s'%file_to_downscale)
            return



def bias_correction(product_name,file_in,cycleYYYYMMDDHH,fcstYYYYMMDDHH,
                   parser,em = 0):
    """ Perform bias correction to input data. The method will vary by product.
    
        Args:
          product_name (string): The name of the model product
                                 (e.g. RAP, GFS, CFSv2, etc).
          file_in (string): The input file being applied a bias correction to.
          cycleYYYYMMDDHH (datetime): Product cycle (init) datetime object.
          fcstYYYYMMDDHH (datetime): Product forecast datetime object.
          parser (SafeConfigParser): Parser object used to read 
                                     values set in the param/config file.
          em (optional integer): Specifies the ensemble member number.

        Returns:
          files_out: List of file(s) that were created in the bias-correction.

    """

    # Retrieve NCL executable path from config file
    product = product_name.upper()
    ncl_exec = parser.get('exe', 'ncl_exe')
    file_exists(ncl_exec)

    if product == "CFSV2":
        em_str = str(em)
        em_str = em_str.zfill(2)

        # Obtain CFSv2 forcing engine parameters.
        ncarg_root = parser.get('default_env_vars', 'ncarg_root')
        CFS_in_dir = parser.get('data_dir','CFS_data')
        CFS_bias_exe = parser.get('exe','CFS_bias_correct_exe')
        CFS_bias_mod = parser.get('exe','CFS_bias_correct_mod')
        tmp_dir = parser.get('bias_correction','CFS_tmp_dir')
        CFS_bias_dir = parser.get('bias_correction','CFS_bias_parm_dir')
        NLDAS_bias_dir = parser.get('bias_correction','NLDAS_bias_parm_dir')         
        CFS_corr_file = parser.get('bias_correction','CFS_correspond')

        # Check for the NCARG_ROOT environment variable. If it is not set,
        # use an appropriate default, defined in the configuration file.
        ncarg_root_found = os.getenv("NCARG_ROOT")
        if ncarg_root_found is None:
            ncarg_root = os.environ["NCARG_ROOT"] = ncarg_root

        # Sanity check to ensure all directories/executables are on system.
        try:
            dir_exists(ncarg_root)
            dir_exists(CFS_in_dir)
        except MissingDirectoryError:
            WhfLog.error("Missing ncarg_root or CFS_in_dir directories")
            raise
        try:
            file_exists(CFS_bias_exe)
            file_exists(CFS_bias_mod)
        except MissingFileError:
            WhfLog.error("Missing CFS_bias_exe or CFS_bias_mod file")
            raise

        # try to create the temp dir if it is not there, since it sometimes isn't
        # before seeing if it exists
        df.makeDirIfNeeded(tmp_dir)
        try:
            dir_exists(tmp_dir)
            dir_exists(CFS_bias_dir)
            dir_exists(NLDAS_bias_dir)
        except MissingDirectoryError:
           WhfLog.error("Missing tmp_dir, CFS_bias_dir, or NLDAS_bias_dir")
           raise
  
        try:
            file_exists(CFS_corr_file)
        except MissingFileError:
            WhfLog.error("Missing CFS_corr_file file")
            raise   

        # Compose previous forecast CFSv2 forecast time step. This is done as the
        # previous time step of data is used in interpolation. If the two time
        # steps are identical, still pass information to the NCL scripts as the 
        # NCL code has checks in place to handle this.
        if fcstYYYYMMDDHH == cycleYYYYMMDDHH:
            prevYYYYMMDDHH = fcstYYYYMMDDHH
        else:
            prevYYYYMMDDHH = fcstYYYYMMDDHH - \
                             datetime.timedelta(seconds=6*3600) 
 
        # Create time stamps for composing paths to NLDAS/CFS bias correction datasets.
        # This is done independently as we need to account for leap years.
        if fcstYYYYMMDDHH.month == 2:
            if fcstYYYYMMDDHH.day == 29:
                fcstYYYYMMDDHHtmp = fcstYYYYMMDDHH - datetime.timedelta(days=1)
            else:
                fcstYYYYMMDDHHtmp = fcstYYYYMMDDHH
        else:
            fcstYYYYMMDDHHtmp = fcstYYYYMMDDHH
     
        # Compose input file path and ensure file exists on system.
        #XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
        # IMPORTANT!!!! THIS WILL NEED TO BE MODIFIED FOR NCEP!!!!!!!!!!!!
        file_in_path = CFS_in_dir + "/cfs." + cycleYYYYMMDDHH.strftime("%Y%m%d") + \
                       "/" + cycleYYYYMMDDHH.strftime("%H") + "/6hrly_grib_" + \
                       em_str + "/flxf" + fcstYYYYMMDDHH.strftime("%Y%m%d%H") + \
                       "." + em_str + "." + cycleYYYYMMDDHH.strftime("%Y%m%d%H") + \
                       ".grb2"
        file_in_path_prev = CFS_in_dir + "/cfs." + cycleYYYYMMDDHH.strftime("%Y%m%d") + \
                            "/" + cycleYYYYMMDDHH.strftime("%H") + "/6hrly_grib_" + \
                            em_str + "/flxf" + prevYYYYMMDDHH.strftime("%Y%m%d%H") + \
                            "." + em_str + "." + cycleYYYYMMDDHH.strftime("%Y%m%d%H") + \
                            ".grb2"
        #XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
        try:
            file_exists(file_in_path)
            file_exists(file_in_path_prev)
        except MissingFileError:
            raise 

        # Determine hourly sub-time steps between six-hour CFSv2 forecasts
        datePrevYYYYMMDDHH = fcstYYYYMMDDHH - datetime.timedelta(seconds=6*3600)
        datePrevMMDD = datePrevYYYYMMDDHH.strftime('%m%d')
        datePrevHH = datePrevYYYYMMDDHH.strftime('%H')
        dateFcstMMDD = fcstYYYYMMDDHH.strftime('%m%d')
        dateFcstHH = fcstYYYYMMDDHH.strftime('%H')
        dateSub1YYYYMMDDHH = datePrevYYYYMMDDHH + datetime.timedelta(seconds=3600)
        dateSub2YYYYMMDDHH = dateSub1YYYYMMDDHH + datetime.timedelta(seconds=3600)
        dateSub3YYYYMMDDHH = dateSub2YYYYMMDDHH + datetime.timedelta(seconds=3600)
        dateSub4YYYYMMDDHH = dateSub3YYYYMMDDHH + datetime.timedelta(seconds=3600)
        dateSub5YYYYMMDDHH = dateSub4YYYYMMDDHH + datetime.timedelta(seconds=3600)

        datePrevYYYYMMDDHHtmp = fcstYYYYMMDDHHtmp - datetime.timedelta(seconds=6*3600)
        datePrevMMDDtmp = datePrevYYYYMMDDHHtmp.strftime('%m%d')
        datePrevHHtmp = datePrevYYYYMMDDHHtmp.strftime('%H')
        dateFcstMMDDtmp = fcstYYYYMMDDHHtmp.strftime('%m%d')
        dateFcstHHtmp = fcstYYYYMMDDHHtmp.strftime('%H')
        dateSub1YYYYMMDDHHtmp = datePrevYYYYMMDDHHtmp + datetime.timedelta(seconds=3600)
        dateSub2YYYYMMDDHHtmp = dateSub1YYYYMMDDHHtmp + datetime.timedelta(seconds=3600)
        dateSub3YYYYMMDDHHtmp = dateSub2YYYYMMDDHHtmp + datetime.timedelta(seconds=3600)
        dateSub4YYYYMMDDHHtmp = dateSub3YYYYMMDDHHtmp + datetime.timedelta(seconds=3600)
        dateSub5YYYYMMDDHHtmp = dateSub4YYYYMMDDHHtmp + datetime.timedelta(seconds=3600)
    
        # Establish hourly NLDAS parameter files used for bias correction and interpolation
        NLDAS_param_path_1 = NLDAS_bias_dir + "/nldas2_" + \
                             dateSub1YYYYMMDDHHtmp.strftime('%m%d%H') + '_dist_params.nc'
        NLDAS_param_path_2 = NLDAS_bias_dir + "/nldas2_" + \
                         dateSub2YYYYMMDDHHtmp.strftime('%m%d%H') + '_dist_params.nc'
        NLDAS_param_path_3 = NLDAS_bias_dir + "/nldas2_" + \
                             dateSub3YYYYMMDDHHtmp.strftime('%m%d%H') + '_dist_params.nc'
        NLDAS_param_path_4 = NLDAS_bias_dir + "/nldas2_" + \
                             dateSub4YYYYMMDDHHtmp.strftime('%m%d%H') + '_dist_params.nc'
        NLDAS_param_path_5 = NLDAS_bias_dir + "/nldas2_" + \
                             dateSub5YYYYMMDDHHtmp.strftime('%m%d%H') + '_dist_params.nc'
        NLDAS_param_path_6 = NLDAS_bias_dir + "/nldas2_" + \
                             fcstYYYYMMDDHHtmp.strftime('%m%d%H') + '_dist_params.nc' 
        try: 
            # Ensure files are present on system
            file_exists(NLDAS_param_path_1)
            file_exists(NLDAS_param_path_2)
            file_exists(NLDAS_param_path_3)
            file_exists(NLDAS_param_path_4)
            file_exists(NLDAS_param_path_5)
            file_exists(NLDAS_param_path_6)
        except MissingFileError:
            raise

        # Establish CFS parameter files used for bias correction and interpolation.
        # There will be two parameter files for each variable being downscaled.
        CFS_param_2mT_path0 = CFS_bias_dir + "/cfs_tmp2m_" + datePrevMMDDtmp + \
                              "_" + datePrevHHtmp + "_dist_params.nc"
        CFS_param_2mT_path1 = CFS_bias_dir + "/cfs_tmp2m_" + dateFcstMMDDtmp + \
                              "_" + dateFcstHHtmp + "_dist_params.nc"
        CFS_param_SW_path0 = CFS_bias_dir + "/cfs_dswsfc_" + datePrevMMDDtmp + \
                              "_" + datePrevHHtmp + "_dist_params.nc"
        CFS_param_SW_path1 = CFS_bias_dir + "/cfs_dswsfc_" + dateFcstMMDDtmp + \
                              "_" + dateFcstHHtmp + "_dist_params.nc"
        CFS_param_LW_path0 = CFS_bias_dir + "/cfs_dlwsfc_" + datePrevMMDDtmp + \
                              "_" + datePrevHHtmp + "_dist_params.nc"
        CFS_param_LW_path1 = CFS_bias_dir + "/cfs_dlwsfc_" + dateFcstMMDDtmp + \
                              "_" + dateFcstHHtmp + "_dist_params.nc"
        CFS_param_PCP_path0 = CFS_bias_dir + "/cfs_prate_" + datePrevMMDDtmp + \
                              "_" + datePrevHHtmp + "_dist_params.nc"
        CFS_param_PCP_path1 = CFS_bias_dir + "/cfs_prate_" + dateFcstMMDDtmp + \
                              "_" + dateFcstHHtmp + "_dist_params.nc"
        CFS_param_PRES_path0 = CFS_bias_dir + "/cfs_pressfc_" + datePrevMMDDtmp + \
                              "_" + datePrevHHtmp + "_dist_params.nc"
        CFS_param_PRES_path1 = CFS_bias_dir + "/cfs_pressfc_" + dateFcstMMDDtmp + \
                              "_" + dateFcstHHtmp + "_dist_params.nc"
        CFS_param_U_path0 = CFS_bias_dir + "/cfs_ugrd_" + datePrevMMDDtmp + \
                              "_" + datePrevHHtmp + "_dist_params.nc"
        CFS_param_U_path1 = CFS_bias_dir + "/cfs_ugrd_" + dateFcstMMDDtmp + \
                              "_" + dateFcstHHtmp + "_dist_params.nc"
        CFS_param_V_path0 = CFS_bias_dir + "/cfs_vgrd_" + datePrevMMDDtmp + \
                                  "_" + datePrevHHtmp + "_dist_params.nc"
        CFS_param_V_path1 = CFS_bias_dir + "/cfs_vgrd_" + dateFcstMMDDtmp + \
                              "_" + dateFcstHHtmp + "_dist_params.nc"
        CFS_param_2mQ_path0 = CFS_bias_dir + "/cfs_q2m_" + datePrevMMDDtmp + \
                              "_" + datePrevHHtmp + "_dist_params.nc"
        CFS_param_2mQ_path1 = CFS_bias_dir + "/cfs_q2m_" + dateFcstMMDDtmp + \
                              "_" + dateFcstHHtmp + "_dist_params.nc"

        try:
            # Ensure parameter files are on the system
            file_exists(CFS_param_2mT_path0)
            file_exists(CFS_param_2mT_path1)
            file_exists(CFS_param_SW_path0)
            file_exists(CFS_param_SW_path1)
            file_exists(CFS_param_LW_path0)
            file_exists(CFS_param_LW_path1)
            file_exists(CFS_param_PCP_path0)
            file_exists(CFS_param_PCP_path1)
            file_exists(CFS_param_PRES_path0)
            file_exists(CFS_param_PRES_path1)
            file_exists(CFS_param_U_path0)
            file_exists(CFS_param_U_path1)
            file_exists(CFS_param_V_path0)
            file_exists(CFS_param_V_path1)
            file_exists(CFS_param_2mQ_path0)
            file_exists(CFS_param_2mQ_path1)

        except MissingFileError:
            raise

        # Compose NCL command that calls bias-correction program.
        bias_params = "'fileIn=" + '"' + file_in_path + '"' + "' " + \
                      "'tmpDir=" + '"' + tmp_dir + '"' + "' " + \
                      "'nldasParamHr1=" + '"' + NLDAS_param_path_1 + '"' + "' " + \
                      "'nldasParamHr2=" + '"' + NLDAS_param_path_2 + '"' + "' " + \
                      "'nldasParamHr3=" + '"' + NLDAS_param_path_3 + '"' + "' " + \
                      "'nldasParamHr4=" + '"' + NLDAS_param_path_4 + '"' + "' " + \
                      "'nldasParamHr5=" + '"' + NLDAS_param_path_5 + '"' + "' " + \
                      "'nldasParamHr6=" + '"' + NLDAS_param_path_6 + '"' + "' " + \
                      "'cfs2TParam0=" + '"' + CFS_param_2mT_path0 + '"' + "' " + \
                      "'cfs2TParam1=" + '"' + CFS_param_2mT_path1 + '"' + "' " + \
                      "'cfsSWParam0=" + '"' + CFS_param_SW_path0 + '"' + "' " + \
                      "'cfsSWParam1=" + '"' + CFS_param_SW_path1 + '"' + "' " + \
                      "'cfsLWParam0=" + '"' + CFS_param_LW_path0 + '"' + "' " + \
                      "'cfsLWParam1=" + '"' + CFS_param_LW_path1 + '"' + "' " + \
                      "'cfsPCPParam0=" + '"' + CFS_param_PCP_path0 + '"' + "' " + \
                      "'cfsPCPParam1=" + '"' + CFS_param_PCP_path1 + '"' + "' " + \
                      "'cfsPRESParam0=" + '"' + CFS_param_PRES_path0 + '"' + "' " + \
                      "'cfsPRESParam1=" + '"' + CFS_param_PRES_path1 + '"' + "' " + \
                      "'cfsUParam0=" + '"' + CFS_param_U_path0 + '"' + "' " + \
                      "'cfsUParam1=" + '"' + CFS_param_U_path1 + '"' + "' " + \
                      "'cfsVParam0=" + '"' + CFS_param_V_path0 + '"' + "' " + \
                      "'cfsVParam1=" + '"' + CFS_param_V_path1 + '"' + "' " + \
                      "'cfs2QParam0=" + '"' + CFS_param_2mQ_path0 + '"' + "' " + \
                      "'cfs2QParam1=" + '"' + CFS_param_2mQ_path1 + '"' + "' " + \
                      "'cycleYYYYMMDDHH=" + '"' + cycleYYYYMMDDHH.strftime("%Y%m%d%H") + \
                      '"' + "' " + \
                      "'fcstYYYYMMDDHH=" + '"' + fcstYYYYMMDDHH.strftime("%Y%m%d%H") + \
                      '"' + "' " + \
                      "'prevYYYYMMDDHH=" + '"' + prevYYYYMMDDHH.strftime("%Y%m%d%H") + \
                      '"' + "' " + \
                      "'corrFile=" + '"' + CFS_corr_file + '"' + "' " + \
                      "'fileInPrev=" + '"' + file_in_path_prev + '"' + "' " + \
                      "'em=" + '"' + em_str + '"' + "' "  
        ncl_cmd = "ncl -Q " + CFS_bias_exe + " " + bias_params
        #WhfLog.debug("Bias command: %s",ncl_cmd)

        # Measure how long it takes to run the NCL script for bias correction.
        start_NCL_bias = time.time()
        return_value = ncl.run(ncl_cmd)
        if return_value != 0:
            WhfLog.error('Bias correction returned an exit status of ' + str(return_value))
            raise NCLError('NCL bias correction failed with return value %s'%return_value)
        end_NCL_bias = time.time()
        elapsed_time_sec = end_NCL_bias - start_NCL_bias
        WhfLog.info('Time(sec) to bias correct file %s' % elapsed_time_sec)  
        
def layer_data(parser, first_data, second_data, first_data_product, second_data_product, forcing_type):
    """Invokes the NCL script, combine.ncl
       to layer/combine two files:  first_data and 
       second_data, with product type of first_prod and
       second_prod respectively.


        Args:
              parser (ConfigParser):  The parser to the config/parm
                                      file containing all the defined
                                      values.
              first_prod (string): The product name of the 
                                   first data product. 
              first_data (string):  The name of the first data file
                                    (e.g. RAP or HRRR)
                                    with the YYYYMMDDHH directory 
                                    so we can associate the model/init
                                    time.
              second_prod (string): The product name of the 
                                    second data product.  
 
              second_data (string): The name of the second data file
                                    (e.g. HRRR or RAP)
                                    and its YYYYMMDDHH directory, so
                                    we can identify its accompanying
                                    model/init time.
              forcing_type (string): The forcing configuration:
                                     Anal_Assim, Short_Range,
                                     Medium_Range, or Long_Range

        Output:
              None:  For each first and second file that is
                     combined/layered, create a file
                     (name and location defined in the config/parm 
                     file).
    """
    # Retrieve any necessary data from the parameter/config file.
    ncl_exe = parser.get('exe', 'ncl_exe')
    forcing_config = forcing_type.lower()
    if forcing_config == 'anal_assim':
        layered_output_dir = parser.get('layering', 'analysis_assimilation_output')
        layering_exe = parser.get('exe','Analysis_Assimilation_layering')
    elif forcing_config == 'short_range':
        layered_output_dir = parser.get('layering', 'short_range_output')
        downscaled_first_dir = parser.get('layering','short_range_primary')
        downscaled_second_dir = parser.get('layering','short_range_secondary')
        layering_exe = parser.get('exe','Short_Range_layering')
    elif forcing_config == 'medium_range':
        # No layering needed for Medium range
        layered_output_dir = parser.get('layering', 'medium_range_output')
    else :
        # No layering needed for Long range
        layered_output_dir = parser.get('layering', 'long_range_output')

    # Create the destination directory in case it doesn't already exist.
    if not os.path.exists(layered_output_dir):
        mkdir_p(layered_output_dir)
    WhfLog.info('Layered output dir: %s', layered_output_dir)

    # Retrieve just the file name portion of the first data file (the file name
    # portion of the first and second data file will be identical, they differ
    # by their directory path names). Note: DO NOT include the .nc file extension
    # for the final output file, the WRF-Hydro model is NOT looking for these.
    # NCL requires a recognized file extension, therefore remove the .nc
    # extension after the layering is complete.
    match = re.match(r'([0-9]{10}/[0-9]{12}.LDASIN_DOMAIN1).nc',first_data)
    if match:
        file_name_only = match.group(1)
    else:
        WhfLog.error("File name format is not what was expected")
        raise FilenameMatchError('%s filename format is unexpecte'%first_data)

    # Create the key-value pair of
    # input needed to run the NCL layering script.
    hrrrFile_param = "'hrrrFile=" + '"' + downscaled_first_dir + "/" + first_data + '"' + "' "
    rapFile_param =  "'rapFile="  + '"' + downscaled_second_dir + "/" +second_data + '"' + "' "
    # Create the output filename for the layered file
    layered_outfile = layered_output_dir + "/" \
                                        + file_name_only
    full_layered_outfile = layered_outfile + ".nc"
    outFile_param = "'outFile=" + '"' + full_layered_outfile + '"' + "' "
    #print ("full_layered_outfile: %s")%(full_layered_outfile)
    if not os.path.exists(full_layered_outfile):
        mkdir_p(full_layered_outfile)
    init_indexFlag = "false"
    indexFlag = "true"
    init_indexFlag_param = "'indexFlag=" + '"' +  init_indexFlag + '"' + "' "
    indexFlag_param = "'indexFlag=" + '"' + indexFlag + '"' + "' "
    init_layering_params = hrrrFile_param + rapFile_param + init_indexFlag_param\
                           + outFile_param 
    layering_params = hrrrFile_param + rapFile_param + indexFlag_param\
                      + outFile_param
    init_layering_cmd = ncl_exe + " " + init_layering_params + " " + \
                        layering_exe
    layering_cmd = ncl_exe + " " + layering_params + " " + \
                        layering_exe
    #print ("layering command: %s")%(layering_cmd)    
    init_return_value = ncl.run(init_layering_cmd)
    if init_return_value != 0:
        WhfLog.error("initial layering was unsuccessful")
        raise NCLError('initial NCL Layering unsuccessful, return value %s'%init_return_value)
    else:
        # Move/rename the processed files to the corresponding forcing
        # configuration directory. 
        os.rename(full_layered_outfile, layered_outfile)

    return_value = ncl.run(layering_cmd) 
   
    if return_value != 0:
        WhfLog.error("layering was unsuccessful")
        raise NCLError('NCL Layering unsuccessful, return value %s'%return_value)
        
    
    

def initial_setup(parser,forcing_config_label):
    """  Set up any environment variables, etc.
         before any processing begins.

         Args:
            parser (SafeConfigParser):  the parsing object 
                                          necessary for parsing
                                          the config/parm file.
            forcing_config_label (string):  The name of the log
                                          file to associate with
                                          the forcing configuration.
                            
         Returns:
            none
                                           
    """

    #Read in all relevant params from the config/param file
    ncl_exec = parser.get('exe', 'ncl_exe')
    ncarg_root = parser.get('default_env_vars', 'ncarg_root')

    # Check for the NCARG_ROOT environment variable. If it is not set,
    # use an appropriate default, defined in the configuration file.
    ncarg_root_found = os.getenv("NCARG_ROOT")
    if ncarg_root_found is None:
        ncarg_root = os.environ["NCARG_ROOT"] = ncarg_root

    # Set the NCL_DEF_LIB_DIR to indicate where ALL shared objects
    # reside.
    ncl_def_lib_dir = parser.get('default_env_vars','ncl_def_lib_dir')
    ncl_def_lib_dir = os.environ["NCL_DEF_LIB_DIR"] = ncl_def_lib_dir
   

def extract_file_info(input_file):

    """ Extract the date, model run time (UTC) and
        forecast hour (UTC) from the (raw) input 
        data file name (i.e. data that hasn't been
        regridded, downscaled,etc.).

        Args:
            input_file (string):  Contains the date, model run
                                  time (UTC) and the forecast
                                  time in UTC.
        Returns:
            date (string):  YYYYMMDD
            model_run (int): HH
            fcst_hr (int):  HHH
    """

    # Regexp check for model data
    match = re.match(r'.*([0-9]{8})_i([0-9]{2})_f([0-9]{3,4}).*', input_file)

    # Regexp check for MRMS data
    match2 = re.match(r'.*(GaugeCorr_QPE_00.00)_([0-9]{8})_([0-9]{6})',input_file)
    if match:
       date = match.group(1)
       model_run = int(match.group(2))
       fcst_hr  = int(match.group(3))
       return (date, model_run, fcst_hr)
    elif match2:
       date = match2.group(2)
       model_run = match2.group(3)
       fcst_hr = int(0)
       return (date, model_run, fcst_hr)
    else:
        WhfLog.error("File name doesn't follow expected format")
        raise FilenameMatchError('Unexpected filename format for %s'%input_file)

    
def extract_file_info_cfs(input_file):

    """ Extract file date, model run time (UTC),
        forecast hour (UTC), and ensemble member
        from the (raw) input data file name (i.e.
        data that hasn't been regridded, downscaled,
        etc.).
 
        Args:
           input_file (string): Contains the date, model run
                                time (UTC), forecast time (UTC),
                                and ensemble member.
       Returns:
           date (string): YYYYMMDD
           model_run (int): HH
           fcst_hr (int): HHH
           em (int) :: N
    """

    # Regexp check for model data
    match = re.match(r'.*([0-9]{8})/([0-9]{8})_i([0-9]{2})_f([0-9]{3,4})_e([0-9]{2}).*',input_file)
    if match:
        date = match.group(1)
        date2 = match.group(1)
        if date != date2:
            WhfLog.error("File name doesn't follow expected format")
            sys.exit(1)
        model_run = int(match.group(3))
        fcst_hr = int(match.group(4))
        em = int(match.group(5))
        return (date, model_run, fcst_hr, em)
    else:
        WhfLog.error("2File name doesn't follow expected format")
        raise FilenameMatchError('Unexpected filename format for %s'%input_file)

def is_in_fcst_range(product_name,fcsthr, parser):
    """  Determine if this current file to be processed has a forecast
         hour that falls within the range bound by the max forecast hour 
         Supports checking for RAP, HRRR, and GFS data.  
         
         Args:
            fcsthr (int):  The current file's (i.e. the data file under
                           consideration) forecast hour.
            parser (SafeConfigParser): The parser object. 
     
         Returns:
            boolean:  True if this is within the max forecast hour
                      False otherwise.
                           
    """

    # Determine whether this current file lies within the forecast range
    # for this data (e.g. if processing RAP, use only the 0hr-18hr forecasts).
    # Skip if this file corresponds to a forecast hour outside of the range.
    if product_name == 'RAP':
        fcst_max = int(parser.get('fcsthr_max','RAP_fcsthr_max'))
    elif product_name == 'HRRR':
        fcst_max = int(parser.get('fcsthr_max','HRRR_fcsthr_max'))
    elif product_name == 'GFS':
        fcst_max = int(parser.get('fcsthr_max','GFS_fcsthr_max'))
    elif product_name == 'CFSv2':
        fcst_max = int(parser.get('fcsthr_max','CFS_fcsthr_max'))
    elif product_name == 'MRMS':
        # MRMS is from observational data, no forecasted data, just
        # return True...
        return True
        
      
    if int(fcsthr) > fcst_max:
        WhfLog.info("Skip file, fcst hour %d is outside of fcst max %d",fcsthr,fcst_max)
        return False
    else:
        return True






def replace_fcst0hr(parser, file_to_replace, product):
    """ There are some missing variables in the 0hr forecast
          for RAP and GFS (such as precipitation
          and radiation fields), which cause
          problems when input to the WRF-Hydro model.
          Substitute these files with downscaled data 
          file from the previous model run/init time:
          YYYYMMDDHH, where HH is the model/init time.
          The file associated with this previous model/init
          time is readily identified as a file with the same name 
          in an earlier model/init run's subdirectory (i.e. previous
          HH = HH-1).
   
          Args:
             parser (SafeConfigParser): parser object used to
                                        read values set in the
                                        param/config file.
             file_to_replace (string);  The fcst 0hr file that 
                                        needs to be substituted
                                        with a downscaled file
                                        from a previous model
                                        run and same valid time.
             product (string):  The name of the model product
                                (e.g. RAP, GFS, etc.)



          Returns:
             None:       Creates a copy of the file and saves
                         it to the appropriate directory:
                         YYYYMMDDHH, where HH is the model/init time.


    """
    # Retrieve the date, model time,valid time, and filename from the full filename 
    WhfLog.debug("file to replace=%s", file_to_replace)
    match = re.match(r'(.*)/([0-9]{8})([0-9]{2})/([0-9]{8}([0-9]{2})00.LDASIN_DOMAIN1.nc)',file_to_replace)
    WhfLog.debug("After, file to replace=%s", file_to_replace)
    if match:
        base_dir = match.group(1)
        curr_date = match.group(2)
        model_time = int(match.group(3))
        file_only = match.group(4) 
        valid_time = int(match.group(5))
    else:
        WhfLog.error("filename %s  is unexpected, exiting.", file_to_replace)
        raise FilenameMatchError('Unexpected filename format for %s'%input_file)


    if product == 'RAP':
        # Get the previous directory corresponding to the previous
        # model run/init time.
        if model_time == 0:
            # Use the previous day's last model run
            # and date.
            prev_model_time = 23
            date = get_past_or_future_date(curr_date,-1)
            prev_model_time_str = (str(prev_model_time)).rjust(2,'0')
            

        else:
            prev_model_time = model_time - 1
            prev_model_time_str = (str(prev_model_time)).rjust(2,'0')
            date = curr_date
    
        # Create the full file path and name to create the directory of
        # the previous model run/init time (i.e. YYYYMMDDH'H', 
        # where H'H' is the previous model run/init).
        # In this directory, search for the fcst 0hr file with the same name.  If it 
        # exists, copy it over to the YYYYMMDDHH directory of the
        # fcst 0hr file in the downscaling output directory.  

        base_dir = parser.get('downscaling','RAP_finished_output_dir')

        full_path = base_dir + '/' + date + prev_model_time_str + "/" + \
                    file_only
        WhfLog.info("full path = %s", full_path)
        if os.path.isfile(full_path):
            # Make a copy
            file_dir_fcst0hr = base_dir + "/" + curr_date + (str(model_time)).rjust(2,'0') 
            # Make the directory for the downscaled fcst 0hr 
            if not os.path.exists(file_dir_fcst0hr):
                mkdir_p(file_dir_fcst0hr)
            file_path_to_replace = file_dir_fcst0hr + "/" + file_only
            copy_cmd = "cp " + full_path + " " + file_path_to_replace
            WhfLog.info("copying the previous model run's file: %s",copy_cmd)      
            os.system(copy_cmd)
        else:
            # If we are here, we didn't find any file from a previous RAP model run...
            # this could be a "bootstrapping" issue, where we are requesting data 
            # that isn't available (due to scrubbing, etc.)
            WhfLog.error("No previous RAP model runs found, exiting...")
            raise ZeroHourReplacementError('No RAP file from previous RAP model run- premature scrubbing or inavailability of data') 
    elif product == 'GFS':
        base_dir = parser.get('layering','medium_range_output')
        # Get the previous directory corresponding to the previous
        # model/init run. GFS only has 0,6,12,and 18 Z model/init run times.
        # Available forecasts are 0,3,6,9,12,15, and 18 hours.
        prev_model = model_time - 6
        if prev_model < 0:
            prev_model_time_str = str(18)   
            date = get_past_or_future_date(curr_date, -1)
        else:
            date = curr_date
            prev_model_time_str = (str(prev_model)).rjust(2,'0')
        full_path = base_dir + '/' + date + prev_model_time_str + "/" +\
                    file_only
        if os.path.isfile(full_path):
            # Make a copy
            file_dir_fcst0hr = base_dir + "/" + curr_date + (str(model_time)).rjust(2,'0') 
            # Make the directory for the downscaled fcst 0hr 
            if not os.path.exists(file_dir_fcst0hr):
                mkdir_p(file_dir_fcst0hr)
            file_path_to_replace = file_dir_fcst0hr + "/" + file_only
            copy_cmd = "cp " + full_path + " " + file_path_to_replace
            WhfLog.info("copying the previous model run's file: %s",copy_cmd)      
            os.system(copy_cmd)
        else:
            # If we are here, we didn't find any file from a previous GFS model run...
            WhfLog.error("No previous GFS model runs found, exiting...")
            raise ZeroHourReplacementError('No GFS file from previous RAP model run- premature scrubbing or inavailability of data') 
          
def get_past_or_future_date(curr_date, num_days = -1):
    """   Determines the date in YMD format
          (i.e. YYYYMMDD) for the day before the specified date.
         
          Args:
             curr_date (string): The current date. We want to 
                                 determine the nth-previous day's 
                                 date in YMD format.
             num_days (int)    : By default, set to -1 to determine
                                 the previous day's date. Set to
                                 positive integer value for n days
                                 following the curr_date, and -n
                                 days for n days preceeding the
                                 curr_date.
          Returns:
             prev_date (string): The nth previous day's date in 
                                 YMD format (YYYYMMDD).

    """        

    curr_dt = datetime.datetime.strptime(curr_date, "%Y%m%d")
    prev_dt = curr_dt + datetime.timedelta(days=num_days)
    year = str(prev_dt.year)
    month = str(prev_dt.month)
    day = str(prev_dt.day)
    month  = month.rjust(2,'0')
    day = day.rjust(2, '0')
    prev_list = [year, month, day]
    prev_date = ''.join(prev_list)
    return prev_date
    
def dir_exists(dir):
    """ Check for directory existence 
        Args:
           dir (string): The directory in question.
    """

    if not os.path.isdir(dir):
        WhfLog.error('Directory: ' + dir + ' not found.')
        raise MissingDirectoryError('Directory %s not found'%dir)

def file_exists(file):    
    """ Check for file (or symbolic link) existence
        Args:
           file (string): The file in question.
    """  
    
    # Using ispath instead of isfile to account for symbolic links
    if not os.path.exists(file):
        WhfLog.error('File: ' + file + ' not found.')
        raise MissingFileError('File %s not found'%file)

    
def rename_final_files(parser, forcing_type):
    """Rename the processed files in the
          forcing configuration directory so the
          .nc file extension is removed.
  
        Input:
            parser (SafeConfigParser):  SafeConfigParser used to
                                        retrieve the information in
                                        the wrf_hydro_forcing.parm
                                        configuration/param file.

            forcing_type (string):  One of the four supported
                                    forcing configurations:
                                    Anal_Assim, Short_Range,
                                    Medium_Range, and Long_Range.
 
        Returns:
            None                   moves the files that are 
                                   in the source directory 
                                   (stated in the param/config file)
                                   to the destination directory
                                   (stated in the param/config file)
                                   WITHOUT the '.nc' file extension
                                   (requested input format to the
                                    WRF-HYDRO model)
                               

    """    

    parser = SafeConfigParser()
    parser.read('../../parm//wrf_hydro_forcing.parm')


    forcing_type = forcing_type.upper()
    if forcing_type == 'ANAL_ASSIM':
        # Move layered RAP and HRRR data
        # to the Anal_Assim directory
        anal_assim_dir = parser.get('layering','analysis_assimilation_output')
        mrms_dir = parser.get('regridding','MRMS_output_dir')
        anal_assim_files = get_layered_files(anal_assim_dir)
        for file in anal_assim_files:
            # Get the filename without the .nc extension
            match = re.match(r'.*/(([0-9]{10})/[0-9]{12}.LDASIN_DOMAIN1).*', file)
            if match:
                filename_only = match.group(1)
                ymd_dir = match.group(2)
                destination_dir = anal_assim_dir + "/" + ymd_dir
                destination = anal_assim_dir + "/" + filename_only
                if not os.path.exists(destination_dir):
                    mkdir_p(destination_dir)
                shutil.move(file, destination)

            else:
               WhfLog.warning("filename is of unexpected format: %s", file)
               raise FilenameMatchError('Renaming file %s for %s, unexpected filename format'%(file,forcing_type)) 
        # Move the MRMS files to their own location.
        for mrms in mrms_dir:
            # Get the filename without the .nc extension
            match = re.match(r'.*/(([0-9]{10})/[0-9]{12}.LDASIN_DOMAIN1).*', file)
            if match:
                filename_only = match.group(1)
                ymd_dir = match.group(2)
                destination_dir = anal_assim_dir + "/" + ymd_dir  
                destination = mrms_dir +  "/" + filename_only
                if not os.path.exists(destination_dir):
                    mkdir_p(destination_dir)
                src = mrms_dir + "/" + ymd_dir + "/" + file
                os.rename(src, destination)
            else:
               WhfLog.warning("filename is of unexpected format: %s", mrms)
               raise FilenameMatchError('Renaming file %s for %s, unexpected filename format'%(file,forcing_type)) 
             
        

    elif forcing_type == 'SHORT_RANGE':
        short_range_dir = parser.get('layering','short_range_output')
        short_range_files = get_layered_files(short_range_dir)
        for file in short_range_files:
            # Get the filename without the .nc extension
            match = re.match(r'.*/(([0-9]{10})/[0-9]{12}.LDASIN_DOMAIN1).*', file)
            if match:
                filename_only = match.group(1)
                ymd_dir = match.group(2)
                destination_dir = short_range_dir + "/" + ymd_dir
                destination = short_range_dir + "/" + filename_only
                if not os.path.exists(destination_dir):
                    mkdir_p(destination_dir)
                os.rename(file, destination)

            else:
               WhfLog.warning("filename is of unexpected format :%s", file)
               raise FilenameMatchError('Renaming file %s for %s, unexpected filename format'%(file,forcing_type)) 


    elif forcing_type == 'MEDIUM_RANGE':
        # Medium Range has GFS data only and no layering.  Use
        # the final downscaled directory.
        medium_range_downscale_dir = parser.get('layering','medium_range_output')
        medium_range_dir = parser.get('layering','medium_range_output')
        medium_range_files = get_layered_files(medium_range_downscale_dir)
        for file in medium_range_files:
            # Get the filename without the .nc extension
            match = re.match(r'.*/(([0-9]{10})/[0-9]{12}.LDASIN_DOMAIN1).*', file)
            if match:
                filename_only = match.group(1)
                ymd_dir = match.group(2)
                destination_dir = medium_range_dir + "/" + ymd_dir 
                destination = medium_range_dir + "/" + filename_only
                if not os.path.exists(destination_dir):
                    mkdir_p(destination_dir)
                os.rename(file, destination)
            else:
               WhfLog.warning("filename is of unexpected format :%s", file)
               raise FilenameMatchError('Renaming file %s for %s, unexpected filename format'%(file,forcing_type)) 

    elif forcing_type == 'LONG_RANGE':
        # Already renamed and moved within the Long_Range_Forcing script.
        WhfLog.info("request renaming of Long Range files")

    else:
        print "Forcing type is not recognized or is unsupported. Try again."
        raise UnrecognizedCommandError('Forcing type %s not supported/unrecognized'%forcing_type) 


    
def get_layered_files(dir):
    """Retrieves all the files in the layered file directory.
       Only netCDF files with the '.nc' extension will be
       considered.

       Args:
           dir (string):  The directory to search for all layered
                          files with .nc extension

       Returns:
           file_paths (list) : List of the full filepath and
                               files in the input directory.
    """

    # Create an empty list which will eventually store
    # all the full filenames
    file_paths = []

    # Walk the tree
    for root, directories, files in os.walk(dir):
        for filename in files:
            # add it to the list only if it is a grib file
            match = re.match(r'.*(.nc)$',filename)
            if match:
                # Join the two strings to form the full
                # filepath.
                filepath = os.path.join(root,filename)
                file_paths.append(filepath)
            else:
                continue
    return file_paths


def move_to_finished_area(parser, product, src, zero_move = False):
    """Move finished regridded (MRMS) or downscaled HRRR,
       RAP files to a "finished" area so they can
       be monitored by an external script which determines
       when to layer the various products.
        

       Args:
            parser (SafeConfigParser): used to obtain the
                                       parameters set in 
                                       the wrf_hydro_forcing.parm
                                       config/parameter file.
            product (string) :  The name of the product: MRMS, HRRR,
                                RAP, or GFS
            
            src (string): full file path and filename of src
            zero_move (bool): Optional argument for handling 00hr 
                              fcst files. Only used by analysis and
                              assimilation configuration.

       Returns:
           None
    """
    if product == "MRMS":
        dest_dir = parser.get('regridding','MRMS_finished_output_dir')
    elif product == "RAP":
        dest_dir = parser.get('downscaling', 'RAP_finished_output_dir')
        dest_dir_0hr = parser.get('downscaling','RAP_finished_output_dir_0hr')
    elif product == "HRRR":
        dest_dir = parser.get('downscaling', 'HRRR_finished_output_dir')
        dest_dir_0hr = parser.get('downscaling','HRRR_finished_output_dir_0hr')
    elif product == "GFS":
        dest_dir = parser.get('downscaling', 'GFS_finished_output_dir')
    else:
        WhfLog.error("%s is unsupported",product) 
        raise UnrecognizedCommandError('Cannot move files for unsupported/unrecognized product %s'%product)
    # Get the YYYYMMDDHH subdirectory from the full file path and
    # name (src).
    match = re.match(r'.*/([0-9]{10})/([0-9]{12}.LDASIN_DOMAIN1.nc)',src)
    if match:
        ymd_dir = match.group(1)
        file_only = match.group(2)
        if zero_move == True:
            finished_dir = dest_dir_0hr + "/" + ymd_dir
        else:
            finished_dir = dest_dir + "/" + ymd_dir
        if not os.path.exists(finished_dir):
            mkdir_p(finished_dir) 
        finished_dest = finished_dir + "/" + file_only
        WhfLog.info("moving %s", src)
        WhfLog.info("...to %s", finished_dest)
        shutil.move(src, finished_dest) 
        #cmd = "mv "+ src + " " + finished_dest
        #WhfLog.info(cmd)
        #status = os.system(cmd)
        #WhfLog.info("Stataus = %d", status)
    else:
        WhfLog.error("can't match filename")
        raise FilenameMatchError('Cannot find match to filename %s'%src)


#--------------------Define the Workflow -------------------------

if __name__ == "__main__":
    # Replace pass with anything you wish if you want to
    # run this as a standalone program.
    pass
