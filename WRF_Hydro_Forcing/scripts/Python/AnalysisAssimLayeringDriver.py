""" AnalysisAssimLayeringDriver.py
Checks regrid/rescale data directories for new content, and if 
found and time to do so, initiate layering scripts.
Keeps state in a state file that is read/written
each time this script is invoked.  The state
file shows the most recent issue times status as regards inputs and layering.
Logs to a log file that is created in the
same directory from where this script is executed.  
"""

import os
import sys
import datetime
import time
import DataFiles as df
from ConfigParser import SafeConfigParser
import Analysis_Assimilation_Forcing as aaf
import WhfLog

#----------------------------------------------------------------------------
def layer(parms, itime, step, which, config):
    """ Perform layering

    NOTE: here is where returns status will be added and used

    Parameters
    ----------
    parms : Parms
        parameters

    """        

    WhfLog.debug("LAYERING: %s  %d %s", itime.strftime("%Y%m%d%H"),
                  step, which)
    aaf.anal_assim_layer(itime.strftime('%Y%m%d%H'), '-%01d'%(step), which, config)
    WhfLog.debug("DONE LAYERING: %s  %d %s", itime.strftime("%Y%m%d%H"),
                  step, which)

#----------------------------------------------------------------------------
def stepStaticName(index):
    ret = 'step%01d' %(index)
    return ret

#----------------------------------------------------------------------------
def forecastExists(dir, issueTime, fcstHour):
    """ Check if forecast exists

    Parameters
    ----------
    dir : str
       Full path to the issue time directories
    issueTime : datetime
       The issue time (y,m,d,h)       
    fcstHour:  int
       should be 0 or 3

    Returns
    -------
    bool
    True if the forecast does exist on disk
    """
           
    path = dir + "/"
    path += issueTime.strftime("%Y%m%d%H")
    if (os.path.isdir(path)):
        validTime = issueTime + datetime.timedelta(hours=fcstHour)
        fname = validTime.strftime("%Y%m%d%H%M") + ".LDASIN_DOMAIN1.nc"
        names = df.getFileNames(path)
        for n in names:
            if (n == fname):
                WhfLog.debug("Found %s in %s",  fname, path)
                return True
    return False

#----------------------------------------------------------------------------
def obsExists(dir, issueTime):
    """ Check if obs exists

    Parameters
    ----------
    dir : str
       Full path to the MRMS directories
    issueTime : datetime
       The issue time (y,m,d,h)       

    Returns
    -------
    bool
    True if the data does exist on disk
    """
           
    path = dir + "/"
    path += issueTime.strftime("%Y%m%d%H")
    if (os.path.isdir(path)):
        fname = issueTime.strftime("%Y%m%d%H%M") + ".LDASIN_DOMAIN1.nc"
        names = df.getFileNames(path)
        for n in names:
            if (n == fname):
                WhfLog.debug("Found %s in %s",  fname, path)
                return True
    return False

#----------------------------------------------------------------------------
def parmRead(fname, realtime):
    """ Read in a param file

    Parameters
    ---------
    fname : str
       Name of the file to read
    Returns
    -------
    Parms
        The parameters that were read in
    """
    
    parser = SafeConfigParser()
    parser.read(fname)


    forcing_config_label = "AnalysisAssimLayeringDriver"
    if (realtime):
        WhfLog.init(parser, 'AaLayer', False)
    else:
        WhfLog.set('AaLayer')
    hrrrDir = parser.get('downscaling', 'HRRR_finished_output_dir')
    hrrr0hrDir = parser.get('downscaling', 'HRRR_finished_output_dir_0hr') # placeholder
    mrmsDir = parser.get('regridding', 'MRMS_finished_output_dir')  # maybe incorrect
    rapDir = parser.get('downscaling', 'RAP_finished_output_dir')
    rap0hrDir = parser.get('downscaling', 'RAP_finished_output_dir_0hr') # placeholder
    layerDir = parser.get('layering', 'analysis_assimilation_output')
    maxFcstHour = 3

    hoursBack = 5   # 3 hours back at 0, -1, and -2    (-2 -3 = -5)

    veryLateMinutes= int(parser.get('triggering', 'analysis_assim_very_late_minutes'))
    stateFile = parser.get('triggering', 'analysis_assim_layering_state_file')

    parms = Parms(hrrrDir, hrrr0hrDir, rapDir, rap0hrDir, mrmsDir, layerDir,
                  maxFcstHour, hoursBack, veryLateMinutes, stateFile)

    return parms

