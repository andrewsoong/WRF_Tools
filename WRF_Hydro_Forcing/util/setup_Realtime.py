import sys
import re
import os
import time
import errno
from ForcingEngineError import MissingDirectoryError
from ForcingEngineError import MissingFileError


def setup_for_realtime(product,source_dir, destination_dir):
    '''Sets up archived data to 
       behave like real-time data.
       
       Move the necessary data from one directory to another (to avoid
       filling disk space).  
   
       Update the corresponding state file with a sorted list of files.

    '''
    prod = product.lower()

    # Assign the state file according to the data product
    if product == "rap":
        state_file = "State.RapRegrid.txt"
    elif product == "hrrr":
        state_file = "State.HrrrRegrid.txt"
    elif product == "mrms":
        state_file = "State.MrmsRegrid.txt"
    elif product == "cfs":
        state_file = "State.LongRangeRegrid.txt"

    # Open the state file. If it already exists, overwrite it
    # otherwise create one.
    sf =  open(state_file, 'w+')
    sf.write('[latest]\n')
    
    sf.write(product+"= ")

    try:
        #Source directory
        dir_exists(source_dir)

    except MissingDirectoryError:
        print "Source directory missing. Check directory path"

    else:
        # Get a directory listing and save all files with the specified
        # extension.
        files = get_filepaths(source_dir)
        files.sort()


    try:
        #Destination directory
        dir_exists(destination_dir)
    except MissingDirectoryError:
        print "Destination directory does not exist, creating it now"
        mkdir_p(destination_dir)
    else:
        #move the files
        for file in files:
            #separate the filename from the directory and the
            #date directory
            date_match = re.match(r'.*/([0-9]{8})',file)
            if date_match:
                date_dir = date_match.group(1)
            else:
                print "No date directory found, exiting"
                raise MissingDirectoryError("No date directory")

            # Just the filename, no path
            exp = re.compile(r'.*/[0-9]{8}/(.*.grib2|.*.grb2)')
            file_match = exp.match(file)
            if file_match:
                filename_only = file_match.group(1)
            else:
                print "No file name match, exiting"
                raise MissingFileError("No file matching the expected pattern")

            dest = (destination_dir,date_dir,"/" )
            dest_path = "".join(dest)
            mkdir_p(dest_path)
            dest = dest_path +  filename_only
            date_and_file_tokens = ('      ',date_dir,'/',filename_only)
            date_and_file = "".join(date_and_file_tokens)
            print "date and file: %s"% date_and_file
            
            #Update the state file corresponding to this data product
            sf.write(date_and_file)
            sf.write("\n")


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

def file_exists(file):
    """ Check for file (or symbolic link) existence
        Args:
           file (string): The file in question.
    """

    # Using ispath instead of isfile to account for symbolic links
    if not os.path.exists(file):
        raise MissingFileError('File %s not found'%file)



def dir_exists(dir):
    """ Check for directory existence
        Args:
            dir (string): The directory in question.
    """

    if not os.path.isdir(dir):
        raise MissingDirectoryError('Directory %s not found'%dir)

def file_exists(file):
    """ Check for file (or symbolic link) existence
        Args:
           file (string): The file in question.
    """

    # Using ispath instead of isfile to account for symbolic links
    if not os.path.exists(file):
        raise MissingFileError('File %s not found'%file)


if __name__ == "__main__":
         
    '''Prepare data directory and corresponding 
       state file to mimic real-time environment 
       for testing the Python trigger and wrapper scripts 
       that comprise the WRF-Hydro forcing engine.
    '''

    prod = sys.argv[1]
    product = prod.lower()
    print "product: %s"%product

    #Set up the location of data directories
    if product=='mrms':
        #Data dir for MRMS:
        source_dir="/d7/hydro-dm/data/MRMS"
        destination_dir="/d8/hydro-dm/data/MRMS"
    elif product == 'rap':
        #Data dir for RAP
        source_dir="/d7/hydro-dm/data/RAP"
        destination_dir="/d8/hydro-dm/data/RAP"
    elif product == 'hrrr':
        #Data dir for HRRR
        source_dir="/d7/hydro-dm/data/HRRR"
        destination_dir="/d8/hydro-dm/data/HRRR"
    elif product == 'gfs':
        #Data dir for GFS
        source_dir="/d7/hydro-dm/data/GFS"
        destination_dir="/d8/hydro-dm/data/GFS"
    elif product == 'cfs':
        #Data dir for CFS
        source_dir="/d7/hydro-dm/data/CFS"
        destination_dir="/d8/hydro-dm/data/CFS"
    else:
        print "Unrecognized product, supported products: MRMS, RAP, HRRR, GFS, CFS"
        exit

    #
    setup_for_realtime(product,source_dir,destination_dir)
    pass 

