"""DataFiles
Handles individual and grouped data files.
"""

import os
import logging
import datetime
import errno
import WhfLog
from ForcingEngineError import InvalidArgumentError

#----------------------------------------------------------------------------
def stringToBool(s):
    """ Convert integer string (1 or 0) to boolean
    Parameters
    ----------
    s : str
       string, hopefully 1 or 0
    Returns
    -------
    Boolean True if 1, False if 0
    """
    i = int(s)
    if (i == 0):
        return False
    elif (i == 1):
        return True
    else
        raise InvalidArgumentError(s)
    
#----------------------------------------------------------------------------
def boolToInt(b):
    """ Convert boolean to integer 1 or 0, just in case
    Parameters
    ----------
    b : boolean
       
    Returns
    -------
    1 for True, 0 for False
    """
    if (b):
        return 1
    else:
        return 0
    
#----------------------------------------------------------------------------
def makeDirIfNeeded(path):
   """ Input is a to be a directory, make it if it does not exist.

   Parameters
   ----------
   path : str
      full path

   Returns
   -------
   bool
      True if directory exists, or was created, false if error
   """

   try:
      os.makedirs(path)
      return True
   except OSError as exception:
      if exception.errno != errno.EEXIST:
         WhfLog.error("ERROR creating %s", path)
         return False
      else:
         return True

#----------------------------------------------------------------------------
def isYyyymmdd(name):
   """Check if input string is of format yyyymmdd

   Parameters
   ----------
   name: str
       Name to check

   Returns
   -------
   bool
       True if successful, False otherwise.

   """
   if (len(name) == 8):
      if (datetime.datetime.strptime(name, '%Y%m%d')):
         return True
   return False

#----------------------------------------------------------------------------
def isYyyymmddhh(name):
    """Check if a string is of format yyyymmddhh

    Parameters
    ----------
    name : str
       Name to check

    Returns
    -------
    bool
        true if name has that format
    """
    if (len(name) == 10):
        if (datetime.datetime.strptime(name, '%Y%m%d%H')):
            return True
    return False

#----------------------------------------------------------------------------
def isYyyymmddhhmmss(name):
    """Check if a string is of format yyyymmddhhmmss

    Parameters
    ----------
    name : str
       Name to check

    Returns
    -------
    bool
        true if name has that format
    """
    if (len(name) == 14):
        if (datetime.datetime.strptime(name, '%Y%m%d%H%M%S')):
            return True
    return False

#----------------------------------------------------------------------------
def dates(names):
   """filter a list of strings down to those that are of the 'yyyymmdd' format

   Parameters
   ----------
   names: list[str]
      List of string to check

   Returns
   -------
   list[str]
      Subset of input with 'yyyymmdd' strings only

   """
   return [name for name in names if (isYyyymmdd(name))]

#----------------------------------------------------------------------------
#
# filter a list of names to those that are dates of format yyyymmddhh
#
# names = list of names
#
# return filtered list
#
def datesWithHour(names):
    """Filter a list down to elements that have format yyyymmdd

    Parameters
    ----------
    names : list[str]
        The names to filter

    Returns
    -------
    list[str]
        The filtered names
    """
    return [name for name in names if (isYyyymmddhh(name))]

    
    
#----------------------------------------------------------------------------
def getFileNames(aDir):
   """Return the files in a directory that are not themselves subdirectories

   Parameters
   ----------
   aDir: str
      Full path directory name

   Returns
   -------
   List[str]
      the data files in the directory
   """
   return [name for name in os.listdir(aDir)
           if not os.path.isdir(os.path.join(aDir, name))]

#----------------------------------------------------------------------------
def getImmediateSubdirectories(aDir):
   """return the subdirectories of a directory

   Parameters
   ----------
   aDir: str
      Full path directory name

   Returns
   -------
   list[str]
      All subdirectories of the aDir

   """

   if (not os.path.exists(aDir)):
      return []
   
   return [name for name in os.listdir(aDir)
           if os.path.isdir(os.path.join(aDir, name))]

