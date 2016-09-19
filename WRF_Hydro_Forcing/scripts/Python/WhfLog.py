"""WhfLog
Handles log file creation and use
"""

import os
import datetime
import logging
import sys
import DataFiles as df
from ConfigParser import SafeConfigParser
from ForcingEngineError import SystemCommandError
from ForcingEngineError import InvalidArgumentError
import inspect

# global var for which logging type is currently active
WhfWhichChoices = ['RegridHRRR', 'RegridRAP', 'RegridMRMS', 'RegridGFS', 'ShortLayer', 'AaLayer', 'LongRegrid']
WhfWhich = 'RegridHRRR'

# global var always length 7  'Short   ', 'Medium ', 'Long   ', 'AA     '
WhfConfigType = '      '
WhfConfigTypeLen = 7

# global variable always length 7  'Regrid ', 'Layer  '
WhfAction = '       '
WhfActionLen = 7

# global variable always length 14  'RAP,HRRR/MRMS ', ...
WhfData = '              '
WhfDataLen = 14

def setup_logger(logger_name, log_file, level=logging.INFO):
    """  Set named logger to a particular level and log file name

    Parameters
    ----------
    logger_name : str
       Name of logger
    log_file : str
       Name of log file
    level
       INFO, DEBUG, ...
    """
    l = logging.getLogger(logger_name)
    formatter = logging.Formatter('%(asctime)s : %(message)s')
    fileHandler = logging.FileHandler(log_file, mode='a')
    fileHandler.setFormatter(formatter)
    l.setLevel(level)
    l.addHandler(fileHandler)

def init(parser, which, initAll):
    """Initialize log file using configFile content, and a log file name

    Parameters
    ----------
    parser : SafeConfigParser
        parser that has parsed the file on entry
    logFileName : str
        Name of the log file, without a .log suffix
    configType : str
        Short, Medium, Long, AA
    action : str
        Regrid, Layer
    data : str
        HRRR, RAP, MRMS, GFS, CFS
    """

    logging_level = parser.get('log_level', 'forcing_engine_log_level')
    # Set the logging level based on what was defined in the parm/config file
    if logging_level == 'DEBUG':
        set_level = logging.DEBUG
    elif logging_level == 'INFO':
        set_level = logging.INFO
    elif logging_level == 'WARNING':
        set_level = logging.WARNING
    elif logging_level == 'ERROR':
        set_level = logging.ERROR
    else:
        set_level = logging.CRITICAL

    # log files written to configured place with yyyymmdd subdirectory
    logging_path = parser.get('log_level', 'forcing_engine_log_dir')
    if (not df.makeDirIfNeeded(logging_path)):
        raise SystemCommandError("Cannot create " + logging_path)
    logging_path += "/"
    now = datetime.datetime.utcnow()
    logging_path += now.strftime("%Y%m%d")
    if (not df.makeDirIfNeeded(logging_path)):
        raise SystemCommandError("Cannot create " + logging_path)

    # we have two log files, one for python, one for ncl, for each of the cases
    # string 'RegridHRRR', 'RegridRAP', 'RegridMRMS', 'RegridGFS', 'ShortLayer', 'AaLayer', 'LongRegrid'
    global WhfWhichChoices
    for choice in WhfWhichChoices:
        if (initAll):
            logging_filename =  logging_path + "/" + choice + ".log" 
            ncl_logging_filename =  logging_path + "/" + choice + ".ncl.log" 
            setup_logger(choice + 'main',  logging_filename, set_level)
            setup_logger(choice + 'ncl',  ncl_logging_filename, set_level)
        else:
            if (choice == which):
                logging_filename =  logging_path + "/" + choice + ".log" 
                ncl_logging_filename =  logging_path + "/" + choice + ".ncl.log" 
                setup_logger(choice + 'main',  logging_filename, set_level)
                setup_logger(choice + 'ncl',  ncl_logging_filename, set_level)
    set(which)
    
