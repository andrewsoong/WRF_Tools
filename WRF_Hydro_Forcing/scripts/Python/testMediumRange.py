import WRF_Hydro_forcing as whf
import Medium_Range_Forcing as mrf
import datetime
import re
from ConfigParser import SafeConfigParser

"""Runner for Medium Range Forcing configuration. 
   Can be run on either Yellowstone or hydro-c1.
   If running on Yellowstone, set the is_yellowtone
   variable to True. Specify time range: YYYYMMDD
   for the data you wish to process.
"""


def is_within_time_range(start_dt, end_dt, file,  is_yellowstone=False):
    """Determines whether the file (full file path) is
       within the specified start and end time.
     
       Returns True if this file is within the specified
       start and end time, False otherwise.

    """
  
    # Get the date-time (YYYYMMDD) portion from
    # the filename, create a datetime object and
    # see if it lies within the start_dt and
    # end_dt datetimes.

    match = re.match(r'.*/(gfs5|GFS_0.25-pgrb2)/([0-9]{8})/[0-9]{8}_i[0-9]{2}_f[0-9]{4}_GFS.*',file)
    if match:
        ymd_dir = match.group(2)
    else:
        return False


    # Create the datetime object for this ymd and compare
    ymd_datetime = datetime.datetime.strptime(ymd_dir, "%Y%m%d")
    if ymd_datetime >= start_dt and ymd_datetime <= end_dt:
        return True
    else:
        return False
    
        



def main():
    """Tests the regridding and downscaling of GFS
       data for the Medium Range Forcing Configuration.
    """
    # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    # CHANGE THIS TO REFLECT WHICH RUN ENVIRONMENT,
    # YELLOWSTONE OR HYDRO-C1
    # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    # Set flag for testing host
    #is_yellowstone = True
    is_yellowstone = False
    parser = SafeConfigParser()
    config_file = "../../parm/wrf_hydro_forcing2.parm"
    parser.read(config_file)    

    # Start and end dates 
    if is_yellowstone:
         start_dt = datetime.datetime.strptime("20150929","%Y%m%d")
         end_dt = datetime.datetime.strptime("20150930","%Y%m%d")
    else:
         start_dt = datetime.datetime.strptime("20160201","%Y%m%d")
         end_dt = datetime.datetime.strptime("20160202","%Y%m%d")

    # Set the directory where the input data resides.
    # For running on yellowstone:
    # GFS_dir_base = "/glade/scratch/lpan/IOC/data/gfs5"
    # For running on hydro-c1:
    # /var/autofs/mnt/gfsdmg1/data/grib/GFS_0.25-pgrb2
    # GFS_downscale_dir =
    # "/glade/scratch/gochis/IOC_evaluation_datasets/Forcing_Engine/workspace/downscaled/GFS"
    GFS_dir_base = parser.get('data_dir','GFS_data')
    #GFS_downscale_dir = parser.get('downscaling', 'GFS_downscale_output_dir')
    GFS_downscale_dir = parser.get('layering', 'medium_range_output')

    all_GFS_files_with_path = whf.get_filepaths(GFS_dir_base) 

    # We are only interested in the GFS files that are
    # within the start and end forecast times.
        
    GFS_files_with_path = [x for x in all_GFS_files_with_path if is_within_time_range(start_dt,end_dt,x,is_yellowstone)]
    print("INFO: GFS files within time range:")
    for gfs_files in GFS_files_with_path:
        print(gfs_files)

    # do the processing on only the input grib files 
    do_regrid(config_file, GFS_dir_base,'GFS', GFS_files_with_path, is_yellowstone)


def do_regrid(config_file, dir_base, prod, data_files, is_yellowstone):
    """Do the regridding and downscaling of the product"""
    
    for file in data_files:
        # Use only the filename of the file, the 
        # regrid_data() is only expecting a file name.
        match = re.match(r'(.*)/([0-9]{8}_i[0-9]{2}_f[0-9]{2,3}.*)',file)
        file_only = match.group(2) 
        mrf.forcing(config_file, "regrid",prod,file_only)



#-------------------------------------------
if __name__ == "__main__":
    main()    