#---------------------------------------------------------------------------
def getYyyymmddSubdirectories(aDir):
   """return the 'yyyymmdd' subdirectories of a directory

   Parameters
   ----------
   aDir: str
      Full path directory name

   Returns
   -------
   list[str]
      All subdirectories of the aDir that are of format 'yyyymmdd'

   """
   names = getImmediateSubdirectories(aDir)
   return dates(names)

#---------------------------------------------------------------------------
def getYyyymmddhhSubdirectories(dir):
   """return the 'yyyymmddhh' subdirectories of a directory

   Parameters
   ----------
   aDir: str
      Full path directory name

   Returns
   -------
   list[str]
      All subdirectories of the aDir that are of format 'yyyymmddhh'

   """
   names = getImmediateSubdirectories(dir)
   return datesWithHour(names)

#----------------------------------------------------------------------------
def filterWithinNHours(files, type, ftime, N):
   """Filter a list of file names with assumed format to those in a time range
       
   Parameters
   ----------
   files: list[str]
      file names, each with parent directory: 'yyyymmdd/<file>
   type: str
      file type string, 'RAP', 'HRRR', 'MRMS', GFS'
   ftime: ForecastTime
      time to compare against, assumed most recent time
   N: int
      Number of hours back from ftime to keep

   Returns
   -------
   list[str]
      subset of input files with issue time is in the range [ftime-N,ftime]

   """

   ret = []
   for f in files:
      df = DataFile(f[0:8], f[9:], type)
      if (df._ok):
         ithFtime = df._time
         if (ithFtime.withinNHours(ftime, N)):
            ret.append(f)
         else:
            WhfLog.debug("Did not append file, too old compared to %s  file=%s", ftime.debugString(), f)

   WhfLog.debug("filtering within %d hours, input length %d output %d",
                 N, len(files), len(ret))
   return ret
        
#----------------------------------------------------------------------------
def newestIssueTime(dir):
    """return the subdirectory (yyyymmddhh) that is for the newest issue time

    Parameters
    ----------
    dir : str
       Directory with subdirectories

    Returns
    -------
    str
       The subdirectory with biggest issue time, or empty string
    """       
    names = getYyyymmddhhSubdirectories(dir)
    if (not names):
        return ""

    names = sorted(names)
    return names[-1]
    
