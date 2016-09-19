"""Regrid_Driver
Checks data directories for new content, and if 
found initiates regrid/rescaling python scripts.
Keeps state in a state file that is read/written
each time this script is invoked.  The state
file contains the most recent data files.
Logs to a log file that is created in the
same directory from where this script is executed.  
"""

import os
import sys
import logging
import datetime
import time
from ConfigParser import SafeConfigParser
import DataFiles as df
import WhfLog
import Short_Range_Forcing as srf
import Analysis_Assimilation_Forcing as aaf
import Medium_Range_Forcing as mrf
from ForcingEngineError import FilenameMatchError
from ForcingEngineError import InvalidArgumentError
from ForcingEngineError import SystemCommandError
from ForcingEngineError import ZeroHourReplacementError

#----------------------------------------------------------------------------
def parmRead(fname, fileType, realtime):
   """Read in the main config file, return needed parameters

   Parameters
   ----------
   fname: str
      name of parameter file to read in
   fileType: str
      'RAP', 'HRRR', 'MRMS', 'GFS'
   realtime: boolean
      True if realtime, False for archive mode

   Returns
   -------
   Parms
      values as pulled from the file

   """
    
   parser = SafeConfigParser()
   parser.read(fname)

   label = 'Regrid' + fileType
   if (realtime):
      WhfLog.init(parser, label, False)
   else:
      WhfLog.set(label)
   dataDir = parser.get('data_dir', fileType + '_data')
   maxFcstHour = int(parser.get('fcsthr_max', fileType + '_fcsthr_max'))
   hoursBack = int(parser.get('triggering', fileType + '_hours_back'))
   stateFile = parser.get('triggering', fileType + '_regrid_state_file')
   
   parms = Parms(dataDir, maxFcstHour, hoursBack, stateFile)
   return parms

#----------------------------------------------------------------------------
def regridIfZeroHr(configFile, fileType, fname):
   """If it is a 0 hour forecast (RAP or HRRR) regrid in a special way
   Parameters
   ----------
   configFile : str
      configuration file with all settings
   fileType: str
      HRRR, RAP, ... string
   fname: str
      name of file to regrid and downscale, with yyyymmdd parent dir

   Returns
   -------
   None
   """
   # check for 0 hour by creating a DataFile and checking forecast hour
   try:
      f = df.DataFile(fname[0:8], fname[9:], fileType)
   except FilenameMatchError as fe:
      WhfLog.debug("Cannot check for 0 hour data due to %s", fe)
      raise
   except InvalidArgumentError as ie:
      WhfLog.debug("Cannot check for 0 hour data due to %s", ie)
      raise
   if (f._time._forecastHour == 0):
      WhfLog.setConfigType('AA')
      WhfLog.debug("SPECIAL 0 hour case %s", fname[9:0])
      aaf.forcing(configFile, 'regrid', fileType, fname[9:])
      WhfLog.setConfigType('Short')

#----------------------------------------------------------------------------
def regrid(fname, fileType, configFile):
   """Invoke regridding/downscaling 
       
   Parameters
   ----------
   fname: str
      name of file to regrid and downscale, with yyyymmdd parent dir
   fileType: str
      HRRR, RAP, ... string
   configFile : str
      configuration file with all settings

   Returns
   -------
   None

   """

   WhfLog.info("REGRIDDING %s DATA, file=%s", fileType, fname)
   try:
      if (fileType == 'HRRR'):
         srf.forcing(configFile, 'regrid', 'HRRR', fname[9:])
         # special case, if it is a 0 hour forecast, do double regrid
         regridIfZeroHr(configFile, fileType, fname)
      elif (fileType == 'RAP'):
         srf.forcing(configFile, 'regrid', 'RAP', fname[9:])
         # special case, if it is a 0 hour forecast, do double regrid
         regridIfZeroHr(configFile, fileType, fname)
      elif (fileType == 'GFS'):
         mrf.forcing(configFile, 'regrid', 'GFS', fname[9:])
      elif (fileType == 'MRMS'):
         aaf.forcing(configFile, 'regrid', 'MRMS', fname[9:])
      else:
         WhfLog.info("ERROR REGRIDDING %s DATA, file=%s", fileType, fname)
         raise InvalidArgumentError("Unknown file type " + fileType)
   except ZeroHourReplacementError as z:
      WhfLog.info("ERROR REGRIDDING: %s", z)
      WhfLog.info("Remove this forecast from list of to do forecasts")
   except:
      WhfLog.info("ERROR REGRIDDING %s DATA, file=%s", fileType, fname)
      raise

   WhfLog.info("DONE REGRIDDING %s DATA, file=%s", fileType, fname)
    
