# -----------------------------------------------------
#             replayAll.py
# -----------------------------------------------------

#  Overview:
#  This is script that will replay a range of times, first doing
#  regridding and downscaling, then the layering.  It runs through
#  the configured times in order by invoking the same scripts that run
#  in real time.
#

import os
import sys
import re
import shutil
import time
from datetime import timedelta

# Pull in scripts from the Python (real time) directory
sys.path.insert(0, '../Python')
import WRF_Hydro_forcing as whf
import DataFiles as df
import Regrid_Driver
import ShortRangeLayeringDriver as srf
import AnalysisAssimLayeringDriver as aa
import WhfLog
from ConfigParser import SafeConfigParser
from ForcingEngineError import MissingDirectoryError
from ForcingEngineError import MissingFileError
from ForcingEngineError import InvalidArgumentError

#----------------------------------------------------------------------------
def parmRead(fname):
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

   dataDirMRMS = parser.get('data_dir', 'MRMS_data')
   sourceDataDirMRMS = parser.get('source_data_dir', 'MRMS_data')
   stateFileMRMS = parser.get('triggering', 'MRMS_regrid_state_file')
   formatMRMS = parser.get('data_dir', 'MRMS_format')

   dataDirHRRR = parser.get('data_dir', 'HRRR_data')
   sourceDataDirHRRR = parser.get('source_data_dir', 'HRRR_data')
   stateFileHRRR = parser.get('triggering', 'HRRR_regrid_state_file')
   formatHRRR = parser.get('data_dir', 'HRRR_format')

   dataDirRAP = parser.get('data_dir', 'RAP_data')
   sourceDataDirRAP = parser.get('source_data_dir', 'RAP_data')
   stateFileRAP = parser.get('triggering', 'RAP_regrid_state_file')
   formatRAP = parser.get('data_dir', 'RAP_format')

   dataDirGFS = parser.get('data_dir', 'GFS_data')
   sourceDataDirGFS = parser.get('source_data_dir', 'GFS_data')
   stateFileGFS = parser.get('triggering', 'GFS_regrid_state_file')
   formatGFS = parser.get('data_dir', 'GFS_format')

   stateFileShortRange = parser.get('triggering',
                                    'short_range_layering_state_file')
   stateFileAnalAssim = parser.get('triggering',
                                   'analysis_assim_layering_state_file')

   parser2 = SafeConfigParser()
   parser2.read('../../parm/replay.parm')
   days = [name for name in parser2.get('times', 'days').split()]

   delta = int(parser2.get('times', 'short_forecast_resolution_hours'))
   issue = range(int(parser2.get('times', 'short_issue_hour0')),
                 int(parser2.get('times', 'short_issue_hour1'))+delta,
                 delta)
   fcst = range(int(parser2.get('times', 'short_forecast_hour0')),
                int(parser2.get('times', 'short_forecast_hour1'))+delta,
                delta)
                 

   delta = int(parser2.get('times', 'medium_forecast_resolution_hours'))
   medium_issue = range(int(parser2.get('times', 'medium_issue_hour0')),
                        int(parser2.get('times', 'medium_issue_hour1')) + delta,
                        delta)

   medium_fcst = range(int(parser2.get('times', 'medium_forecast_hour0')),
                       int(parser2.get('times', 'medium_forecast_hour1'))+delta,
                       delta)

   hrrrFinishedDir = parser.get('downscaling', 'HRRR_finished_output_dir')
   rapFinishedDir = parser.get('downscaling', 'RAP_finished_output_dir')
   hrrrFinished0hrDir = parser.get('downscaling','HRRR_finished_output_dir_0hr')
   mrmsFinishedDir = parser.get('regridding', 'MRMS_finished_output_dir')
   rapFinished0hrDir = parser.get('downscaling', 'RAP_finished_output_dir_0hr')

   parms = Parms(dataDirMRMS, sourceDataDirMRMS, stateFileMRMS, formatMRMS,
                 dataDirHRRR, sourceDataDirHRRR, stateFileHRRR, formatHRRR,
                 dataDirRAP, sourceDataDirRAP, stateFileRAP, formatRAP,
                 dataDirGFS, sourceDataDirGFS, stateFileGFS, formatGFS,
                 stateFileShortRange, stateFileAnalAssim,
                 days, issue, fcst, medium_issue, medium_fcst,
                 hrrrFinishedDir, rapFinishedDir, hrrrFinished0hrDir,
                 rapFinished0hrDir, mrmsFinishedDir)
   return parms