#---------------------------------------------------------------------------
class DataFile:
   """DataFile is One data file

   Attributes
   ----------
   _ok : bool
      True if object has valid content
   _yyyymmddDir: str
      Directory for this data file
   _name: str
      Name of file withn the directory
   _fileType: str
      string for type 'HRRR', 'MRMS', 'RAP', 'GFS'
   _time: ForecastTime
      forecast time information, can be parsed from name
   """

   def __init__(self, yyyymmdd="", fileName="", fileType=""):
      """Initialization using input args

      Parameters
      ----------
      yyyymmdd: str
         Directory for this data file
      name: str
         Name of file withn the directory
      fileType: str
         string for type 'HRRR', 'MRMS', 'RAP', 'GFS'
      """

      # not yet ok
      self._ok = False

      # copy stuff in
      self._yyyymmddDir = yyyymmdd
      self._name = fileName
      self._fileType = fileType

      # empty time
      self._time = ForecastTime(datetime.datetime, -1, -1)

      # if not a valid input, return now with ok=0
      if ((not yyyymmdd) or (not fileName)):
         return

      # parse depends on type (parse methods set time)
      if (fileType == "MRMS"):
         self._parseMrmsFile(fileName)
      else:
         self._parseNonMrmsFile(fileName)

   def debugPrint(self, name):
      """WhfLog.debug call with description of this data

      Parameters
      ----------
      name: string
         name that is included in the description

      Returns
      -------
         none

      """
      WhfLog.debug("%s[%s]=%s, %s, %s", name, self._yyyymmddDir,
                    self._name, self._fileType,
                    self._time.debugString())
                      
   def debugString(self):
      """WhfLog.debug call with description of this data

      Returns
      -------
         string

      """
      s = '%s,%s, %s, %s' %(self._yyyymmddDir,self._name, self._fileType, self._time.debugString())
      return s
                      
   def inRange(self, oldestT, newestT):
      """return true if the local _time is between input times

      Parameters
      ----------
      oldestT:  ForecastTime
         earliest allowed time to be in range
      newestT:  ForecastTime
         latest allowed time to be in range

      Returns
      -------
         true if issue times of oldestT <= self._time <= newestT

      """
      return (self._time.inputIsNewerThanOrEqual(newestT) and
              oldestT.inputIsNewerThanOrEqual(self._time))

   def forecastHourInRange(self, maxFcstHour):
      """return true if the forecast hour of local _time is <= max

      Parameters
      ----------
      maxFcstHour: int
         maximum allowed forecast hour

      Returns
      -------
         true if the self._time has a forecast hour <= maxFcstHour

      """
      if (self._ok):
         return self._time.forecastHourInRange(maxFcstHour)
      else:
         return False
            
   def fullPathFileName(self):
      """return full path name built from local content

      Parameters
      ----------
      none

      Returns
      -------
      str
         file name with parent yyyymmdd directory 'yyyymmdd/<file>'

      """
      ret = self._yyyymmddDir + "/"
      ret += self._name
      return ret

   def _parseNonMrmsFile(self, fileName):
      """Parse a file name to set local _time, non MRMS, store to _time

      If successful, sets self._time and sets self._ok = true

      Parameters
      ----------
      fileName: str
         File name, hopefully of format yyyymmdd_ihh_fhhh_<whatever>
      Returns
      -------
      none

      """
      if (len(fileName) >= 17):
         ymd = fileName[0:8]
         if (isYyyymmdd(ymd)):
            itime = int(fileName[10:12])
            ftime = int(fileName[14:17])
            self._time = ForecastTime(datetime.datetime.strptime(ymd,
                                                                 '%Y%m%d'),
                                      itime, ftime)
            self._ok = True
        
   def _parseMrmsFile(self, fileName):
      """Parse a file name to set local _time, MRMS, store to _time

      If successful, sets self._time and sets self._ok = true

      Parameters
      ----------
      fileName: str
         File name, format GaugeCorr_QPE_00.00_yyyymmdd_hhmmss.grib2
      Returns
      -------
      none

      """
      if (len(fileName) >= 35):
         ymd = fileName[20:28]
         if (isYyyymmdd(ymd)):
            itime = int(fileName[29:31])
            # Note forecast hour is 0 here
            self._time = ForecastTime(datetime.datetime.strptime(ymd,
                                                                 '%Y%m%d'),
                                      itime, 0)
            self._ok = True

    