#----------------------------------------------------------------------------
class Parms:
   """Parameters from the main wrf_hydro param file that are needed 

   Attributes
   ----------
   _dataDir: str
      Topdir for data
   _maxFcstHour: int
      Maximum forecast hour to process
   _hoursBack: int
      Hours back to maintain state
   _stateFile: str
      Name of file with state information that is read/written
   """

   #--------------------------------------------------------------------------
   def __init__(self, dataDir, maxFcstHour, hoursBack, stateFile):
      """Initialization using input args

      Parameters
      ----------
      One to one with attributes, self explanatory
      """
      self._dataDir = dataDir
      self._maxFcstHour = maxFcstHour
      self._hoursBack = hoursBack
      self._stateFile = stateFile

   #--------------------------------------------------------------------------
   def debugPrint(self):
      """ Debug logging of content
      """
      WhfLog.debug("Parms: data = %s", self._dataDir)
      WhfLog.debug("Parms: MaxFcstHour = %d", self._maxFcstHour)
      WhfLog.debug("Parms: StateFile = %s", self._stateFile)


#----------------------------------------------------------------------------

# Internal state that is read in and saved out
# The state
#
class State:
   """Internal state that is read in and saved out

   Attributes
   ----------
   _empty: bool
      True if state is not set
   _data
      data file names with yyyymmdd parent directory
   """

   #--------------------------------------------------------------------------
   def __init__(self, parmFile="", fileType=""):
      """Initialize using parameters read in from a file

      Parameters
      ----------
      parmFile: str
         Name of param file to read
      fileType: str
         'HRRR', 'RAP', ...
      """

      if (not parmFile):
         self._empty = True
         self._data = []
      else:
         self._empty = False
         cf = SafeConfigParser()
         cf.read(parmFile)
         self._data = [name for name in cf.get("latest", fileType).split()]

   #--------------------------------------------------------------------------
   def isEmpty(self):
      """Check if state is set or not

      Parameters
      ----------
         none
    
      Returns
      -------
         true if state is not set
      """
      if (self._empty):
         return True
      return (not self._data)

   #--------------------------------------------------------------------------
   def newest(self):
      """return newest file

      Returns
      -------
      str
         File name (newest), or empty string if none
         
      """
      if (self.isEmpty()):
         return ""
      return (self._data[-1])
      
   #--------------------------------------------------------------------------
   def initialize(self, data):
      """Initialize from DataFiles inputs

      Parameters
      ----------
      data: DataFiles
         data
    
      Returns
      -------
         None
      """
      self._empty = False
      self._data = data.getFnames()

   #--------------------------------------------------------------------------
   def debugPrint(self):
      """ logging debug of contents
      """
      for f in self._data:
         WhfLog.debug("State:%s", f)
        
   #--------------------------------------------------------------------------
   def addFileIfNew(self, f):
      """ If input file is not in state, add it

      Parameters
      ----------
      f:str
         File name

      Returns
      -------
      bool
         True if added, false if already in the state

      """
      ret = False
      if (not f in self._data):
          self._data.append(f)
          ret = True
      return ret
   
   #--------------------------------------------------------------------------
   def sortFiles(self):
      """ Sort the files into ascending order for a type

      Note: sort depends on naming being 'nice'

      Returns
      -------
      none

      """
      self._data.sort()

   #--------------------------------------------------------------------------
   def lookForNew(self, data, hoursBack, fileType):
      """ See if new data has arrived compared to state.
      If a new issue time, purge older stuff from state.

      Parameters
      ----------
      data: DataFiles
         The newest data
      hoursBack: int
         Maximum number of hours back to keep data in state
      fileType : str
         'HRRR', 'RAP', ...
      Returns
      -------
      list[str]
          The data file names that are are to be added to state
      """
         
      ret = []
      fnames = data.getFnames()
      if (not fnames):
         return ret

      if (self.isEmpty()):
         WhfLog.debug("Adding to empty list")
      else:
         sname = self.newest()
         if (not sname):
            WhfLog.error("Expected file, got none")
            return ret
         self._analyzeNewest(fnames[-1], sname, hoursBack, fileType)
      for f in fnames:
         if (self._isNew(f)):
            ret.append(f)
      return ret

   #--------------------------------------------------------------------------
   def write(self, parmFile, fileType):
      """ Write state to param file

      Parameters
      ----------
      parmFile: Name of file to write to 
      fileType: str
          'HRRR', etc
            
      Returns
      -------
      None
      """
         
      config = SafeConfigParser()

      # When adding sections or items, add them in the reverse order of
      # how you want them to be displayed in the actual file.
      # In addition, please note that using RawConfigParser's and the raw
      # mode of ConfigParser's respective set functions, you can assign
      # non-string values to keys internally, but will receive an error
      # when attempting to write to a file or when you get it in non-raw
      # mode. SafeConfigParser does not allow such assignments to take place.

      config.add_section('latest')

      s = ""
      for f in self._data:
         s += f
         s += "\n"
      config.set('latest', fileType, s)

      # Write it out
      with open(parmFile, 'wb') as configfile:
         config.write(configfile)

   #--------------------------------------------------------------------------
   def _isNew(self, f):
      return (not f in self._data)

   #--------------------------------------------------------------------------
   def _update(self, time, hoursBack, fileType):
      """Update typed state so that input time is newest one

       Parameters
       ----------
       time: ForecastTime
          The newest time
       hoursBack:
          Maximum issue time hours back compared to time
       fileType: str
          'HRRR', ...
       
       Returns
       -------
       none
       """
      self._data = df.filterWithinNHours(self._data, fileType, time, hoursBack)
      
   #--------------------------------------------------------------------------
   def _analyzeNewest(self, dataNewest, stateNewest, hoursBack, fileType):
      if (dataNewest <= stateNewest):
         return

      # see if issue time has increased and if so, purge old stuff
      # create DataFile objects, which requires breaking the full
      # file into yymmdd/filename
      sind = stateNewest.find('/')
      if (sind < 0):
         raise FileNameMatchError('Cannot parse directory from ' + stateNewest)
      nind = dataNewest.find('/')
      if (nind < 0):
         raise FileNameMatchError('Cannot parse directory from ' + dataNewest)
      symd = stateNewest[:sind]
      sfile = stateNewest[sind+1:]
      nymd = dataNewest[:nind]
      nfile = dataNewest[nind+1:]
      WhfLog.debug("Checking %s / %s  against %s / %s", symd, sfile, nymd, nfile)
      try:
         df0 = df.DataFile(symd, sfile, fileType)
         df1 = df.DataFile(nymd, nfile, fileType)
      except FilenameMatchError as fe:
         WhfLog.debug("Cannot update due to %s", fe)
      except InvalidArgumentError as ie:
         WhfLog.debug("Cannot update due to %s", ie)

      if (df0._time.inputIsNewerIssueHour(df1._time)):
         WhfLog.debug("%s Issue hour has increased, purge now", fileType)
         self._update(df1._time, hoursBack, fileType)

