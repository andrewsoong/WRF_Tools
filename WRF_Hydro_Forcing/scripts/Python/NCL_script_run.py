""" NCL_script_run
All NCL scripts are run through this command, which manages logging
"""

import shlex
from subprocess import Popen, PIPE
import WhfLog

def run(cmd):
    """
    Execute the external command and get its exitcode, stdout and stderr.
    Parameters
    ----------
    cmd : str
       The NCL command
    Returns 
    -------
    int:  exitcode
    """

    # log the command prior to doing anything
    WhfLog.debug_ncl(cmd)

    # do the command in a way where stdout and stderr can be grabbed as strings
    args = shlex.split(cmd)
    proc = Popen(args, stdout=PIPE, stderr=PIPE)
    out, err = proc.communicate()
    exitcode = proc.returncode

    if err:
        # get rid of annoying error about not making directory that exists
        header = 'mkdir: cannot create directory'
        tail = 'File exists'
        ltail = len(tail)
        i = err.find(header)
        if (i >= 0):
            j = err.find(tail)
            if (j > i):
                err = err[0:i] + err[j+ltail:]
                k = err.find('\n')
                if (k ==0):
                    if (len(err) > 1):
                        # multi line error, not just this annoying one
                        err = err[1:]
                    else:
                        # just the annoying line
                        err = ""
        if (err):
            # Log errors PRIOR to logging output
            WhfLog.error_ncl(err)
    if out:
        # Go ahead and log the output, which is usually some big multiline string
        WhfLog.debug_ncl(out)

    # return the exit code, for those who want to know
    return exitcode

    