#----------------------------------------------------------------------------
class Parms:
    """ Parameters from the main wrf_hydro param file that are used for layering

    Attributes
    ----------
    _hrrrDir : str
       HRRR top input directory
    _hrrr0hrDir : str
       HRRR top input directory, 0 hour forecasts
    _rapDir : str
       RAP top input directory
    _rap0hrDir : str
       RAP top input directory, 0 hour forecasts
    _mrmsDir : str
       MRMS top input directory
    _layerDir : str
       output top directory
    _maxFcstHour : int
       maximum forecast hour for layered output
    _hoursBack : int
       Hours back to maintain state, issue time
    _veryLateSeconds
       Maximum number of sec. before declaring a forecast very late
    _stateFile : str
        Name of file with state information
    """
    #--------------------------------------------------------------------------
    def __init__(self, hrrrDir, hrrr0hrDir, rapDir, rap0hrDir, mrmsDir,
                 layerDir, maxFcstHour, hoursBack,
                 veryLateMinutes, stateFile) :
        """ Initialize from input args
        
        Parameters
        ----------
        Inputs are 1 to 1 with attributes
        """
        self._hrrrDir = hrrrDir
        self._hrrr0hrDir = hrrr0hrDir
        self._rapDir = rapDir
        self._rap0hrDir = rap0hrDir
        self._mrmsDir = mrmsDir
        self._layerDir = layerDir
        self._maxFcstHour = maxFcstHour
        self._hoursBack = hoursBack
        self._veryLateSeconds = veryLateMinutes*60
        self._stateFile = stateFile

    #--------------------------------------------------------------------------
    def debugPrint(self):
        """ logging debug of content
        """
        WhfLog.debug("Parms: HRRR_data = %s", self._hrrrDir)
        WhfLog.debug("Parms: HRRR_0_data = %s", self._hrrr0hrDir)
        WhfLog.debug("Parms: RAP_data = %s", self._rapDir)
        WhfLog.debug("Parms: RAP_0_data = %s", self._rap0hrDir)
        WhfLog.debug("Parms: MRMSdata = %s", self._mrmsDir)
        WhfLog.debug("Parms: Layer_data = %s", self._layerDir)
        WhfLog.debug("Parms: MaxFcstHour = %d", self._maxFcstHour)
        WhfLog.debug("Parms: HoursBack = %d", self._hoursBack)
        WhfLog.debug("Parms: veryLateSeconds = %d", self._veryLateSeconds)
        WhfLog.debug("Parms: StateFile = %s", self._stateFile)