#----------------------------------------------------------------------------
class DataFiles:
   """DataFiles are any number of DataFile objects, for a directory/file type

   Attributes
   ----------
   _topDir: str
      full path to the top directory (which has yyyymmdd subdirectories)
   _fileType: str
      string for type 'HRRR', 'MRMS', 'RAP', 'GFS'
   _maxFcstHour: int
      maximum allowed forecast hour
   _content: list[DataFile]
      The list itself, which depends on current use
   """

   def __init__(self, dir, maxFcstHour, fileType):
      """Initialization using input args

      _content is set empty

      Parameters
      ----------
      dir: str
         full path to the top directory (which has yyyymmdd subdirectories)
      maxFcstHour: int
         maximum allowed forecast hour
      fileType: str
         string for type 'HRRR', 'MRMS', 'RAP', 'GFS'
      """

      self._topDir = dir
      self._maxFcstHour = maxFcstHour
      self._fileType = fileType
      self._content = []  # no content in constructor
            
   def printContent(self):
      print "Content:"
      for c in self._content:
         print c.debugString()

   def setNewestFiles(self, hoursBack):
      """Set _content to files that are the most recent ones.

      Parameters
      ----------
      hoursBack: int
         Maximum number of hours back compared to newest issue time to consider
         a file new enough to be a newest file
      
      Returns
      -------
      true if successful and there is at least one file in _content

      """

      # Clear content
      self._content = []

      # get the newest DataFile
      newestF = self._newestDataFile()
      if (not newestF._ok):
         WhfLog.debug("setNewestFiles:No data in %s", self._topDir)
         return False

      # create a new ForecastTime that is hoursBack 
      oldestTime = ForecastTime()
      oldestTime.copyFields(newestF._time)
      oldestTime.olderIssueHour(hoursBack)

      # build up all the files on disk
      dataFiles = self._allDataFiles()

      # filter to those in range and put those as _content
      for d in dataFiles:
         if (d.inRange(oldestTime, newestF._time)):
            self._content.append(d)
      return True

   def getFnames(self):
      """Return the full path file names for everything in _content

      Parameters
      ----------
      none

      Returns
      -------
      list[str]   The files

      """
      ret = []
      for f in self._content:
         ret.append(f.fullPathFileName())
      return ret
            
   def _newestDataFile(self):
      """Return the newest (biggest issuetime in newest day, max fcst hour) file

      Parameters
      ----------
      none

      Returns
      -------
      DataFile
         Empty or the newest one with content

      """

      dirs = getYyyymmddSubdirectories(self._topDir)
      # sort them into ascending order
      dirs = sorted(dirs)
      if not dirs:
         # nothing there
         WhfLog.debug("_newestDatFile:No data in %s", self._topDir)
         return DataFile()
      else:
         # The last directory will be newest, look there for our newest
         return self._newestDataFileInDir(dirs[-1])
   
   def _allDataFiles(self):
      """Return all data files on disk, in order

      Parameters
      ----------
      none

      Returns
      -------
      list[DataFile]
         The DataFile specs, in order oldest to newest

      """

      # get the yyyymmdd subdirs
      dirs = getYyyymmddSubdirectories(self._topDir)

      # sort them into ascending order
      dirs = sorted(dirs)

      if not dirs:
         # nothing there
         WhfLog.debug("_allDataFiles: No data in %s", self._topDir)
         return []
      else:
         # make one big array
         ret = []
         for d in dirs:
            ret.extend(self._allDataFilesInDir(d))
         return ret

   def _allDataFilesInDir(self, ymdDir):
      """Return all data files in a directory with forecast hour in range

      Parameters
      ----------
      ymdDir: str
         subdirectory of _topDir to look in

      Returns
      -------
      list[DataFile]
         The DataFiles in order

      """

      # get all files
      fileNames = getFileNames(self._topDir + "/" + ymdDir)
      
      # sorting succes depends on a nice file naming scheme!!!
      fileNames = sorted(fileNames)

      # Create DataFile objects from this list of names whose forecast
      # times are in range, and return 
      # names
      return self._filterFileNamesToInRangeDataFiles(ymdDir, fileNames)

   def _newestDataFileInDir(self, ymdDir):
      """Return newest data file in a directory

      Parameters
      ----------
      ymdDir: str
         subdirectory of _topDir to look in

      Returns
      -------
      DataFile

      """

      # get all files
      dataFiles = self._allDataFilesInDir(ymdDir)
      if not dataFiles:
         return DataFile()
      else:
         return dataFiles[-1]

   #
   # Filter an input list of file names, keeping only those that are
   # data files in the known formats, that have forecast hour in range
   #
   # Return filtered list
   #
   def _filterFileNamesToInRangeDataFiles(self, ymdDir, files):
      """Filter input list of file names, keep only data files

      Parameters
      ----------
      ymdDir: str
         subdirectory of _topDir to look in
      files: list[str]
         file names

      Returns
      -------
      list[DataFile]

      """

      datafiles = []
      for f in files:
         df = DataFile(ymdDir, f, self._fileType)
         if (df.forecastHourInRange(self._maxFcstHour)):
            datafiles.append(df)
      return datafiles