#----------------------------------------------------------------------------
def createStateFile(parms, fileType, realtime):
   """  Called if there is no state file, look at data dirs and create state
        in realtime, in non-realtime create an empty state.  Write to file.
   Parameters
   ----------
   parms: Parms
      Parameter settings
   fileType: str
      'HRRR', ...
   realtime: boolean
      True if realtime, False for archive mode

   Returns
   -------
   none

   Writes out the state file after creating it
   """

   WhfLog.info("Initializing")
   state = State("")

   if (realtime):

      # query each directory and get newest model run file for each, then
      # get all for that and previous issue time, this becomes state that
      # is not re-processed, we only look for new stuff
      data = df.DataFiles(parms._dataDir, parms._maxFcstHour, fileType)
      data.setNewestFiles(parms._hoursBack)
      for f in data._content:
         f.debugPrint("Newest files: " + fileType)
      state.initialize(data)

   # write out file (at least try to)
   state.write(parms._stateFile, fileType)

#---------------------------------------------------------------------------
def run(fileType, configFile, realtime):
   """ Run the script, process any new data
   Parameters
   ----------
   fileType: str
      'HRRR', ...
   configFile : str
      Name of the file with settings
   realtime : boolean
      True if this is realtime
   Returns
   -------
   1 for error, 0 for success
   """   
   good = False
   regriddable = ['HRRR', 'RAP', 'MRMS', 'GFS']
   if (fileType not in regriddable):
      print 'ERROR unknown file type command arg ', fileType
      return 1

   # User must pass the config file into the main driver.
   if not os.path.exists(configFile):
      print 'ERROR forcing engine config file not found:', configFile
      return 1

   # read in fixed main params
   parms = parmRead(configFile, fileType, realtime)

   #if there is not a state file, create one now using newest
   if (not os.path.exists(parms._stateFile)):
      parms.debugPrint()
      createStateFile(parms, fileType, realtime)
        
   # read in state
   state = State(parms._stateFile, fileType)

      # query each directory and get newest model run file for each, then
   # get all for that and previous issue time
   data = df.DataFiles(parms._dataDir, parms._maxFcstHour, fileType)
   data.setNewestFiles(parms._hoursBack)

   # Update the state to reflect changes, returning those files to regrid
   # Regrid 'em
   toProcess = state.lookForNew(data, parms._hoursBack, fileType)
   for f in toProcess:
      try:
         regrid(f, fileType, configFile);
      except:
         WhfLog.error("Could not regrid/downscale %s", f)
      else:
         WhfLog.debug("Adding new file %s, and writing state file", f)
         if (not state.addFileIfNew(f)):
            WhfLog.error("File %s was not new", f)
         else:
            state.write(parms._stateFile, fileType);
          
   # write out state (in case it has not been written yet) and exit
   #state.debugPrint()
   state.write(parms._stateFile, fileType)
   return 0

#----------------------------------------------------------------------------
def main(argv):
   return run(argv[0], argv[1], True)

#----------------------------------------------

if __name__ == "__main__":
   main(sys.argv[1:])
