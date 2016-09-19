import WRF_Hydro_forcing as whf
import Analysis_Assimilation_Forcing as aaf
import datetime
import WhfLog as wlog
import re
from ConfigParser import SafeConfigParser
from ForcingEngineError import InvalidArgumentError


def is_within_time_range(start_dt, end_dt, file, prod, is_yellowstone=False):
    """Determines whether the file (full file path) is
       within the specified start and end time.
     
       Returns True if this file is within the specified
       start and end time, False otherwise.

    """
  
    # Get the date-time (YYYYMMDD) portion from
    # the filename, create a datetime object and
    # see if it lies within the start_dt and
    # end_dt datetimes.
    if is_yellowstone:
        if prod == 'MRMS':
            match = re.match(r'.*GaugeCorr.*00.00_([0-9]{8})_[0-9]{6}.*',file)
            ymd_dir = match.group(1)

        else:
            match = re.match(r'.*/(RAP|HRRR)/([0-9]{8})/[0-9]{8}_i[0-9]{2,3}_f[0-9]{2,3}_(WRF-RR|HRRR).*',file)
            ymd_dir = match.group(2)
    else: 
        if prod == 'MRMS':
            match = re.match(r'.*GaugeCorr.*00.00_([0-9]{8})_[0-9]{6}.*',file)
            ymd_dir = match.group(1)
        else:
            match = re.match(r'.*/([0-9]{8})/[0-9]{8}_i[0-9]{2}_f[0-9]{2,3}_(WRF-RR|HRRR).*',file)
            ymd_dir = match.group(1)

    # Create the datetime object for this ymd and compare
    ymd_datetime = datetime.datetime.strptime(ymd_dir, "%Y%m%d")
    if ymd_datetime >= start_dt and ymd_datetime <= end_dt:
        return True
    else:
        return False
    
def do_regrid(config_file, dir_base, prod, data_files, is_yellowstone=False):
    """Do the regridding and downscaling of the product"""
    
    for file in data_files:
        # Use only the filename of the file, the 
        # regrid_data() is only expecting a file name.
        if prod == 'MRMS':
            match = re.match(r'.*(GaugeCorr.*00.00_[0-9]{8}_[0-9]{6}.*)',file)
            file_only = match.group(1) 
        else:
            match = re.match(r'(.*)/([0-9]{8}_i[0-9]{2}_f[0-9]{2,3}.*)',file)
            file_only = match.group(2) 
        try:
           aaf.forcing(config_file,"regrid",prod,file_only)
        except InvalidArgumentError:
           pass


def do_layering(config_file,parser,rap_downscale_dir, hrrr_downscale_dir, mrms_downscale_dir, fcst_hr, is_yellowstone=False):
    # Initialize some flags and lists,
    # assume that we only have RAP for now.
    request_hrrr = False
    request_mrms = False 
    rap_files = []
    hrrr_files = []
    mrms_files = []
    
    # Set flags to be used to determine which layers need to be layered.
    if hrrr_downscale_dir is not None:
        request_hrrr = True
    if mrms_downscale_dir is not None:
        request_mrmrs = True
  
    # We will always have RAP when calling do_layering.
    print "RAP downscale dir: %s"%rap_downscale_dir
    rap_file_paths = whf.get_filepaths(rap_downscale_dir)
    size = len(rap_file_paths)
    print("number of RAP files in %s, %s")%(rap_downscale_dir, size)
    if request_hrrr == True:
        print "HRRR true, layer RAP and HRRR"
        # Layer only RAP and HRRR
        hrrr_file_paths = whf.get_filepaths(hrrr_downscale_dir)
        if is_yellowstone:
            for rap in rap_file_paths:
                match = re.match(r'.*/RAP.*/([0-9]{10})/([0-9]{12}.LDASIN_DOMAIN1.*)',rap)
                model_run = match.group(1)
                aaf.anal_assim_layer(model_run,fcst_hr,"RAP_HRRR",config_file)

        else:
            for rap in rap_file_paths:
                match = re.match(r'.*/RAP.*/([0-9]{10})/([0-9]{12}.LDASIN_DOMAIN1.*)',rap)
                model_run = match.group(1)
                aaf.anal_assim_layer(model_run,fcst_hr,"RAP_HRRR", config_file)
 
        if request_mrms == True:
            # Layer all three: RAP, HRRR, and MRMS
            # Compare the YYYYMMDDHH/YYYYMMDDhh00.LDASIN_DOMAIN1.nc portions
            mrms_file_paths = whf.get_filepaths(mrms_downscale_dir)
            if is_yellowstone:    
                for rap in rap_file_paths:
                    match = re.match(r'.*/RAP.*([0-9]{10})/([0-9]{12}.LDASIN_DOMAIN1.*)',rap)
                    model_run = match.group(1)
                    whf.anal_assim_layer(model_run, fcst_hr, 'RAP_HRRR_MRMS',config_file) 
            else:
                # Testing on development/test host
                for rap in rap_file_paths:
                    match = re.match(r'.*/RAP.*([0-9]{10})/([0-9]{12}.LDASIN_DOMAIN1.*)',rap)
                    model_run = match.group(1)
                    whf.anal_assim_layer(model_run, fcst_hr, 'RAP_HRRR_MRMS',config_file) 
    else:
        # Only RAP requested, call layering with just RAP.     
        print ("Only RAP requested, layering called with just RAP")
        if is_yellowstone:    
            for rap in rap_file_paths:
                print("layering rap file: %s")%rap
                match = re.match(r'.*/RAP/.*([0-9]{10})/([0-9]{12}.LDASIN_DOMAIN1.*)',rap)
                model_run = match.group(1)
                print("model run: %s, fcst hr %s")%(model_run,fcst_hr)
                aaf.anal_assim_layer(model_run, fcst_hr, "RAP",config_file)
         
        else:
            for rap in rap_file_paths:
                match = re.match(r'.*/RAP/.*([0-9]{10})/([0-9]{12}.LDASIN_DOMAIN1.*)',rap)
                model_run = match.group(1)
                aaf.anal_assim_layer(model_run, fcst_hr, "RAP",config_file)