#----------------------------------------------------------------------------
class ForecastStep:
    """ Internal state that is read in and saved out, individual time step relative to an issue time
    
    Assumes there is an issue time at a higher level

    Attributes
    ----------
    _empty : bool
       True if contents not set
    _step : int
       0, 1, or 2
<    _hrrr0 : bool
       True if HRRR input is available at issue - _step, hour 0
    _hrrr3 : bool
       True if HRRR input is available at issue - _step - 3, hour 3
    _rap0 : bool
       True if RAP input is available at issue - _step, hour 0
    _rap3 : bool
       True if RAP input is available at issue - _step - 3, hour 3
    _mrms : bool
       True if MRMS input is available at issue - _step
    _layered : bool
       True if this step has been layered (sent to Analysis/Assimilation)
    """
    #--------------------------------------------------------------------------
    def __init__(self, configString=""):
        """ Initialize by parsing a a config file  line

        Parameters
        ----------
        configString : str
           Config file line, or empty
        """

        # init to empty
        self._empty = True
        self._step = 0
        self._hrrr0 = False
        self._hrrr3 = False
        self._rap0 = False
        self._rap3 = False
        self._mrms = False
        self._layered = False
        if not configString:
            return

        # parse
        self._empty = False
        self._step = int(configString[0:1])
        self._hrrr0 = df.stringToBool(configString[2:3])
        self._hrrr3 = df.stringToBool(configString[4:5])
        self._rap0 = df.stringToBool(configString[6:7])
        self._rap3 = df.stringToBool(configString[8:9])
        self._mrms = df.stringToBool(configString[10:11])
        self._layered = df.stringToBool(configString[12:13])

    #--------------------------------------------------------------------------
    def debugPrint(self):
        """ logging debug of content
        """
        WhfLog.debug("FcstStep: empty=%d", self._empty)
        if (self._empty):
            return
        WhfLog.debug("FcstStep[%d] hrrr0:%d hrrr3:%d rap0:%d rap3:%d mrms:%d lay:%d",
                      self._step, df.boolToInt(self._hrrr0), df.boolToInt(self._hrrr3),
                      df.boolToInt(self._rap0), df.boolToInt(self._rap3),
                      df.boolToInt(self._mrms), df.boolToInt(self._layered))

    #--------------------------------------------------------------------------
    def debugPrintString(self):
        """ logging debug of content
        Returns
        -------
        str
        """
        if (self._empty):
            return ""
        ret = 's[%d] hr0[%d] hr3[%d] rp0[%d] rp3[%d] mrms[%d] lay[%d]'%(self._step,
                                                                        df.boolToInt(self._hrrr0),
                                                                        df.boolToInt(self._hrrr3),
                                                                        df.boolToInt(self._rap0),
                                                                        df.boolToInt(self._rap3),
                                                                        df.boolToInt(self._mrms),
                                                                        df.boolToInt(self._layered))
        return ret
    
    #--------------------------------------------------------------------------
    def initializeContent(self, step):
        """ Set content using inputs

        Parameters
        ----------
        step : int
           Step 0, 1, 2
        """
        self._empty = False
        self._step = step
        self._hrrr0 = False
        self._hrrr3 = False
        self._rap0 = False
        self._rap3 = False
        self._mrms = False
        self._layred = False
        
    #--------------------------------------------------------------------------
    def stepName(self):
        ret = stepStaticName(self._step)
        return ret

    #--------------------------------------------------------------------------
    def writeConfigString(self):
        """ Write local content as a one line string
        Returns
        -------
        str
        """
        if (self._empty):
            # write fake stuff out
            ret = "0 0 0 0 0 0 0"
        else:
            ret = '%01d %01d %01d %01d %01d %01d %01d' %(self._step,
                                                         df.boolToInt(self._hrrr0),
                                                         df.boolToInt(self._hrrr3),
                                                         df.boolToInt(self._rap0),
                                                         df.boolToInt(self._rap3),
                                                         df.boolToInt(self._mrms),
                                                         df.boolToInt(self._layered))
        return ret
    
    #--------------------------------------------------------------------------
    def layerIfReady(self, parms, config, itime):
        """  Perform layering if state is fully ready

        Parameters
        ----------
        parms : Parms
           Parameters
        itime : datetime
        Returns
        -------
        bool
           True if layering was done, or had previously been done
        """
        
        if (self._layered):
            return True
        self._setAvailability(parms, itime)
        if (self._hrrr0 and self._rap0 and
            self._hrrr3 and self._rap3 and self._mrms):
            self._layered = True
            WhfLog.setData('RAP/HRRR/MRMS')
            layer(parms, itime, self._step, "RAP_HRRR_MRMS", config)
            return True
        return False
    
    #--------------------------------------------------------------------------
    def forceLayer(self, parms, config, itime):
        """  Perform layering if state is partially ready enough

        Parameters
        ----------
        parms : Parms
           Parameters
        itime : datetime
        Returns
        -------
        bool
           True if layering was done, or had previously been done
        """
        
        if (self._layered):
            return True

        self._setAvailability(parms, itime)
        if (self._rap0 and self._rap3):
            if (self._hrrr0 and self._hrrr3):
                self._layered = True
                if (self._mrms == True):
                    WhfLog.setData('RAP/HRRR/MRMS')
                    layer(parms, itime, self._step, "RAP_HRRR_MRMS", config)
                else:
                    WhfLog.setData('RAP/HRRR')
                    layer(parms, itime, self._step, "RAP_HRRR", config)
                    WhfLog.setData('RAP/HRRR/MRMS')
            else:
                self._layered = True
                WhfLog.setData('RAP')
                layer(parms, itime, self._step, "RAP", config)
                WhfLog.setData('RAP/HRRR/MRMS')
        else:
            self._layered = True
            WhfLog.warning("WARNING, no layering of %s, step=-%d",
                            itime.strftime("%Y%m%d%h"), self._step)
        return True

    #--------------------------------------------------------------------------
    def _setAvailability(self, parms, issueTime):
        """ Change availability status when appropriate by looking at disk

        Parameters
        ----------
        parms : Parms
            parameters
        issueTime : datetime
            time of this assimilation

        Returns
        -------
        none
        """

        if (self._layered):
            return
        
        time0 = issueTime - datetime.timedelta(hours=self._step)
        time3 = issueTime - datetime.timedelta(hours=(self._step + 3))

        if (not self._hrrr0):
            self._hrrr0 = forecastExists(parms._hrrr0hrDir, time0, 0)
        if (not self._hrrr3):
            self._hrrr3 = forecastExists(parms._hrrrDir, time3, 3)
        if (not self._rap0):
            self._rap0 = forecastExists(parms._rap0hrDir, time0, 0)
        if (not self._rap3):
            self._rap3 = forecastExists(parms._rapDir, time3, 3)
        if (not self._mrms):
            self._mrms = obsExists(parms._mrmsDir, time0)


    
