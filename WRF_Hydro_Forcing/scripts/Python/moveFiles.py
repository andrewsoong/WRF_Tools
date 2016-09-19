import os
import sys
import re
import shutil
import time
import WRF_Hydro_forcing as whf
from ForcingEngineError import MissingDirectoryError
from ForcingEngineError import MissingFileError



def moveFiles(source_dir, destination_dir, delay=0):
    '''Moves all the files from the source directory to the
       destination directory.
  
       Args:
           source_dir (string):      Full path to the source directory
           destination_dir (string): Full path to the destination directory
           extension (string):       File extension of files to be moved

       Returns:
           None

    '''

    try:
        #Source directory
        dir_exists(source_dir)
    
    except MissingDirectoryError:
        print "Source directory missing. Check directory path"
        
    else:
        # Get a directory listing and save all files with the specified
        # extension.
        files = whf.get_filepaths(source_dir)
        
    try:
        #Destination directory
        dir_exists(destination_dir)
    except MissingDirectoryError:
        print "Destination directory does not exist, creating it now"
        whf.mkdir_p(destination_dir)
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
            whf.mkdir_p(dest_path)
            dest = dest_path +  filename_only
            shutil.move(file, dest)
            time.sleep(delay)



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
    #Indicate the source and destination for testing/mimicking real-time data
    source = "/d7/hydro-dm/data/MRMS/"
    destination = "/d8/hydro-dm/data/MRMS/"
 
    #Set time delay (in seconds) for move so that this actually behaves more like real-time
    #If undefined, then the default is 0, but if reversing, we want to revert as quickly as possible
    delay = 65

    usage =  "Usage: python moveFiles.py [forward|reverse]"

    if len(sys.argv) == 1:
        print usage

    else:
        if sys.argv[1] == 'forward':
            print "Moving files from source to destination to mimic real-time data..."
            moveFiles(source, destination, delay)
        elif sys.argv[1] == 'reverse':
            # Resetting, reversing the files back to their original directory
            print "Reversing.  Moving files back to original destination directory for retesting..."
            source,destination = destination,source
            moveFiles(source, destination)
        else:
            print usage