def main():
    """Tests the regridding and downscaling of RAP and HRRR
       data for the Short Range Forcing Configuration.
    """
    # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    # CHANGE THIS TO REFLECT WHICH RUN ENVIRONMENT:
    # YELLOWSTONE OR HYDRO-C!
    # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    # Set flag for testing host
    #is_yellowstone = True
    is_yellowstone = False
    parser = SafeConfigParser()
    config_file = "../../parm/b_wrf_hydro_forcing.parm"
    parser.read(config_file)    

    # Set up logger
    #wlog.init(parser, "testAA", "AA","Regrid","MRMS")

    # Start and end dates 
    if is_yellowstone:
         start_dt = datetime.datetime.strptime("20151004","%Y%m%d")
         end_dt = datetime.datetime.strptime("20151005","%Y%m%d")
    else:
         start_dt = datetime.datetime.strptime("20160215","%Y%m%d")
         end_dt = datetime.datetime.strptime("20160216","%Y%m%d")

    # Set the directory where the input data resides.
    # For running on yellowstone:
    # RAP_dir_base = "/glade/scratch/lpan/IOC/data/RAP"
    # HRRR_dir_base = "/glade/scratch/lpan/IOC/data/HRRR"
    # MRMS_dir_base = "/glade/scratch/lpan/IOC/data/MRMS"
    # For running on hydro-c1:
    # RAP_downscale_dir =
    # "/glade/scratch/gochis/IOC_evaluation_datasets/
    # Forcing_Engine/workspace/downscaled/RAP"
    # HRRR_downscale_dir = "/glade/scratch/gochis/
    # IOC_evaluation_datasets/Forcing_Engine/workspace/downscaled/HRRR"
    RAP_dir_base = parser.get('data_dir','RAP_data')
    HRRR_dir_base = parser.get('data_dir', 'HRRR_data')
    MRMS_dir_base = parser.get('data_dir', 'MRMS_data')
    RAP_downscale_dir = parser.get('downscaling', 'RAP_finished_output_dir')
    RAP_0hr_downscale_dir = parser.get('downscaling', 'RAP_finished_output_dir_0hr')
    HRRR_downscale_dir = parser.get('downscaling', 'HRRR_finished_output_dir')
    HRRR_0hr_downscale_dir = parser.get('downscaling', 'HRRR_finished_output_dir_0hr')
    MRMS_downscale_dir = parser.get('regridding','MRMS_finished_output_dir')

    all_RAP_files_with_path = whf.get_filepaths(RAP_dir_base) 
    all_HRRR_files_with_path = whf.get_filepaths(HRRR_dir_base) 
    all_MRMS_files_with_path = whf.get_filepaths(MRMS_dir_base) 

    # We are only interested in the MRMS, RAP and HRRR files that are
    # within the start and end forecast times, since the /glade/scratch/lpan/IOC/data
    # directory is continually adding more dates.
    RAP_files_with_path = [x for x in all_RAP_files_with_path if is_within_time_range(start_dt,end_dt,x,"RAP",is_yellowstone)]
    HRRR_files_with_path = [x for x in all_HRRR_files_with_path if is_within_time_range(start_dt,end_dt,x,"HRRR",is_yellowstone)]
    MRMS_files_with_path = [x for x in all_MRMS_files_with_path if is_within_time_range(start_dt,end_dt,x,"MRMS",is_yellowstone)]

    wlog.init(parser, "testAA", "AA","Regrid","RAP")
    do_regrid(config_file, RAP_dir_base,'RAP', RAP_files_with_path)
    wlog.init(parser, "testAA", "AA","Regrid","HRRR")
    do_regrid(config_file, HRRR_dir_base, 'HRRR', HRRR_files_with_path)
    wlog.init(parser, "testAA", "AA","Regrid","MRMS")
    do_regrid(config_file,MRMS_dir_base, 'MRMS', MRMS_files_with_path)
#    do_layering(config_file, parser, RAP_0hr_downscale_dir, None, None, 0)
    #do_layering(config_file, parser, RAP_downscale_dir, None, None, -1)
    #do_layering(config_file, parser, RAP_downscale_dir, None, None, -2)
    #do_layering(config_file, parser, RAP_0hr_downscale_dir, HRRR_0hr_downscale_dir, None,0)
    #do_layering(config_file, parser, RAP_downscale_dir, HRRR_downscale_dir, None, -1)
    #do_layering(config_file, parser, RAP_downscale_dir, HRRR_downscale_dir, None, -2)
    #do_layering(config_file, parser, RAP_0hr_downscale_dir, HRRR_0hr_downscale_dir,MRMS_downscale_dir, 0)
    #do_layering(config_file, parser, RAP_downscale_dir, HRRR_downscale_dir,MRMS_downscale_dir, -1)
    #do_layering(config_file, RAP_downscale_dir, HRRR_downscale_dir,MRMS_downscale_dir, -2)




#----------------------------------------------------------------------------------------         
    
if __name__ == "__main__":
    main()    