#----------------------------------------------------------------------------
class ParmInput:
   """Parameters from the main wrf_hydro param file for one input

   Attributes
   ----------
   _dataType: str
      Type name of data (HRRR, RAP, ...)
   _dataDir: str
      Topdir for data
   _sourceDataDir: str
      Topdir for input data
   _stateFile: str
      Path of state file
   _format: str
      Format string used to build file names
   """

   def __init__(self, dataType, dataDir, sourceDataDir, stateFile, format):
      """Initialization using input args

      Parameters
      ----------
      One to one with attributes, self explanatory
      """
      self._dataType = dataType
      self._dataDir = dataDir
      self._sourceDataDir = sourceDataDir
      self._stateFile = stateFile
      self._format = format

   def debugPrint(self):
      """ Debug logging of content
      """
      WhfLog.debug("%s data = %s", self._dataType, self._dataDir)
      WhfLog.debug("%s source = %s", self._dataType, self._sourceDataDir)
      WhfLog.debug("%s statefile = %s", self._dataType, self._stateFile)
      WhfLog.debug("%s format = %s", self._dataType, self._format)

   def debugPrintOut(self):
      """ Debug logging of content
      """
      print self._dataType, " data = ", self._dataDir
      print self._dataType, " source = ", self._sourceDataDir
      print self._dataType, " statefile = ", self._stateFile
      print self._dataType, " format = ", self._format

#----------------------------------------------------------------------------
class Parms:
   """Parameters from the main wrf_hydro param file that are needed 

   Attributes
   ----------
   _inputs: [ParmInput]
      The inputs
   """

   def __init__(self,
                dataDirMRMS, sourceDataDirMRMS, stateFileMRMS, formatMRMS,
                dataDirHRRR, sourceDataDirHRRR, stateFileHRRR, formatHRRR,
                dataDirRAP, sourceDataDirRAP, stateFileRAP, formatRAP,
                dataDirGFS, sourceDataDirGFS, stateFileGFS, formatGFS,
                stateFileShortRange, stateFileAnalAssim,
                days, issue, fcst, medium_issue, medium_fcst,
                hrrrFinishedDir, rapFinishedDir, hrrrFinished0hrDir,
                rapFinished0hrDir, mrmsFinishedDir):
      """Initialization using input args

      Parameters
      ----------
      One to one with attributes, self explanatory
      """
      self._inputs = []
      p = ParmInput('MRMS', dataDirMRMS, sourceDataDirMRMS, stateFileMRMS,
                    formatMRMS)
      self._inputs.append(p)

      p = ParmInput('HRRR', dataDirHRRR, sourceDataDirHRRR, stateFileHRRR,
                    formatHRRR)
      self._inputs.append(p)

      p = ParmInput('RAP', dataDirRAP, sourceDataDirRAP, stateFileRAP,
                    formatRAP)
      self._inputs.append(p)

      p = ParmInput('GFS', dataDirGFS, sourceDataDirGFS, stateFileGFS,
                    formatGFS)
      self._inputs.append(p)

      self._stateFileShortRange = stateFileShortRange
      self._stateFileAnalAssim = stateFileAnalAssim

      self._days = days
      self._issue = issue
      self._fcst = fcst
      self._medium_issue = medium_issue
      self._medium_fcst = medium_fcst

      self._hrrrFinishedDir = hrrrFinishedDir
      self._rapFinishedDir = rapFinishedDir
      self._hrrrFinished0hrDir = hrrrFinished0hrDir
      self._rapFinished0hrDir = rapFinished0hrDir
      self._mrmsFinishedDir = mrmsFinishedDir

      self._finishedDirs = [mrmsFinishedDir, hrrrFinishedDir, rapFinishedDir,
                            hrrrFinished0hrDir, rapFinished0hrDir]

   def getInputParms(self, which):
      for p in self._inputs:
         if (p._dataType == which):
            return p
      raise InvalidArgumentError(which)
   
   def debugPrint(self):
      """ Debug logging of content
      """
      for p in self._inputs:
         p.debugPrint()

   def debugPrintOut(self):
      """ Debug logging of content
      """
      for p in self._inputs:
         p.debugPrintOut()
      print "days = ", self._days
      print "issue = ", self._issue
      print "fcst = ", self._fcst
      print "medium_issue = ", self._medium_issue
      print "medium_fcst = ", self._medium_fcst

