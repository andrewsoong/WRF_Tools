"""LongRangeRegridDriver
Checks data directory for new content, and if 
found initiates regrid/rescaling python script.
Keeps state in a state file that is read/written
each time this script is invoked.  The state
file contains the most recent data files.
Logs to a log file that is created in the
same directory from where this script is executed.  
"""

import os
import sys
import datetime
import time
import WhfLog
import DataFiles as df
import Long_Range_Forcing as lrf
from ConfigParser import SafeConfigParser
from ForcingEngineError import FilenameMatchError
from ForcingEngineError import InvalidArgumentError

#----------------------------------------------------------------------------
def parmRead(fname, realtime):
   """Read in the main config file, return needed parameters

   Parameters
   ----------
   fname: str
      name of parameter file to read in

   Returns
   -------
   Parms
      values as pulled from the file

   """
   parser = SafeConfigParser()
   parser.read(fname)

   if (realtime):
       WhfLog.init(parser, 'LongRegrid', False)
   else:
       WhfLog.set('LongRegrid')
   cfsDir = parser.get('data_dir', 'CFS_data')
   cfsNumEnsemble = int(parser.get('data_dir', 'CFS_num_ensemble'))
   maxFcstHourCfs = int(parser.get('fcsthr_max', 'CFS_fcsthr_max'))
   hoursBackCfs = int(parser.get('triggering', 'CFS_hours_back'))
   stateFile = parser.get('triggering', 'long_range_regrid_state_file')
   parms = Parms(cfsDir, cfsNumEnsemble, maxFcstHourCfs, hoursBackCfs,
                 stateFile)
   return parms

#----------------------------------------------------------------------------
def regridCFS(parmFile, cfsFname):
   """Invoke CFS regridding (see Long_Range_Forcing.py)

   Parameters
   ----------
   parmFile : str
      name of param file
   fname: str
      name of file to regrid and downscale, with yyyymmdd parent dir

   Returns
   -------
   None

   """
   WhfLog.info("REGRIDDING CFS DATA, file=%s", cfsFname)
   try:
      lrf.forcing(parmFile, cfsFname)    
   except:
      WhfLog.info("ERROR REGRIDDING CFS DATA, file=%s", cfsFname)
      raise
      
   WhfLog.info("DONE REGRIDDING CFS DATA, file=%s", cfsFname)