#----------------------------------------------------------------------------
class State:
    """ Internal state that is read in and saved out

    Attributes

    _empty : bool
       true if contents not set
    _issue : datetime
       Issue time (y, m, d, h, 0, 0)
    _step : list[ForecastStep]
       The 3 steps 0, 1, 2 hours back
    _layered : bool
       true if this forecast has been layered
    _clockTime : datetime
       time at which the first forecast input was available
    """
    #--------------------------------------------------------------------------
    def __init__(self):
        """ Initialize

        Parameters
        ----------
        """

        # init to empty
        self._empty = True
        self._first = True
        self._issue = datetime.datetime
        self._step = []
        self._layered = False
        self._clockTime = datetime.datetime

    #--------------------------------------------------------------------------
    def initFromStateFile(self, confFile):

        # parse
        cf = SafeConfigParser()
        cf.read(confFile)
        self._step = []
        self._first = True
        self._empty = True
        status = df.stringToBool(cf.get('status', 'first'))
        if (status):
            return
        self._empty = False
        self._first = df.stringToBool(cf.get('forecast', 'first'))
        stime = cf.get('forecast', 'issue_time')
        self._issue = datetime.datetime.strptime(stime, "%Y%m%d%H")

        self._layered = df.stringToBool(cf.get('forecast', 'layered', self._layered))
        fs0 = ForecastStep(cf.get('forecast', stepStaticName(0)))
        fs1 = ForecastStep(cf.get('forecast', stepStaticName(1)))
        fs2 = ForecastStep(cf.get('forecast', stepStaticName(2)))
        self._step.append(fs0)
        self._step.append(fs1)
        self._step.append(fs2)
        stime = cf.get('forecast', 'clock_time')
        self._clockTime = datetime.datetime.strptime(stime, '%Y-%m-%d_%H:%M:%S')
        
    #--------------------------------------------------------------------------
    def debugPrint(self):
        """ logging debug of content
        """
        WhfLog.debug("Fcst: empty=%d first=%d", df.boolToInt(self._empty), df.boolToInt(self._first))
        if (self._empty):
            return
        WhfLog.debug("Fcst: I:%s step[0]:%s step[1]:%s step[2]:%s layered:%d clockTime=%s",
                      self._issue.strftime("%Y%m%d%H"),
                      self._step[0].debugPrintString(),
                      self._step[1].debugPrintString(),
                      self._step[2].debugPrintString(),
                      df.boolToInt(self._layered),
                      self._clockTime.strftime("%Y-%m-%d_%H:%M:%S"))

    #--------------------------------------------------------------------------
    def initialize(self, parms, newest):
        """  Initialize state using inputs. Called when issue time changes.

        Parameters
        ----------
        parms : Parms
           Parameteres
        newest : str
           yyyymmddhh string for the new issue time
        """

        # convert to datetime
        itime = datetime.datetime.strptime(newest, '%Y%m%d%H')

        self._empty = False
        self._step = []
        self._first = True
        self._setContent(itime)
        
    #--------------------------------------------------------------------------
    def write(self, parmFile):
        """ Write contents to a state file

        Parameters
        ----------
        parmFile : str
           Name of file to write to 
        """

        config = SafeConfigParser()

        config.add_section('status')
        config.set('status', 'first', str(int(self._empty)))

        # When adding sections or items, add them in the reverse order of
        # how you want them to be displayed in the actual file.
        # In addition, please note that using RawConfigParser's and the raw
        # mode of ConfigParser's respective set functions, you can assign
        # non-string values to keys internally, but will receive an error
        # when attempting to write to a file or when you get it in non-raw
        # mode. SafeConfigParser does not allow such assignments to take place.
        config.add_section('forecast')

        
        config.set('forecast', 'first', str(df.boolToInt(self._first)))
        config.set('forecast', 'issue_time', self._issue.strftime("%Y%m%d%H"))
        config.set('forecast', 'layered', str(df.boolToInt(self._layered)))
        for f in self._step:
            s = f.writeConfigString()
            stepName = f.stepName()
            config.set('forecast', stepName, s)
        config.set('forecast', 'clock_time',
                   self._clockTime.strftime("%Y-%m-%d_%H:%M:%S"))
        
        # Write it out
        with open(parmFile, 'wb') as configfile:
            config.write(configfile)

    #--------------------------------------------------------------------------
    def isNewModelIssueTime(self, issueTime):
        """ Check if input is a new model issue time or not

        Parameters
        ----------
        issueTime: str
            yyyymmddhh string
        Returns
        -------
        bool
            true if the input issue time is not in the state
        
        """
        if (self._empty):
            return True
        else:
            itime = datetime.datetime.strptime(issueTime, '%Y%m%d%H')
            return (itime > self._issue)
    
    #--------------------------------------------------------------------------
    def setCurrentModelAvailability(self, parms, config):
        """ Change availability status when appropriate by looking at disk

        Parameters
        ----------
        parms : Parms
            parameters
        config : str
            Config file name

        Returns
        -------
        none
        """

        if (self._layered):
            # no need to do more, already layered
            return
        if (self._empty):
            WhfLog.error("Empty when not expected")
            return
        
        # make note if going from nothing to something
        nothing = True
        for f in self._step:
            if (f._layered):
                nothing = False


        #if (nothing):
            #WhfLog.debug("Nothing, so trying to get stuff")

        # first time only, try the -1 and -2 steps, force with what we have
        if (self._first):
            self._step[2].forceLayer(parms, config, self._issue)
            self._step[1].forceLayer(parms, config, self._issue)
            self._first = False
            
        self._step[0].layerIfReady(parms, config, self._issue)
        self._layered = self._step[0]._layered
        if (not self._layered):
            tnow = datetime.datetime.utcnow()
            diff = tnow - self._clockTime
            idiff = (diff.microseconds +
                     (diff.seconds + diff.days*24*3600)*10**6)/10**6
            if (idiff > parms._veryLateSeconds):
                WhfLog.warning("WARNING: Inputs for layering timeout Issue:%s",
                                self._issue.strftime("%Y%m%d%H"))
                s = self._step[0].debugPrintString()
                WhfLog.warning("WARNING: 0, state=%s", s)
                self._step[0].forceLayer(parms, config, self._issue)
                self._layered = True

    #--------------------------------------------------------------------------
    def _setContent(self, issueTime):
        """ Set content using inputs

        Parameters
        ----------
        issueTime : datetime
            Model run time
        lt : int
            Forecast time seconds
        """
        self._empty = False
        self._issue = issueTime
        self._step = []
        self._first = True
        fs0 = ForecastStep()
        fs0.initializeContent(0)
        self._step.append(fs0)
        fs1 = ForecastStep()
        fs1.initializeContent(1)
        self._step.append(fs1)
        fs2 = ForecastStep()
        fs2.initializeContent(2)
        self._step.append(fs2)
        self._layered = False
        self._clockTime = datetime.datetime.utcnow()
        #self.debugPrint()
        
                
