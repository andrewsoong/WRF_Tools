; linearly interpolates the forcing files (replaces) to a specified time interval
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRF_contributed.ncl"

begin

print("+"+"Beginning time_interpolate_forcing.ncl")

forceIntervalss = stringtodouble(getenv("FORCING_INTERVAL"))
if ( ismissing(forceIntervalss) ) then
  print("Set environment variable FORCING_INTERVAL")
  exit
end if
print("Will interpolate to interval "+forceIntervalss)

inFNam = getenv("FORCE_FILE_NAME")
if ( ismissing(inFNam) ) then
  print("Set environment variable FORCE_FILE_NAME")
  exit
end if
print("Will interpolate and replace file "+inFNam)

outFNam = "forcing_temp.nc"

inF = addfile(inFNam,"r")
ierr = systemfunc("/bin/rm -f "+outFNam)
outF = addfile(outFNam,"c")

; copy global atts
copy_VarAtts(inF,outF)

; get times
inTimeStrings = inF->Times
dims = dimsizes(inTimeStrings)
nT = dims(0)
timeStrLen = dims(1)

inTimesHH = wrf_times_c(inTimeStrings,1)
nT = dimsizes(inTimesHH)

; need to add one more for interp purposes
nT = nT+1
inTimesHHFull = new(nT,"double")
inTimesHHFull(0:nT-2) = inTimesHH
dtIn = inTimesHH(nT-2) - inTimesHH(nT-3) 
inTimesHHFull(nT-1) = inTimesHH(nT-2) + dtIn

; figure out full time list
forceIntervalHH = forceIntervalss / 3600
if ( dtIn .eq. forceIntervalHH ) then
  print("No need to interpolate, data already at interval "+forceIntervalss)
  exit
end if  

nTOutFull = doubletoint((inTimesHHFull(nT-1) - inTimesHHFull(0)) / forceIntervalHH + 1)
outTimesHHFull = fspan(inTimesHHFull(0),inTimesHHFull(nT-1),nTOutFull)
nTOut = nTOutFull - 1;
outTimesHH = outTimesHHFull(0:nTOut-1)

copy_VarAtts(inTimesHH,outTimesHHFull)

; make time strings to set the time dimension
outDate = floattointeger(ut_calendar(outTimesHHFull(0:nTOut-1),0))

outYY = outDate(:,0)
outMM = outDate(:,1)
outDD = outDate(:,2)
outHH = outDate(:,3)
outmm = outDate(:,4)
outss = outDate(:,5)

outYYstr = ""+outYY
outMMstr = ""+outMM
outMMstr = where(outMM .lt. 10,"0"+outMMstr,outMMstr)
outDDstr = ""+outDD
outDDstr = where(outDD .lt. 10,"0"+outDDstr,outDDstr)
outHHstr = ""+outHH
outHHstr = where(outHH .lt. 10,"0"+outHHstr,outHHstr)
outmmstr = ""+outmm
outmmstr = where(outmm .lt. 10,"0"+outmmstr,outmmstr)
outssstr = ""+outss
outssstr = where(outss .lt. 10,"0"+outssstr,outssstr)

outTimeStrings = stringtochar(outYY+"-"+outMMstr+"-"+outDDstr+"_"+outHHstr+":"+outmmstr+":"+outssstr); 
tmpOTS = outTimeStrings(:,0:18)
delete(outTimeStrings)
outTimeStrings = tmpOTS
delete(tmpOTS)

copy_VarMeta(inTimeStrings,outTimeStrings)

outF->Times = outTimeStrings

; now loop thru variables and interpolate
; everything except Times is the same dimension

varListTemp = getfilevarnames(inF)
keepInds = ind(varListTemp .ne. "Times")
varList = varListTemp(keepInds)
delete(varListTemp)
nVars = dimsizes(varList)

do iV = 0, nVars - 1

  xIn = inF->$varList(iV)$
  dims = dimsizes(xIn)
  nT = dims(0)
  nZ = dims(1)

  xOut = new((/nTOut,nZ/),typeof(xIn))
  copy_VarMeta(xIn,xOut)
 
  charName = stringtochar(varList(iV))
  nC = dimsizes(charName) - 1

;--------------------------------------
; two main branches - tendency or not?
;--------------------------------------

  if ( nC .gt. 5 .and. charName(nC-5:nC-1) .eq. "_TEND" ) then

    print(varList(iV)+" is a tendency, just filling in")

    ; find all times that I need to fill, and just fill them 
    do iT = 0, nT - 1
      myOutTimes = ind(outTimesHH .ge. inTimesHHFull(iT) .and. outTimesHH .lt. inTimesHHFull(iT+1) ) 
      xOut(myOutTimes,:) = conform(xOut(myOutTimes,:),xIn(iT,:),1)
    end do

  else ; not a tendency ------------------------------------

    print(varList(iV)+" is not a tendency, need to interpolate")

    ; need the tendency to fill though
    tendVarName = varList(iV)+"_TEND" 
    tendF = inF->$tendVarName$

    ; find all times that I need to fill, and just fill them 
    do iT = 0, nT - 1
      myOutTimes = ind(outTimesHH .ge. inTimesHHFull(iT) .and. outTimesHH .lt. inTimesHHFull(iT+1) ) 
      nFillTimes = dimsizes(myOutTimes)

      ; find time between outTimesHH and inTimesHHFull
      dtHH = (outTimesHH(myOutTimes) - inTimesHHFull(iT)) * 3600

      ; use tendency to fill
      xOut(myOutTimes,:) = conform(xOut(myOutTimes,:),xIn(iT,:),1) + conform(xOut(myOutTimes,:),tendF(iT,:),1)*doubletofloat(conform(xOut(myOutTimes,:),dtHH,0))

      delete(dtHH)
    end do

    delete(tendF)
    delete(tendVarName)

  end if

  outF->$varList(iV)$ = xOut

  delete(charName)
  delete(xOut)

end do

print("SUCCESS in filling times in file "+inFNam)

end