#----------------------------------------------------------------------------
def removeYmdDirs(source_dir):
   '''Remove the yyyymmdd subdirectories of source_dir
   '''
   try:
      #Source directory
      dirExists(source_dir)

   except MissingDirectoryError:
      print "Source directory missing. Check directory path", source_dir

   else:
      # Get ymd subdirectories
      ymdDirs = df.getYyyymmddSubdirectories(source_dir)
      for ymd in ymdDirs:
         path = source_dir + "/" + ymd
         print "Removing -r ", path
         shutil.rmtree(path)

#----------------------------------------------------------------------------
def initialize(source_dir, destination_dir):
   '''Initialize by looking at source_dir, and creating destination_dir
   Args:
      source_dir (string) : Full path to source data, subdir yyyymmdd
      destination_dir(string) : Full path to destination
   Returns:
      list of source file paths, ordered
   '''
   try:
      #Source directory
      dirExists(source_dir)
   except MissingDirectoryError:
      print "Source directory missing. Check directory path ", source_dir
      files = []
   else:
      # Get a directory listing and save all files with the specified
      # extension.
      files = whf.get_filepaths(source_dir)
      files = sorted(files)
      print "Numfiles in ", source_dir, " = ", len(files)

   try:
      #Destination directory
      dirExists(destination_dir)
   except MissingDirectoryError:
      print "Destination directory does not exist, creating it now ", destination_dir
      whf.mkdir_p(destination_dir)

   return files

#----------------------------------------------------------------------------
def moveFiles(source_dir, destination_dir):
   '''Moves all the files from the source directory to the destination directory.
   Args:
      source_dir (string):      Full path to the source directory
      destination_dir (string): Full path to the destination directory

   Returns:
      None
   '''
   files = initialize(source_dir, destination_dir)

   #move the files
   for f in files:
      moveFile(f, destination_dir)

#----------------------------------------------------------------------------
def moveFile(fname, destination_dir):
   '''Moves one file to the destination directory.
   Args:
      fname (string):      File to move
      destination_dir (string): Full path to the destination directory

   Returns:
      None
   '''

   #separate the filename from the directory and the
   #date directory
   date_match = re.match(r'.*/([0-9]{8})',fname)
   if date_match:
      date_dir = date_match.group(1)
   else:
      print "No date directory found, exiting"
      raise MissingDirectoryError("No date directory")
            
   # Just the filename, no path
   exp = re.compile(r'.*/[0-9]{8}/(.*.grib2|.*.grb2)')
   file_match = exp.match(fname)
   if file_match:
      filename_only = file_match.group(1)
   else: 
      print "No file name match, exiting"
      raise MissingFileError("No file matching the expected pattern") 

   dest_path = destination_dir + "/" + date_dir
   whf.mkdir_p(dest_path)
   dest = dest_path + "/" + filename_only

   print "Move ", fname, " to ", dest
   shutil.move(fname, dest)

#----------------------------------------------------------------------------
def process(configFile, parm):
   '''Moves all the files from the source directory to the destination directory.
   Args:
      fileType (string) : 
      source_dir (string):      Full path to the source directory
      destination_dir (string): Full path to the destination directory
      extension (string):       File extension of files to be moved

   Returns:
      None
   '''

   # initialize the logging first
   parser = SafeConfigParser()
   parser.read(configFile)
   WhfLog.init(parser, 'RegridMRMS', True)  # just use any valid 2nd arg
   for day in parm._days:
      processDay(configFile, day, parm)

#----------------------------------------------------------------------------
def processDay(configFile, day, parm):
   print "Processing day", day
   for iHr in parm._issue:
      processIssue(configFile, day, iHr, parm)
   for iHr in parm._medium_issue:
      processMediumIssue(configFile, day, iHr, parm)

#----------------------------------------------------------------------------
def processIssue(configFile, day, iHr, parm):
   mrms = processMrms(configFile, day, iHr, parm)
   for fHr in parm._fcst:
      processOneForecast(mrms, configFile, day, iHr, fHr, parm)
      