#----------------------------------------------------------------------------
def run(configFile, realtime):
    # User must pass the config file into the main driver.
    if not os.path.exists(configFile):
        print 'ERROR forcing engine config file not found.'
        return 1

    # read in fixed main params
    parms = parmRead(configFile, realtime)

    newestT = ""
    newestT1 = df.newestIssueTime(parms._hrrrDir)
    if (newestT):
        if (newestT1):
            if (newestT1 > newestT):
                newestT = newestT1
    else:
        newestT = newestT1
        
    newestT1 = df.newestIssueTime(parms._rapDir)
    if (newestT):
        if (newestT1):
            if (newestT1 > newestT):
                newestT = newestT1
    else:
        newestT = newestT1
    newestT1 = df.newestIssueTime(parms._hrrr0hrDir)
    if (newestT):
        if (newestT1):
            if (newestT1 > newestT):
                newestT = newestT1
    else:
        newestT = newestT1
        
    newestT1 = df.newestIssueTime(parms._rap0hrDir)
    if (newestT):
        if (newestT1):
            if (newestT1 > newestT):
                newestT = newestT1
    else:
        newestT = newestT1
        
    newestT1 = df.newestIssueTime(parms._mrmsDir)
    if (newestT):
        if (newestT1):
            if (newestT1 > newestT):
                newestT = newestT1
    else:
        newestT = newestT1
        

    if (not newestT):
        WhfLog.debug("No data")
        return 0

    
    # if there is not a state file, create one now using newest
    if (not os.path.exists(parms._stateFile)):
        state = State()
        WhfLog.info("Initializing")
        state.initialize(parms, newestT)
        state.write(parms._stateFile)

    # Normal processing situation
    #WhfLog.debug("Look for Layering....")
    
    # read in state
    state2 = State()
    state2.initFromStateFile(parms._stateFile)
    #state2.debugPrint()

        # check for new issue time
    if (state2.isNewModelIssueTime(newestT)):
        WhfLog.info("Re-Initializing state, new model issue time %s", newestT)
        state2.initialize(parms, newestT)

    # update availability
    state2.setCurrentModelAvailability(parms, configFile)

    # write out final state
    state2.write(parms._stateFile)
    return 0

#----------------------------------------------------------------------------
def main(argv):
    return run(argv[0], True)

#----------------------------------------------
if __name__ == "__main__":
    main(sys.argv[1:])