def set(which):
    if which in WhfWhichChoices:
        global WhfWhich
        WhfWhich = which
    else:
        raise InvalidArgumentError("Unknown input " + which)
    if (which == 'RegridHRRR'):
        configType = 'Short'
        action = 'Regrid'
        data = 'HRRR'
    elif (which == 'RegridRAP'):
        configType = 'Short'
        action = 'Regrid'
        data = 'RAP'
    elif (which == 'RegridMRMS'):
        configType = 'AA'
        action = 'Regrid'
        data = 'MRMS'
    elif (which == 'RegridGFS'):
        configType = 'Medium'
        action = 'Regrid'
        data = 'GFS'
    elif (which == 'ShortLayer'):
        configType = 'Short'
        action = 'Layer'
        data = 'RAP/HRRR'
    elif (which == 'AaLayer'):
        configType = 'AA'
        action = 'Layer'
        data = 'RAP/HRRR/MRMS'
    elif (which == 'LongRegrid'):
        configType = 'Long'
        action = 'Regrid'
        data = 'CFS'
    else:
        raise InvalidArgumentError("Unknown input " + which)

    # set the global var's to inputs, padded to correct length
    #(so logging lines up nice)
    global WhfConfigType
    WhfConfigType = configType
    WhfConfigType = WhfConfigType.ljust(WhfConfigTypeLen)

    global WhfAction
    WhfAction = action
    WhfAction = WhfAction.ljust(WhfActionLen)
    
    global WhfData
    WhfData = data
    WhfData = WhfData.ljust(WhfDataLen)

def setConfigType(ctype):
    """  Set config type to input, padded to correct length
    Parameters
    ----------
    ctype : str
       Short, Medium, Long, AA
    """
    global WhfConfigType
    WhfConfigType = ctype
    WhfConfigType = WhfConfigType.ljust(WhfConfigTypeLen)

def setData(data):
    """  Set data type to input, padded to correct length
    Parameters
    ----------
    data : str
       HRRR, RAP, MRMS, etc
    """
    global WhfData
    WhfData = data
    WhfData = WhfData.ljust(WhfDataLen)

def createFormatString(status, fmt, level):
    """  Create and return a standard format string, with input format string
         appended
    Parameters
    ----------
    status : str
       'OK', 'ERROR', 'WARNING', 'CRITICAL'
    fmt : str
       Format string
    level : int
       1 if calling function is 1 deep compared to what you want to get line/function/file,
       2 if calling function is 2 deep
    Returns
    -------
    str : The format string
    """

    # Get location of caller ([level+1]'th thing on stack)
    lineno = inspect.stack()[level+1][2]
    funcname = inspect.stack()[level+1][3]
    filename = os.path.basename(inspect.stack()[level+1][1])
    # a standard output format:
    linestr = '%d' % (lineno)
    fStatus = status;
    fStatus = fStatus.ljust(8)
    formatStr = fStatus + WhfConfigType + WhfAction + WhfData + " [" + filename + ":" + linestr + "," + funcname + "] " + fmt
    return formatStr

def debug(fmt, *argv):
    """ Log a debug message
    Parameters
    ----------
    fmt : str
       Format string
    argv
       Arguments
    """
    formatStr = createFormatString('OK', fmt, 1)
    global WhfWhich
    log = logging.getLogger(WhfWhich + 'main')
    log.debug(formatStr, *argv)
    
def debug_ncl(fmt, *argv):
    """ Log a debug message to the NCL log file
    Parameters
    ----------
    fmt : str
       Format string
    argv
       Arguments
    """
    formatStr = createFormatString('OK', fmt, 2)
    global WhfWhich
    log = logging.getLogger(WhfWhich + 'ncl')
    log.debug(formatStr, *argv)
    
def info(fmt, *argv):
    """ Log an info message
    Parameters
    ----------
    fmt : str
       Format string
    argv
       Arguments
    """
    formatStr = createFormatString('OK', fmt, 1)
    global WhfWhich
    log = logging.getLogger(WhfWhich + 'main')
    log.info(formatStr, *argv)
    
def warning(fmt, *argv):
    """ Log a warning message
    Parameters
    ----------
    fmt : str
       Format string
    argv
       Arguments
    """
    formatStr = createFormatString('WARNING', fmt, 1)
    global WhfWhich
    log = logging.getLogger(WhfWhich + 'main')
    log.warning(formatStr, *argv)
    
def error(fmt, *argv):
    """ Log an error message
    Parameters
    ----------
    fmt : str
       Format string
    argv
       Arguments
    """
    formatStr = createFormatString('ERROR', fmt, 1)
    global WhfWhich
    log = logging.getLogger(WhfWhich + 'main')
    log.error(formatStr, *argv)
    
def error_ncl(fmt, *argv):
    """ Log an error message to the NCL log file
    Parameters
    ----------
    fmt : str
       Format string
    argv
       Arguments
    """
    formatStr = createFormatString('ERROR', fmt, 2)
    global WhfWhich
    log = logging.getLogger(WhfWhich + 'ncl')
    log.error(formatStr, *argv)
    
def critical(fmt, *argv):
    """ Log a critical message
    Parameters
    ----------
    fmt : str
       Format string
    argv
       Arguments
    """
    formatStr = createFormatString('CRITICL', fmt, 1)
    global WhfWhich
    log = logging.getLogger(WhfWhich + 'main')
    log.critical(formatStr, *argv)
    
