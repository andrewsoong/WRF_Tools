import os
import re


def insert_text(base_dir):
    ''' Insert the copyright text (approved by NCAR General Counsel) into every
        script (NCL, Python, bash, Fortran, or csh.) that is found under a base directory.

        Args:
            base_dir (string): The base directory where all scripts reside.
        
        Returns:
            None

    '''    

    copyright_text = "; 2015,2016@ University Corporation for Atmospheric Research"
    horizontal_bar = "; ----------------------------------------------------------"

    # Go through the base directory and traverse each subdirectory. For
    # each file, append with the appropriate copyright text at the top

    full_file_paths = get_filepaths(base_dir)
    for file in full_file_paths:
        #Determine the type of file based on the file extension
        match_py = re.search(r'.*/.*(.py)$',file)
        match_ncl = re.search(r'.*/.*(.ncl)$',file)
        match_bash = re.search(r'.*/.*(.bash)$',file)
        match_f90 = re.search(r'.*/.*(.f90|F|F90)$',file)
        match_csh = re.search(r'.*/.*(.csh)$',file)

        #Use the appropriate formatting based on the file type
        #Modify the dates to accurately reflect the origin date and
        #dates when copyright is effective.
        if match_py or match_bash or match_csh:
            copyright_text = "# 2015,2016@ University Corporation for Atmospheric Research"
            horizontal_bar = "# ----------------------------------------------------------"
        elif match_ncl:
            copyright_text = "; 2015,2016@ University Corporation for Atmospheric Research"
            horizontal_bar = "; ----------------------------------------------------------"
        elif match_f90: 
            copyright_text = "! 2015,2016@ University Corporation for Atmospheric Research"
            horizontal_bar = "! ----------------------------------------------------------"
            
        sed_exe = "/bin/sed"
        tokens = (sed_exe, " -i -e ", "'1i", copyright_text, "\\' " ,file)
        cmd = "".join(tokens)
        os.system(cmd)
        #Add horizontal line for simple formatting
        tokens_top = (sed_exe," -i -e ", "'1i ",horizontal_bar,"\\' ", file)
        cmd_newline = "".join(tokens_top)
        os.system(cmd_newline)
        tokens_bottom = (sed_exe," -i -e ", "'2a ",horizontal_bar,"\\' ", file)
        cmd_newline = "".join(tokens_bottom)
        os.system(cmd_newline)

    

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
            # add it to the list only if it is a Python (.py), NCL (.ncl), Fortran (.f90, .F,.F90), csh(.csh) or bash (.bash) file
            match = re.match(r'.*(py|ncl|bash|f90|F|F90|csh)$',filename)
            if match:
                # Join the two strings to form the full
                # filepath.
                filepath = os.path.join(root,filename)
                file_paths.append(filepath)
            else:
                continue
    return file_paths
    


if __name__ == "__main__":
    base_dir = "/home/minnawin/model"
    insert_text(base_dir)
