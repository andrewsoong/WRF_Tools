; builds a forcing file for the SCM from met_em* input.
; 1.  Stuffs in data
; 2.  Modifies global attributes as appropriate
; 3.  Writes in initial profile for soil and atmosphere 
; 4.  Writes a suggested scm namelist
;
; NOTES: 
; 1.  Required environment variables:
;     - the ensemble-center date/time in "SCM_CENTER" following the WRF
;       file naming convention, e.g. setenv SCM_CENTER 2000-06-10_00:00:00
;     - output file name in FORCE_FILE_NAME
;     - path of directory containing met_em* or other input files in METPATH
;     - length of the simulation (seconds) in SIMLENGTH
;     - random seeds in RANDSEEDa and RANDSEEDb, for reproducability 
; 2.  If the ensemble member is specified as 0,
; no perturbation will occur - you will get a single file for the center date
; 3.  Because it's a pain to put environment variables on the NCL command line
; (even possible?), this uses getenv instead.
; 4.  Use a random seed if you want repeatable results
; 5.  Make sure that the number of levels in the forcing file is equal to the
; input data.  Note that metgrid files put the surface diagnostics in the
; first layer.  We don't want to include those.
; 6.  For now we assume that a 3x3 grid is already set up, and we just take the center grid point.  The input stencil should be:
;      v   v
;    u M u M u
;      v X v   <--- forcing is valid at the X
;    u M u M u
;      v   v
; 7.  Built on NARR data, which has the sfc values in the first level. These
; are stripped out for the forcing but not for input_sounding.  Is this
; general to all or at least most met_em* files?
; 8.  Right now this does not do any extrapolation, which will be a problem
; in the case that the lowest pressure-level data (e.g. 1000 mb) higher than
; the lowest WRF level. **
; 9.  Rotates the winds from the input grid to zonal and meridional.
; 10. No consideration of the map scale factors at this point.  Make sure
; that your input met_em* are centered on the SCM location and that you are
; not introducing much grid stretching with the projection.  **
;
; ** to be handled in future versions.
;

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "./build_forcing_functions.ncl"
load "./rotwind.ncl"

begin

; any fixed parameters?
maxEnsembleSize = 1000

;--------------------------------------------------------
; END user modifications
;--------------------------------------------------------

; check for required environment variables

fName = getenv("FORCE_FILE_NAME")
if ( ismissing(fName) ) then
  print("Set environment variable FORCE_FILE_NAME")
  exit
end if
print("Filling forcing file "+fName)

metPath = getenv("METPATH")
if ( ismissing(metPath) ) then
  print("Set environment variable METPATH")
  exit
end if
print("With input from directory "+metPath)

ensMem = stringtointeger(getenv("ENSEMBLE_MEMBER"))
perturb = True
if ( ismissing(ensMem) .or. ensMem .lt. 1 ) then
  print("No perturbation")
  perturb = False
end if

dateStr = getenv("CENTER_DATE")
if ( ismissing(dateStr) ) then
  print("Set environment variable CENTER_DATE")
  exit
  ; NOTE: could use this one to default to a random center
end if

simLen = stringtodouble(getenv("SIMLENGTH"))
if ( ismissing(simLen) ) then
  print("Set environment variable SIMLENGTH")
  exit
end if

xll = stringtointeger(getenv("XLL"))
if ( ismissing(xll) ) then
  print("Set environment variable XLL")
  exit
end if

yll = stringtointeger(getenv("YLL"))
if ( ismissing(yll) ) then
  print("Set environment variable YLL")
  exit
end if

rSeed1 = stringtointeger(getenv("RANDSEEDa"))
rSeed2 = stringtointeger(getenv("RANDSEEDb"))

if ( .not. ismissing(rSeed1) .and. .not. ismissing(rSeed2) ) then
  random_setallseed(rSeed1,rSeed2)
else
  print("Using default NCL random seed")
end if

; open the forcing file
forceFile = addfile(fName,"rw")

; get date string length
timeDims = getfilevardimsizes(forceFile,"Times")
dateStrLen = timeDims(1)

; get times for all files in directory
fList = systemfunc("ls "+metPath+"/met_em.d01*")
nFiles = dimsizes(fList)
fileDates = new((/nFiles,dateStrLen/),"character")
do iFile = 0, nFiles - 1
  inF = addfile(fList(iFile),"r")
  fTime = inF->Times(0,:)
  fileDates(iFile,:) = fTime
  delete(fTime)
  delete(inF)
end do 