#----------------------------------------------------------------------------
def processOneForecast(mrms, configFile, day, iHr, fHr, parm):
   hrrr = processFcst(configFile, day, iHr, fHr, parm, 'HRRR')
   rap = processFcst(configFile, day, iHr, fHr, parm, 'RAP')
   print "(mrs,hrrr,rap)=(", mrms, ",", hrrr, ",", rap, ")"

   cmd = 'ShortRangeLayering('  + configFile + ")"
   print cmd
   startTime = time.time()
   srf.run(configFile, False)
   elapsed = time.time() - startTime
   print "Done ShortRangeLayering, elapsed=", str(timedelta(seconds=elapsed))

   cmd = 'AnalysisAssimLayering('  + configFile + ")"
   print cmd
   startTime = time.time()
   aa.run(configFile, False)
   elapsed = time.time() - startTime
   print "Done AnalysisAssimLayering elapsed=", str(timedelta(seconds=elapsed))

#----------------------------------------------------------------------------
def processMediumIssue(configFile, day, iHr, parm):
   for fHr in parm._medium_fcst:
      gfs = processFcst(configFile, day, iHr, fHr, parm, 'GFS')
      print "(gfs)=(", gfs, ")"

#----------------------------------------------------------------------------
def processMrms(configFile, day, iHr, parm):

   iparm = parm.getInputParms('MRMS')

   # process the file, only if it is there
   sourceDir = iparm._sourceDataDir
   destDir = iparm._dataDir

   fileName = sourceDir + "/" + str(day) + "/"
   fileName += iparm._format%(str(day), iHr)

   if os.path.exists(fileName):
      processFile(fileName, 'MRMS', configFile, destDir)
      return True
   else:
      return False
   
#----------------------------------------------------------------------------
def processFcst(configFile, day, iHr, fHr, parm, ftype):
   print "Processing ", day, " issue:", iHr, " fcst:", fHr, " ", ftype
   iparm = parm.getInputParms(ftype)
   name = iparm._format%(str(day), iHr, fHr)
   sourceDir = iparm._sourceDataDir
   destDir = iparm._dataDir

   fileName = sourceDir + "/" + str(day) + "/" + name
   if os.path.exists(fileName):
      processFile(fileName, ftype, configFile, destDir)
      return True
   else:
      return False

#----------------------------------------------------------------------------
def processFile(fname, fileType, configFile, destination_dir):
   '''Processes one file
   Args:
      fname  (string) :         File name
      fileType (string) :       HRRR, MRMS, ...
      destination_dir (string): Full path to the destination directory
      extension (string):       File extension of files to be moved

   Returns:
      None
   '''

   moveFile(fname, destination_dir)

   cmd = 'Regrid_Driver.run(' + fileType + ',' + configFile + ")"
   print cmd
   startTime = time.time()
   Regrid_Driver.run(fileType, configFile, False)
   elapsed = time.time() - startTime
   print "Done Regrid_Driver.run(), elapsed=", str(timedelta(seconds=elapsed))

#----------------------------------------------------------------------------
def dirExists(dir):
   """ Check for directory existence
       Args:
           dir (string): The directory in question.
   """

   if not os.path.isdir(dir):
      raise MissingDirectoryError('Directory %s not found'%dir)

#----------------------------------------------------------------------------
def cleanForReplay(parms):
   for p in parms._inputs:
      if os.path.exists(p._stateFile):
         print "Removing ", p._stateFile
         os.remove(p._stateFile)
   if os.path.exists(parms._stateFileShortRange):
      print "Removing", parms._stateFileShortRange
      os.remove(parms._stateFileShortRange)
      
   if os.path.exists(parms._stateFileAnalAssim):
      print "Removing", parms._stateFileAnalAssim
      os.remove(parms._stateFileAnalAssim)
      
   for f in parms._finishedDirs:
      print "remove ", f
      if (os.path.exists(f)):
         shutil.rmtree(f)

#----------------------------------------------------------------------------
def main(argv):
   usage =  "Usage: python replayAll.py [parmfile] [replay|reset]"
   if len(argv) < 2:
      print usage
      return 1
    
   configFile = argv[0]
   use = argv[1]

   good = True
   if not os.path.exists(configFile):
      good = False
      print "Config file not there ", configFile
   types = ['replay', 'reset']
   if (use not in types):
      good = False
      print "Last arg should be replay or reset"
   if (not good):
      print usage
      return 1

   # read in fixed main params
   parms = parmRead(configFile)
   parms.debugPrintOut()

   if (use == 'replay'):
      cleanForReplay(parms)
      process(configFile, parms)
   elif (use == 'reset'):
      for p in parms._inputs:
         moveFiles(p._dataDir, p._sourceDataDir)
         removeYmdDirs(p._dataDir)
   else:
      print usage

#----------------------------------------------------------------------------
if __name__ == "__main__":
   main(sys.argv[1:])

