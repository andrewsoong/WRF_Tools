class ForcingEngineError(Exception):
    '''Base class for any errors anticipated
       while running the WRF-Hydro forcing
       engine.
    '''
    def __init__(self, value):
        self.parameter = value
    def __str__(self):
        return repr(self.parameter)



class NCLError(ForcingEngineError):
    '''Used when the NCL script
       invoked by the WRF-Hydro
       forcing engine returns a
       non-zero value.  This indicates
       that something went wrong during
       the execution of the NCL script.
       Unfortunately, there are no standards
       for the return values, these can be
       defined by the NCL script creator. 
    '''
    def __init__(self,value):
        self.parameter = value
    def __str__(self):
        return repr(self.parameter)


class FilenameMatchError(ForcingEngineError):
    '''Used when regex on a file produces
        no match, indicating that the underlying
        file name format has been changed.
    ''' 
    def __init__(self, value):
        self.parameter = value
    def __str__(self):
        return repr(self.parameter)

class MissingDataFileError(ForcingEngineError):
    '''Used when an expected data/processed file
       is not found. 
    ''' 
    def __init__(self, value):
        self.parameter = value
    def __str__(self):
        return repr(self.parameter)
 
class MissingDirectoryError(ForcingEngineError):
    '''Used when an expected directory
       is not found. 
    ''' 
    def __init__(self, value):
        self.parameter = value
    def __str__(self):
        return repr(self.parameter)

class MissingFileError(ForcingEngineError):
    '''Used when an expected file
       is not found. 
    ''' 
    def __init__(self, value):
        self.parameter = value
    def __str__(self):
        return repr(self.parameter)

class ZeroHourReplacementError(ForcingEngineError):
    '''Used when an expected file replacement
       file for a RAP or GFS 0hr forecast
       is not found. 
    ''' 
    def __init__(self, value):
        self.parameter = value
    def __str__(self):
        return repr(self.parameter)

class UnrecognizedCommandError(ForcingEngineError):
    '''Used when an expected request
       is made.
    ''' 
    def __init__(self, value):
        self.parameter = value
    def __str__(self):
        return repr(self.parameter)

class SystemCommandError(ForcingEngineError):
    '''Used when OS System commands fail.
    '''
    def __init__(self, value):
        self.parameter = value
    def __str__(self):
        return repr(self.parameter)

class MissingInputError(ForcingEngineError):
    '''Used when one or more input parameters
       is missing.
    '''
    def __init__(self, value):
        self.parameter = value
    def __str__(self):
        return repr(self.parameter)
    
class InvalidArgumentError(ForcingEngineError):
    '''Used when one or more input parameters
       is incorrect/unexpected.
    '''
    def __init__(self, value):
        self.parameter = value
    def __str__(self):
        return repr(self.parameter)
    