; convert to integers
fileYrList = stringtointeger(chartostring(fileDates(:,0:3)))
fileMoList = stringtointeger(chartostring(fileDates(:,5:6)))
fileDyList = stringtointeger(chartostring(fileDates(:,8:9)))
fileHrList = stringtointeger(chartostring(fileDates(:,11:12)))
fileMmList = stringtointeger(chartostring(fileDates(:,14:15)))
fileSsList = stringtointeger(chartostring(fileDates(:,17:18)))
fileJul = greg2jul(fileYrList,fileMoList,fileDyList,fileHrList)

; find start file for center
dateChar = stringtochar(dateStr)
centerYrStart = stringtointeger(chartostring(dateChar(0:3)))
centerMoStart = stringtointeger(chartostring(dateChar(5:6)))
centerDyStart = stringtointeger(chartostring(dateChar(8:9)))
centerHrStart = stringtointeger(chartostring(dateChar(11:12)))
centerMmStart = stringtointeger(chartostring(dateChar(14:15)))
centerSsStart = stringtointeger(chartostring(dateChar(17:18)))

startJul = greg2jul(centerYrStart,centerMoStart,centerDyStart,centerHrStart)
startJul = startJul + centerMmStart/1440 + centerSsStart/86400

; find all files within range
; NOTE: need last time to compute tendency only - is not written out
endJul = startJul + simLen/86400
centerFileInds = ind(fileJul .ge. startJul .and. fileJul .le. endJul)
centerFiles = fList(centerFileInds)
centerJul   = fileJul(centerFileInds)
nCenterFiles  = dimsizes(centerFileInds)

; make sure beginning and ending are in the list
if ( startJul .ne. centerJul(0) ) then
  print("Could not find a file to start simulation at "+dateStr)
  exit
end if
if ( endJul .ne. centerJul(nCenterFiles-1) ) then
  print("Could not find a file to end simulation of "+simLen+" s")
  exit
end if