#----------------------------------------------------------------------------
class ForecastTime:
   """ Forecast time (model ymd, model issue hour, model forecast hour)

   Attributes
   ----------
   _fcstTime: datetime.datetime
      year/month/day 
   _issueHour: int
      issue hour 0, 1, ..., 23
   _forecastHour: int
      forecast hour 0, 1, ...

   An empty object of this type has issue hour < 0
   
   """
   def __init__(self, fcstTime=datetime.datetime,
                 issueHour=-1, forecastHour=-1):
      """ Initialize using input args
      Parameters
      ----------
      fstTime: datetime.datetime
      issueHour: int
      forecastHour:int
      """

      self._fcstTime = fcstTime
      self._issueHour = issueHour
      self._forecastHour = forecastHour

   def isEmpty(self):
      """ Check if object has been set or not

      Returns
      -------
      True if object has NOT been set
      """
      return (self._issueHour == -1)

   def ymdh(self):
      """ return the datetime for the model run(year/month/day/issue hour)
      Returns
      -------
      datetime
         Model run time
      """
      return self._fcstTime + datetime.timedelta(hours=self._issueHour)
    
   def copyFields(self, f):
      """ c++ like Copy constructor
      Parameters
      ----------
      f : ForecastTime
         Object to copy contents into local state
      """
      self._fcstTime = f._fcstTime
      self._issueHour = f._issueHour
      self._forecastHour = f._forecastHour

   def debugPrint(self):
      """ logging debug of content
      """
      WhfLog.debug("%s,i[%s],f[%s]", self._fcstTime, self._issueHour,
                     self._forecastHour)

   def debugString(self):
      """ debug contents, as a string
      Returns
      -------
      str
         A description
      """
      s = '%s,i[%s],f[%s]' %(self._fcstTime, self._issueHour,self._forecastHour)
      return s

   def forecastHourInRange(self, maxFcstHour):
      """ Check if forecast hour is not too large

      Parameters
      ----------
      maxFcstHour : int
         The maximum allowed forecast hout

      Returns
      -------
      true if forecast hour is in range (not too big)

      """
      if (self.isEmpty()):
         return False
      else:
         return self._forecastHour <= maxFcstHour
         
   #
   # Return ForecastTime that is the earliest lead in the previous
   # issue hour relative to local values
   #
   def olderIssueHour(self, hoursBack):
      """ Return the ForecastTime that has hoursBack hours earlier issue time

      Parameters
      ----------
      hoursBack: int
         Number of hours back to look

      Returns
      -------
      ForecastTime
         Forecast with issue time hoursBack earlier than local, forecastHour=0
      """          
      if (self.isEmpty()):
         WhfLog.debug("ERROR empty input to olderIssueHour")
      else:
         timeBack = self.ymdh() - datetime.timedelta(hours=hoursBack)
         self._fcstTime = datetime.datetime(timeBack.year, timeBack.month,
                                            timeBack.day, 0, 0, 0)
         self._issueHour = timeBack.hour
         self._forecastHour = 0

   def inputIsNewerThanOrEqual(self, ftime):
      """ Check if input time is >= local

      Parameters
      ----------
      ftime: ForecastTime

      Returns
      -------
      True if ftime >= self
      """
      if (self._fcstTime < ftime._fcstTime):
         return True
      elif (self._fcstTime == ftime._fcstTime):
         if (self._issueHour < ftime._issueHour):
            return True
         elif (self._issueHour == ftime._issueHour):
            if (self._forecastHour <= ftime._forecastHour):
               return True
      return False

   def inputIsNewerIssueHour(self, ftime):
      """ Check if input forecast time has issue hour newer than self

      Parameters
      ----------
      ftime: ForecastTime
      Returns
      -------
      True if ftime has issue hour newer than self
      """
      if (self._fcstTime < ftime._fcstTime):
         return True
      elif (self._fcstTime == ftime._fcstTime):
         if (self._issueHour < ftime._issueHour):
            return True
      return False

   def withinNHours(self, ftime, N):
      """ Check if input time is within some number of issue hours of self

      Parameters
      ----------
      ftime: ForecastTime
      N:int
         Number of hours to check
      Returns
      -------
      True if input time - local time <= N hours
      """
      # same day, issue hour match
      # same day, issue hour input - issue hour <= N
      if (self._fcstTime == ftime._fcstTime):
         if (self._issueHour == ftime._issueHour):
            return True
         elif (ftime._issueHour-self._issueHour <= N):
            return True
         else:
            return False
      else:
         # create a full time from local and input states
         timeIn = ftime.ymdh()
         timeLoc = self.ymdh()
         diff = (timeIn - timeLoc).total_seconds()
         maxSeconds = N*3600
         if (diff < 0):
            WhfLog.error("Unexpected data newer than newest")
            return False
         else:
            return (diff <= maxSeconds)

#----------------------------------------------------------------------------