#----------------------------------------------------------------------------
class Parms:
   """Parameters from the main wrf_hydro param file that are needed 

   Attributes
   ----------
   _cfsDir: str
      Topdir for CFS
   _cfsNumEnsemble: int
      Number of CFS ensembles
   _maxFcstHourCfs: int
      Maximum forecast hour to process, CFS
   _hoursBackCfs: int
      Hours back to maintain state, CFS
   _stateFile: str
      Name of file with state information that is read/written
   """

   def __init__(self, cfsDir, cfsNumEnsemble, maxFcstHourCfs,
                hoursBackCfs, stateFile):
      """Initialization using input args

      Parameters
      ----------
      One to one with attributes, self explanatory
      """
      self._cfsDir = cfsDir
      self._cfsNumEnsemble = cfsNumEnsemble
      self._maxFcstHourCfs = maxFcstHourCfs
      self._hoursBackCfs = hoursBackCfs
      self._stateFile = stateFile

   def debugPrint(self):
      """ Debug logging of content
      """
      WhfLog.debug("Parms: CFS_data = %s", self._cfsDir)
      WhfLog.debug("Parms: CFS_num_ensembles = %d", self._cfsNumEnsemble)
      WhfLog.debug("Parms: MaxFcstHourCfs = %d", self._maxFcstHourCfs)
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
   _cfs
      CFS file names with yyyymmdd parent directory
   """

   #--------------------------------------------------------------------------
   def __init__(self, parmFile):
      """Initialize using parameters read in from a file

      Parameters
      ----------
      parmFile: str
         Name of param file to read
      """

      if (not parmFile):
         self._empty = True
         self._cfs = []
      else:
         self._empty = False
         cf = SafeConfigParser()
         cf.read(parmFile)
         self._cfs = [name for name in cf.get("latest", "cfs").split()]

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
      return self._empty

   #--------------------------------------------------------------------------
   def newest(self):
      """return newest file

      Parameters
      ----------
    
      Returns
      -------
      str
         File name (newest), or empty string
         
      """
      if (self.isEmpty()):
         return ""
      return (self._cfs[-1])
      
   #--------------------------------------------------------------------------
   def initialize(self, cfs):
      """Initialize from DataFiles inputs

      Parameters
      ----------
         cfs: DataFiles
            CFS data
    
      Returns
      -------
         None
      """
      self._empty = False
      self._cfs = cfs.getFnames()

   #--------------------------------------------------------------------------
   def debugPrint(self):
      """ logging debug of contents
      """
      for f in self._cfs:
         WhfLog.debug("State:CFS:%s", f)
        
   #--------------------------------------------------------------------------
   def update(self, time, hoursBack):
      """Update state so that input time is newest one

       Parameters
       ----------
       time: ForecastTime
          The newest time
       hoursBack:
          Maximum issue time hours back compared to time
       
       Returns
       -------
       none
       """
      self._cfs = df.filterWithinNHours(self._cfs, 'CFS', time, hoursBack)
      
   #--------------------------------------------------------------------------
   def addFileIfNew(self, f):
      """ If input file is not in state, add it

      Parameters
      ----------
      f : str
         File name

      Returns
      -------
      bool
         True if added, false if already in the state

      """
      ret = False
      if (not f in self._cfs):
         self._cfs.append(f)
         ret = True
      return ret
   
   #--------------------------------------------------------------------------
   def sortFiles(self):
      """ Sort the files into ascending order for a type

      Note: sort depends on naming being 'nice'

      Parameters
      ----------

      Returns
      -------
      none

      """
      self._cfs.sort()

   #--------------------------------------------------------------------------
   def updateWithNew(self, data, hoursBack):
      """ Update internal state with new data

      The dataType is used to determine which part of state to update

      Parameters
      ----------
      data: DataFiles
         The newest data
      hoursBack: int
         Maximum number of hours back to keep data in state

      Returns
      -------
      list[str]
          The data file names that are are newly added to state
      """
         
      ret = []
      fnames = data.getFnames()
      if (not fnames):
         return ret

      if (self.isEmpty()):
         WhfLog.debug("Adding to empty %s list")
      else:
         sname = self.newest()
         if (not sname):
            WhfLog.error("Expected file, got none")
            return ret
         if (fnames[-1] > sname):
            WhfLog.debug("Newer time encountered")
            # see if issue time has increased and if so, purge old stuff
            # create DataFile objects
            try:
               df0 = df.DataFile(sname[0:8], sname[9:], 'CFS')
               df1 = df.DataFile(fnames[-1][0:8], fnames[-1][9:], 'CFS')
            except FilenameMatchError as fe:
               WhfLog.debug("Skipping file use due to %s", fe)
            except InvalidArgumentError as ie:
               WhfLog.debug("Skipping file use due to %s", ie)

            if (df0._time.inputIsNewerIssueHour(df1._time)):
               WhfLog.debug("Issue hour has increased, purge now")
               self.update(df1._time, hoursBack)

      for f in fnames:
         if (self.addFileIfNew(f)):
            ret.append(f)

      self.sortFiles()
      return ret
        
   #--------------------------------------------------------------------------
   def write(self, parmFile):
      """ Write state to param file

      Parameters
      ----------
         parmFile: Name of file to write to 
            
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
      for f in self._cfs:
         s += f
         s += "\n"
      config.set('latest', 'cfs', s)

      # Write it out
      with open(parmFile, 'wb') as configfile:
         config.write(configfile)


#----------------------------------------------------------------------------
def createStateFile(parms, realtime):
   """  Called if there is no state file, look at data dirs and create state

   Parameters
   ----------
   parms: Parms
      Parameter settings

   Returns
   -------
   none

   Writes out the state file after creating it
   """

   WhfLog.info("Initializing")
   state = State("")


   if (realtime):
      # query directory and get newest model run file, then
      # get all for that and previous issue time
      cfs = df.DataFiles(parms._cfsDir, parms._maxFcstHourCfs, "CFS")
      cfs.setNewestFiles(parms._hoursBackCfs)
      for f in cfs._content:
         f.debugPrint("Newest files: CFS")
      state.initialize(cfs)

   # write out file
   state.write(parms._stateFile)

#----------------------------------------------------------------------------
def run(configFile, realtime):
    if not os.path.exists(configFile):
        print 'ERROR forcing engine config file not found.'
        return 1

    # read in fixed main params
    parms = parmRead(configFile, realtime)
    #parms.debugPrint()

    #if there is not a state file, create one now using newest
    if (not os.path.exists(parms._stateFile)):
        parms.debugPrint()
        createStateFile(parms, realtime)
        
    # begin normal processing situation
    WhfLog.debug("....Check for new input data to regid")
    
    # read in state
    state = State(parms._stateFile)
    
    # query directory and get newest model run file, then
    # get all for that and previous issue time
    cfs = df.DataFiles(parms._cfsDir, parms._maxFcstHourCfs, "CFS")
    cfs.setNewestFiles(parms._hoursBackCfs)

    # Same with CFS
    toProcess = state.updateWithNew(cfs, parms._hoursBackCfs)
    for f in toProcess:
        regridCFS(configFile, f)

    # write out state and exit
    #state.debugPrint()
    state.write(parms._stateFile)
    return 0

#----------------------------------------------------------------------------
def main(argv):
    return run(argv[0], True)

#----------------------------------------------

if __name__ == "__main__":
    main(sys.argv[1:])