; build the perturbation file list based on time of day of start time
if ( perturb ) then
  print("Building a perturbation file list")

  ; first find files valid starts at the same time of day
  startCandidateInds = ind(mod(fileJul-startJul,1) .eq. 0)
  nCandidates = dimsizes(startCandidateInds)

  ; remove the center one so that we don't unintentionally get no perturbation
  keepInds = ind(startCandidateInds .ne. centerFileInds(0))
  tmpCandidateInds = startCandidateInds(keepInds)
  delete(startCandidateInds)
  startCandidateInds = tmpCandidateInds
  delete(tmpCandidateInds)
  nCandidates = nCandidates - 1

  if ( all(ismissing(startCandidateInds)) ) then
    print("Could not find additional corresponding start times to perturb")
    exit
  end if

  ; to choose the perturbation, first make a reproducable list of random numbers
  ; the only viable options are 1...number of candidates
  randList = new((/maxEnsembleSize/),"integer")
  srand(rSeed1)
  do iRand = 0, maxEnsembleSize - 1
    randList(iRand) = floattointeger(floor((nCandidates-1)*rand()/32766.0))
  end do

  ; just pick off mine
  pertStartCandidateInd = randList(ensMem-1)
  pertStartInd = startCandidateInds(pertStartCandidateInd)
  pertStartJul = fileJul(pertStartInd)

  ; build list of perturbation time series
  pertEndJul = pertStartJul + simLen/86400
  pertFileInds = ind(fileJul .ge. pertStartJul .and. fileJul .le. pertEndJul)
  pertFiles = fList(pertFileInds)
  pertJul   = fileJul(pertFileInds)
  nPertFiles  = dimsizes(pertFileInds)

  ; sanity check
  if ( nPertFiles .ne. nCenterFiles ) then
    print("Mismatch between center and perturbation time series")
    exit
  end if

  ; choose perturbation weight (normal->logit to give Gaussian-like but bounded on [0,1]
  pertWgtList = random_normal(0.0,1.0,maxEnsembleSize)
  pertWgtList = exp(pertWgtList)/(1+exp(pertWgtList))
  pertWgt = abs(pertWgtList(ensMem-1)-0.5)

else

  pertFileInds = new((/nCenterFiles/),"integer"); should be all missing

end if

; first modify some global attributes
inF = addfile(centerFiles(0),"r") 
forceFile@START_DATE = dateStr
forceFile@SIMULATION_START_DATE = dateStr
forceFile@DX = inF@DX
forceFile@DY = inF@DY
dx = inF@DX;
map_proj = inF@MAP_PROJ
std_lon = inF@STAND_LON
true_lat1 = inF@TRUELAT1
true_lat2 = inF@TRUELAT2

; note perturbed in file
if ( perturb ) then
  forceFile@PERTURBED = "TRUE"
else
  forceFile@PERTURBED = "FALSE"
end if

; rotate winds?
rotate = False
if ( map_proj .lt. 4 ) then
  rotate = True
end if

; change dimension size in forcing file

timeDims = getfilevardimsizes(forceFile,"Times")

; Times can just be dumped.  This also sets the dimension correctly
forceFile->Times(0:nCenterFiles-2,:) = (/fileDates(centerFileInds(0:nCenterFiles-2),:)/) 

; need dimensions
nForceTimes = nCenterFiles-1
vdims = getfilevardimsizes(forceFile,"Z_FORCE")
nForceLevels = vdims(1)

; need dt in input for tendencies
nt = nCenterFiles
dt = doubletofloat((centerJul(1:nt-1)-centerJul(0:nt-2))*86400)

if ( nForceTimes .ne. vdims(0) ) then
  print("Mismatch in number of times, stopping")
  exit
end if

; also do height up front so we know where to interpolate W
z_force = new((/nForceTimes+1,nForceLevels/),"float")
z_force  = forcing_z(centerFiles,z_force,xll,yll)

zCenterInit = z_force(0,:)
if ( perturb ) then
  z_force_perturb = z_force
  z_force_perturb = forcing_z(pertFiles,z_force_perturb,xll,yll)
  z_force = pertWgt*z_force + (1.0-pertWgt)*z_force_perturb
  zPertInit = z_force_perturb(0,:)
end if

z_force_tend = new((/nForceTimes,nForceLevels/),"float")
z_force_tend = (z_force(1:nt-1,:) - \\
            z_force(0:nt-2,:))/conform(z_force(0:nt-2,:),dt,0)

forceFile->Z_FORCE = z_force(0:nForceTimes-1,:)
forceFile->Z_FORCE_TEND = (/z_force_tend/)
delete(z_force)
delete(z_force_tend)
 
; need f_c for geostrophic winds
fCorTmp = inF->F(0,:,:)
fCor = 0.25*(fCorTmp(yll,xll) + fCorTmp(yll+1,xll) + fCorTmp(yll,xll+1) + fCorTmp(yll+1,xll+1))
delete(fCorTmp)

; need lat/long for rotating winds and to write namelist
latTmp = inF->XLAT_M(0,:,:)
lat = 0.25*(latTmp(yll,xll) + latTmp(yll+1,xll) + latTmp(yll,xll+1) + latTmp(yll+1,xll+1))
delete(latTmp)
forceFile@CEN_LAT = lat

lonTmp = inF->XLONG_M(0,:,:)
lon = 0.25*(lonTmp(yll,xll) + lonTmp(yll+1,xll) + lonTmp(yll,xll+1) + lonTmp(yll+1,xll+1))
delete(lonTmp)
forceFile@CEN_LON = lon

;----------------------------------------------------
; U_G, V_G, and associated tendencies
;----------------------------------------------------
u_g = new((/nForceTimes+1,nForceLevels/),"float")
v_g = u_g

u_g = forcing_u_g(centerFiles,u_g,fCor,dx,xll,yll)
v_g = forcing_v_g(centerFiles,v_g,fCor,dx,xll,yll)

if ( rotate ) then 
   utmp = gridwind_to_truewind("U",u_g,v_g,lat,lon,map_proj,std_lon,true_lat1,true_lat2)
   vtmp = gridwind_to_truewind("V",u_g,v_g,lat,lon,map_proj,std_lon,true_lat1,true_lat2)
   u_g = (/utmp/)
   v_g = (/vtmp/)
   delete(utmp)
   delete(vtmp)
end if

if ( perturb ) then
  
  u_g_perturb = u_g
  v_g_perturb = v_g
  u_g_perturb = forcing_u_g(pertFiles,u_g_perturb,fCor,dx,xll,yll)
  v_g_perturb = forcing_v_g(pertFiles,v_g_perturb,fCor,dx,xll,yll)

  if ( rotate ) then 
     utmp = gridwind_to_truewind("U",u_g_perturb,v_g_perturb,lat,lon,map_proj,std_lon,true_lat1,true_lat2)
     vtmp = gridwind_to_truewind("V",u_g_perturb,v_g_perturb,lat,lon,map_proj,std_lon,true_lat1,true_lat2)
     u_g_perturb = (/utmp/)
     v_g_perturb = (/vtmp/)
     delete(utmp)
     delete(vtmp)
  end if

  u_g = pertWgt*u_g + (1.0-pertWgt)*u_g_perturb
  v_g = pertWgt*v_g + (1.0-pertWgt)*v_g_perturb

end if ; perturb?

forceFile->U_G = u_g(0:nForceTimes-1,:)
forceFile->V_G = v_g(0:nForceTimes-1,:)

nt = nCenterFiles

u_g_tend = new((/nForceTimes,nForceLevels/),"float")
v_g_tend = new((/nForceTimes,nForceLevels/),"float")
    
u_g_tend = (u_g(1:nt-1,:) - \\
            u_g(0:nt-2,:))/conform(u_g(0:nt-2,:),dt,0)
v_g_tend = (v_g(1:nt-1,:) - \\
            v_g(0:nt-2,:))/conform(v_g(0:nt-2,:),dt,0)
   
; write to file
forceFile->U_G_TEND = (/u_g_tend/)
forceFile->V_G_TEND = (/v_g_tend/)

;----------------------------------------------------
; W_SUBS and associated tendency
;----------------------------------------------------

w_subs = new((/nForceTimes+1,nForceLevels/),"float")
w_subs  = forcing_w(centerFiles,w_subs,xll,yll)

if ( perturb ) then
  w_subs_perturb = w_subs
  w_subs_perturb = forcing_w(pertFiles,w_subs_perturb,xll,yll)
  w_subs = pertWgt*w_subs + (1.0-pertWgt)*w_subs_perturb
end if

forceFile->W_SUBS = w_subs(0:nForceTimes-1,:)

w_subs_tend = new((/nForceTimes,nForceLevels/),"float")
w_subs_tend = (w_subs(1:nt-1,:) - w_subs(0:nt-2,:)) / \\
               conform(w_subs(0:nt-2,:),dt,0)
forceFile->W_SUBS_TEND = w_subs_tend

delete(w_subs)
delete(w_subs_tend)

;----------------------------------------------------
; All advection/relaxation terms and tendencies
;----------------------------------------------------

; Need to average winds to the same line as the SCM to get the advection
Ua = avg_uv(centerFiles,"U",yll) ; avg U in y direction
Va = avg_uv(centerFiles,"V",xll) ; avg V in x direction

if ( perturb )
  Ua_perturb = avg_uv(pertFiles,"U",yll)
  Va_perturb = avg_uv(pertFiles,"V",xll)
end if

; Advective time scales come directly from these
tau_x = 0.5*dx/abs(Ua(:,:,xll+1))
tau_y = 0.5*dx/abs(Va(:,:,yll+1))

if ( perturb ) then
  tau_x_perturb = 0.5*dx/abs(Ua_perturb(:,:,xll+1))
  tau_y_perturb = 0.5*dx/abs(Va_perturb(:,:,yll+1))
end if

; Find what is upstream (0 is W,S and 1 is E,N)
upstream_x_inds = find_upstream_inds(Ua,xll+1)
upstream_y_inds = find_upstream_inds(Va,yll+1)

if ( perturb ) then
  upstream_x_inds_perturb = find_upstream_inds(Ua_perturb,xll+1)
  upstream_y_inds_perturb = find_upstream_inds(Va_perturb,yll+1)
end if

; Need to average advected scalars to the same line as the SCM
THaV = avg_mass(centerFiles,"TT","X",xll); Avg T in x-dir for V adv
THaU = avg_mass(centerFiles,"TT","Y",yll); Avg T in y-dir for U adv

QVaV = avg_mass(centerFiles,"RH","X",xll); Avg Qv in x-dir for V adv
QVaU = avg_mass(centerFiles,"RH","Y",yll); Avg Qv in y-dir for U adv

if ( perturb ) then
  THaV_perturb = avg_mass(pertFiles,"TT","X",xll); Avg T in x-dir for V adv
  THaU_perturb = avg_mass(pertFiles,"TT","Y",yll); Avg T in y-dir for U adv
  QVaV_perturb = avg_mass(pertFiles,"RH","X",xll); Avg Qv in x-dir for V adv
  QVaU_perturb = avg_mass(pertFiles,"RH","Y",yll); Avg Qv in y-dir for U adv
end if

; Winds are a little more complicated.  To follow the convention adopted
; for TH and QV, we need both components located adjacent to the grid
; center 1/2 grid point away.  That is:
;     U,V
; U,V  X  U,V   <---- X marks SCM location
;     U,V
;
; U to N and S direct from file (V advection U); c.f. stencil at top
; V to E and W direct from file (U advection V); c.f. stencil at top
; U to E and W must be destaggered from Ua (U advection U)
; V to N and S must be destaggered from Va (V advection V)
;
; NOTE: advection does NOT need to be rotated because it is just a tendency.
; Make sure the wind velocities are correct and do not need rescaling.

; first destagger Ua and Va
UaU = destagger_dim(Ua)
VaV = destagger_dim(Va)

if ( perturb ) then
  UaU_perturb = destagger_dim(Ua_perturb)
  VaV_perturb = destagger_dim(Va_perturb)
end if

; grab correct surrounding values for the other direction
UaV = get_neighbors(centerFiles,"U",xll+1)
VaU = get_neighbors(centerFiles,"V",yll+1)

if ( perturb ) then
  UaV_perturb = get_neighbors(pertFiles,"U",xll+1)
  VaU_perturb = get_neighbors(pertFiles,"V",yll+1)
end if

;
; everything should have the same dimensions now with last dim length of 2
;

; Just pull the upstream values
dims = dimsizes(THaV)
nt = dims(0)
nl = dims(1)
delete(dims)

th_ups_x = new((/nt,nl/),"float")
th_ups_y = new((/nt,nl/),"float")
qv_ups_x = new((/nt,nl/),"float")
qv_ups_y = new((/nt,nl/),"float")

if ( perturb ) then

  th_ups_x_perturb = th_ups_x
  th_ups_y_perturb = th_ups_y
  qv_ups_x_perturb = qv_ups_x
  qv_ups_y_perturb = qv_ups_y

end if

u_ups_x = new((/nt,nl/),"float")
u_ups_y = new((/nt,nl/),"float")
v_ups_x = new((/nt,nl/),"float")
v_ups_y = new((/nt,nl/),"float")

if ( perturb ) then

  u_ups_x_perturb = u_ups_x
  u_ups_y_perturb = u_ups_y
  v_ups_x_perturb = v_ups_x
  v_ups_y_perturb = v_ups_y

end if

do itime = 0, nt-1
  do ilevel = 0, nl-1 

    th_ups_x(itime,ilevel) = THaU(itime,ilevel,upstream_x_inds(itime,ilevel))
    th_ups_y(itime,ilevel) = THaV(itime,ilevel,upstream_y_inds(itime,ilevel))
    qv_ups_x(itime,ilevel) = QVaU(itime,ilevel,upstream_x_inds(itime,ilevel))
    qv_ups_y(itime,ilevel) = QVaV(itime,ilevel,upstream_y_inds(itime,ilevel))
    u_ups_x(itime,ilevel) = UaU(itime,ilevel,upstream_x_inds(itime,ilevel))
    u_ups_y(itime,ilevel) = UaV(itime,ilevel,upstream_y_inds(itime,ilevel))
    v_ups_x(itime,ilevel) = VaU(itime,ilevel,upstream_x_inds(itime,ilevel))
    v_ups_y(itime,ilevel) = VaV(itime,ilevel,upstream_y_inds(itime,ilevel))

    if ( perturb ) then

      th_ups_x_perturb(itime,ilevel) = \\
               THaU_perturb(itime,ilevel,upstream_x_inds_perturb(itime,ilevel))
      th_ups_y_perturb(itime,ilevel) = \\
               THaV_perturb(itime,ilevel,upstream_y_inds_perturb(itime,ilevel))
      qv_ups_x_perturb(itime,ilevel) = \\
               QVaU_perturb(itime,ilevel,upstream_x_inds_perturb(itime,ilevel))
      qv_ups_y_perturb(itime,ilevel) = \\
               QVaV_perturb(itime,ilevel,upstream_y_inds_perturb(itime,ilevel))
      u_ups_x_perturb(itime,ilevel) = \\
               UaU_perturb(itime,ilevel,upstream_x_inds_perturb(itime,ilevel))
      u_ups_y_perturb(itime,ilevel) = \\
               UaV_perturb(itime,ilevel,upstream_y_inds_perturb(itime,ilevel))
      v_ups_x_perturb(itime,ilevel) = \\
               VaU_perturb(itime,ilevel,upstream_x_inds_perturb(itime,ilevel))
      v_ups_y_perturb(itime,ilevel) = \\
               VaV_perturb(itime,ilevel,upstream_y_inds_perturb(itime,ilevel))

    end if ; perturb?

  end do
end do

if ( perturb ) then

  th_ups_x = pertWgt*th_ups_x + (1.0-pertWgt)*th_ups_x_perturb
  th_ups_y = pertWgt*th_ups_y + (1.0-pertWgt)*th_ups_y_perturb
  qv_ups_x = pertWgt*qv_ups_x + (1.0-pertWgt)*qv_ups_x_perturb
  qv_ups_y = pertWgt*qv_ups_y + (1.0-pertWgt)*qv_ups_y_perturb
  u_ups_x = pertWgt*u_ups_x + (1.0-pertWgt)*u_ups_x_perturb
  u_ups_y = pertWgt*u_ups_y + (1.0-pertWgt)*u_ups_y_perturb
  v_ups_x = pertWgt*v_ups_x + (1.0-pertWgt)*v_ups_x_perturb
  v_ups_y = pertWgt*v_ups_y + (1.0-pertWgt)*v_ups_y_perturb

  tau_x = pertWgt*tau_x + (1.0-pertWgt)*tau_x_perturb
  tau_y = pertWgt*tau_y + (1.0-pertWgt)*tau_y_perturb

  ; need a physical bounds check on QV?

end if; perturb?

; write to file
forceFile->TH_UPSTREAM_X = (/th_ups_x(0:nForceTimes-1,1:nl-1)/) ; strip sfc
forceFile->TH_UPSTREAM_Y = (/th_ups_y(0:nForceTimes-1,1:nl-1)/) ; strip sfc
forceFile->QV_UPSTREAM_X = (/qv_ups_x(0:nForceTimes-1,1:nl-1)/) ; strip sfc
forceFile->QV_UPSTREAM_Y = (/qv_ups_y(0:nForceTimes-1,1:nl-1)/) ; strip sfc
forceFile->U_UPSTREAM_X = (/u_ups_x(0:nForceTimes-1,1:nl-1)/) ; strip sfc
forceFile->U_UPSTREAM_Y = (/u_ups_y(0:nForceTimes-1,1:nl-1)/) ; strip sfc
forceFile->V_UPSTREAM_X = (/v_ups_x(0:nForceTimes-1,1:nl-1)/) ; strip sfc
forceFile->V_UPSTREAM_Y = (/v_ups_y(0:nForceTimes-1,1:nl-1)/) ; strip sfc
forceFile->TAU_X = (/tau_x(0:nForceTimes-1,1:nl-1)/) ; strip sfc
forceFile->TAU_Y = (/tau_y(0:nForceTimes-1,1:nl-1)/) ; strip sfc

; compute tendencies
th_ups_x_tend = forceFile->TH_UPSTREAM_X_TEND
th_ups_y_tend = forceFile->TH_UPSTREAM_Y_TEND
qv_ups_x_tend = forceFile->QV_UPSTREAM_X_TEND
qv_ups_y_tend = forceFile->QV_UPSTREAM_Y_TEND
u_ups_x_tend = forceFile->U_UPSTREAM_X_TEND
u_ups_y_tend = forceFile->U_UPSTREAM_Y_TEND
v_ups_x_tend = forceFile->V_UPSTREAM_X_TEND
v_ups_y_tend = forceFile->V_UPSTREAM_Y_TEND
tau_x_tend = forceFile->TAU_X_TEND
tau_y_tend = forceFile->TAU_Y_TEND

th_ups_x_tend = (th_ups_x(1:nt-1,1:nl-1) - \\
              th_ups_x(0:nt-2,1:nl-1))/conform(th_ups_x(0:nt-2,1:nl-1),dt,0)
th_ups_y_tend = (th_ups_y(1:nt-1,1:nl-1) - \\
              th_ups_y(0:nt-2,1:nl-1))/conform(th_ups_y(0:nt-2,1:nl-1),dt,0)
qv_ups_x_tend = (qv_ups_x(1:nt-1,1:nl-1) - \\
              qv_ups_x(0:nt-2,1:nl-1))/conform(qv_ups_x(0:nt-2,1:nl-1),dt,0)
qv_ups_y_tend = (qv_ups_y(1:nt-1,1:nl-1) - \\
              qv_ups_y(0:nt-2,1:nl-1))/conform(qv_ups_y(0:nt-2,1:nl-1),dt,0)
u_ups_x_tend  = (u_ups_x(1:nt-1,1:nl-1) - \\
              u_ups_x(0:nt-2,1:nl-1))/conform(u_ups_x(0:nt-2,1:nl-1),dt,0)
u_ups_y_tend  = (u_ups_y(1:nt-1,1:nl-1) - \\
              u_ups_y(0:nt-2,1:nl-1))/conform(u_ups_y(0:nt-2,1:nl-1),dt,0)
v_ups_x_tend  = (v_ups_x(1:nt-1,1:nl-1) - \\
              v_ups_x(0:nt-2,1:nl-1))/conform(v_ups_x(0:nt-2,1:nl-1),dt,0)
v_ups_y_tend  = (v_ups_y(1:nt-1,1:nl-1) - \\
              v_ups_y(0:nt-2,1:nl-1))/conform(v_ups_y(0:nt-2,1:nl-1),dt,0)
tau_x_tend  = (tau_x(1:nt-1,1:nl-1) - \\
              tau_x(0:nt-2,1:nl-1))/conform(tau_x(0:nt-2,1:nl-1),dt,0)
tau_y_tend  = (tau_y(1:nt-1,1:nl-1) - \\
              tau_y(0:nt-2,1:nl-1))/conform(tau_y(0:nt-2,1:nl-1),dt,0)

; write to file
forceFile->TH_UPSTREAM_X_TEND = (/th_ups_x_tend/) 
forceFile->TH_UPSTREAM_Y_TEND = (/th_ups_y_tend/) 
forceFile->QV_UPSTREAM_X_TEND = (/qv_ups_x_tend/) 
forceFile->QV_UPSTREAM_Y_TEND = (/qv_ups_y_tend/) 
forceFile->U_UPSTREAM_X_TEND = (/u_ups_x_tend/) 
forceFile->U_UPSTREAM_Y_TEND = (/u_ups_y_tend/) 
forceFile->V_UPSTREAM_X_TEND = (/v_ups_x_tend/) 
forceFile->V_UPSTREAM_Y_TEND = (/v_ups_y_tend/) 
forceFile->TAU_X_TEND = (/tau_x_tend/) 
forceFile->TAU_Y_TEND = (/tau_y_tend/) 

;-------------------------------------------------------------
; Now deal with initial conditions.
; These are directly from the NARR so the elevation is different.
;-------------------------------------------------------------

; first get surface
f = addfile(centerFiles(0),"r")
sfcvars = get_surface_vars(f,xll,yll)

if ( rotate ) then 
   utmp = gridwind_to_truewind("U",sfcvars@u10,sfcvars@v10,lat,lon,map_proj,std_lon,true_lat1,true_lat2)
   vtmp = gridwind_to_truewind("V",sfcvars@u10,sfcvars@v10,lat,lon,map_proj,std_lon,true_lat1,true_lat2)
   sfcvars@u10 = (/utmp/)
   sfcvars@v10 = (/vtmp/)
   delete(utmp)
   delete(vtmp)
end if

if ( perturb ) then

  f_perturb = addfile(pertFiles(0),"r")
  sfcvars_perturb = get_surface_vars(f_perturb,xll,yll)

  if ( rotate ) then 
     utmp = gridwind_to_truewind("U",sfcvars_perturb@u10,sfcvars_perturb@v10,lat,lon,map_proj,std_lon,true_lat1,true_lat2)
     vtmp = gridwind_to_truewind("V",sfcvars_perturb@u10,sfcvars_perturb@v10,lat,lon,map_proj,std_lon,true_lat1,true_lat2)
     sfcvars_perturb@u10 = (/utmp/)
     sfcvars_perturb@v10 = (/vtmp/)
     delete(utmp)
     delete(vtmp)
  end if

end if; perturb?
 
outdat = new((/1,6/),"float")
outdat(0,:) = (/sfcvars@terrain,sfcvars@u10,sfcvars@v10,sfcvars@t2,sfcvars@qv2, \\
           sfcvars@psurf/)

if ( perturb ) then

  outdat_perturb = new((/1,6/),"float")
  outdat_perturb(0,:) = (/sfcvars_perturb@terrain,sfcvars_perturb@u10,sfcvars_perturb@v10,sfcvars_perturb@t2,sfcvars_perturb@qv2, \\
           sfcvars@psurf/)
  outdat = pertWgt*outdat + (1.0-pertWgt)*outdat_perturb
  
  delete(outdat_perturb)

end if; perturb?

mopt = True
mopt@fout = "surface_init.txt"
write_matrix(outdat,"6f12.4",mopt)
delete(outdat)

; now profile
profvars = get_profile_vars(f,zCenterInit,xll,yll)

if ( rotate ) then 
   utmp = gridwind_to_truewind("U",profvars@u,profvars@v,lat,lon,map_proj,std_lon,true_lat1,true_lat2)
   vtmp = gridwind_to_truewind("V",profvars@u,profvars@v,lat,lon,map_proj,std_lon,true_lat1,true_lat2)
   profvars@u = (/utmp/)
   profvars@v = (/vtmp/)
   delete(utmp)
   delete(vtmp)
end if
 
if ( perturb ) then

  profvars_perturb = get_profile_vars(f_perturb,zPertInit,xll,yll)

  if ( rotate ) then 
     utmp = gridwind_to_truewind("U",profvars_perturb@u,profvars_perturb@v,lat,lon,map_proj,std_lon,true_lat1,true_lat2)
     vtmp = gridwind_to_truewind("V",profvars_perturb@u,profvars_perturb@v,lat,lon,map_proj,std_lon,true_lat1,true_lat2)
     profvars_perturb@u = (/utmp/)
     profvars_perturb@v = (/vtmp/)
     delete(utmp)
     delete(vtmp)
  end if
   
end if; perturb?

nz = dimsizes(profvars@z)
outdat = new((/nz,5/),"float")
outdat(:,0) = profvars@z
outdat(:,1) = profvars@u
outdat(:,2) = profvars@v
outdat(:,3) = profvars@t
outdat(:,4) = profvars@qv

if ( perturb ) then

  nz_perturb = dimsizes(profvars_perturb@z)
  outdat_perturb = new((/nz_perturb,5/),"float")
  outdat_perturb(:,0) = profvars_perturb@z
  outdat_perturb(:,1) = profvars_perturb@u
  outdat_perturb(:,2) = profvars_perturb@v
  outdat_perturb(:,3) = profvars_perturb@t
  outdat_perturb(:,4) = profvars_perturb@qv

  ; deal with possibly different number of above-ground initial conditions
  nz_tmp = min((/nz,nz_perturb/))
  outdat_tmp = outdat(nz-nz_tmp:nz-1,:)
  outdat_perturb_tmp = outdat_perturb(nz_perturb-nz_tmp:nz_perturb-1,:)

  outdat_tmp = pertWgt*outdat_tmp + (1.0-pertWgt)*outdat_perturb_tmp

  delete(outdat)
  outdat = outdat_tmp
  delete(outdat_tmp)
  delete(outdat_perturb)

end if; perturb?

mopt@fout = "profile_init.txt"
write_matrix(outdat,"5f12.6",mopt)
delete(outdat)

; finally soil
soilvars = get_soil_vars(f,xll,yll)

; temp fill in skin
soilvars@skin_temp = soilvars@soil_temp(0)
nz = dimsizes(soilvars@soil_level)
outdat = new((/nz+1,3/),"float")
outdat(0,:) = (/0.0,soilvars@deep_soil_temp,soilvars@skin_temp/)
outdat(1:nz,0) = soilvars@soil_level
outdat(1:nz,1) = soilvars@soil_temp
outdat(1:nz,2) = soilvars@soil_mois

if ( perturb ) then

  soilvars_perturb = get_soil_vars(f_perturb,xll,yll)

  ; temp fill in skin
  soilvars_perturb@skin_temp = soilvars_perturb@soil_temp(0)
  nz = dimsizes(soilvars_perturb@soil_level)
  outdat_perturb = new((/nz+1,3/),"float")
  outdat_perturb(0,:) = (/0.0,soilvars_perturb@deep_soil_temp,soilvars_perturb@skin_temp/)
  outdat_perturb(1:nz,0) = soilvars_perturb@soil_level
  outdat_perturb(1:nz,1) = soilvars_perturb@soil_temp
  outdat_perturb(1:nz,2) = soilvars_perturb@soil_mois
  outdat = pertWgt*outdat + (1.0-pertWgt)*outdat_perturb
  delete(outdat_perturb)

end if; perturb?

mopt@fout = "soil_init.txt"
write_matrix(outdat,"3f12.4",mopt)
delete(outdat)

; write out suggested namelist values
; already have lat, long, and num_force_layers
num_force_layers = nl - 1
; for indices just pick one
num_nl = 14
nlStrings           = new(num_nl,"string")
nlStrings(0)        = "&scm"
nlStrings(1)        = "scm_force = 1"
nlStrings(2)        = "scm_force_dx = "+inF@DX
nlStrings(3)        = "num_force_layers = "+num_force_layers
nlStrings(4)        = "scm_lu_index = "+f->LU_INDEX(0,0,0)
nlStrings(5)        = "scm_isltyp = ";+f->SOILCAT(0,0,0)      ; correct?
nlStrings(6)        = "scm_vegfra = "+f->GREENFRAC(0,centerMoStart-1,0,0)       ; correct?
nlStrings(7)        = "scm_lat = "+lat
nlStrings(8)        = "scm_lon = "+lon
nlStrings(9)        = "scm_th_adv = .false."
nlStrings(10)        = "scm_wind_adv = .false."
nlStrings(11)       = "scm_qv_adv = .false."
nlStrings(12)       = "scm_vert_adv = .true."
nlStrings(num_nl-1) = "/"
asciiwrite("suggested_namelist.txt",nlStrings)

end

