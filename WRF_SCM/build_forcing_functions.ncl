; functions to help build the forcing file

undef("forcing_z")
undef("forcing_w")
undef("forcing_u_g")
undef("forcing_v_g")
undef("find_upstream_inds")
undef("avg_uv")
undef("avg_mass")
undef("destagger_dim")
undef("get_neighbors")
undef("get_surface_vars")
undef("get_profile_vars")
undef("get_soil_vars")

load "./conversions.ncl"

;------------------------------------------------

function forcing_z(fList:string,datIn,xll:integer,yll:integer)

local f, nFiles, dims, zIn, zIn_nosfc, dims, nt, nl

begin

  nFiles = dimsizes(fList)

  f = addfiles(fList,"r")
  zIn = addfiles_GetVar(f,fList,"GHT")

  ; remove surface (in first layer)
  dims = dimsizes(zIn)
  nt = dims(0)
  nl = dims(1)
  zIn_nosfc = zIn(:,1:nl-1,:,:) 

  ; simply average (could replace with weighted avg)
  datIn = (/0.25*(zIn_nosfc(:,:,yll,xll) + zIn_nosfc(:,:,yll+1,xll) + zIn_nosfc(:,:,yll,xll+1) + zIn_nosfc(:,:,yll+1,xll+1))/)

  return(datIn)

end

;------------------------------------------------

function forcing_w(fList:string,datIn,xll:integer,yll:integer)

local f, nFiles, dims, wIn, wIn_nosfc, dims, nt, nl

begin

; FOR NOW JUST 0

;  datIn = 0.0
;  print("WARNING: setting W to zero.  Comment out if you want W.")
;  return(datIn)

  
  nFiles = dimsizes(fList)

  f = addfiles(fList,"r")
  f = addfiles(fList,"r")
  WWtmp = addfiles_GetVar(f,fList,"WW")

  wIn = get_w_from_ww(f,fList,WWtmp)

  ; remove surface (in first layer)
  dims = dimsizes(wIn)
  nt = dims(0)
  nl = dims(1)
  wIn_nosfc = wIn(:,1:nl-1,:,:) 

  ; simply average (could replace with weighted avg)
  datIn = (/0.25*(wIn_nosfc(:,:,yll,xll) + wIn_nosfc(:,:,yll+1,xll) + wIn_nosfc(:,:,yll,xll+1) + wIn_nosfc(:,:,yll+1,xll+1))/)

  return(datIn)

end

;--------------------------------------------------------------

function forcing_u_g(fList:string,datIn,fCor,dx,xll:integer,yll:integer)

; computes grid-relative U_g

local f, nFiles, dims, zIn, zIn_nosfc, g

begin

  g = 9.81

  nFiles = dimsizes(fList)

  f = addfiles(fList,"r")
  zIn = addfiles_GetVar(f,fList,"GHT")

  ; remove surface (in first layer)
  dims = dimsizes(zIn)
  nt = dims(0)
  nl = dims(1)
  zIn_nosfc = zIn(:,1:nl-1,:,:) 

  ; compute geostrophic wind in grid coordinates
  zLine = 0.5*(zIn_nosfc(:,:,:,xll)+zIn_nosfc(:,:,:,xll+1));
  dPhi = (zLine(:,:,yll+1)-zLine(:,:,yll))/dx

  datIn = -(g/fCor)*dPhi

  return(datIn)

end

;--------------------------------------------------------------

function forcing_v_g(fList:string,datIn,fCor,dx,xll:integer,yll:integer)

; computes grid-relative V_g

local f, nFiles, dims, zIn, zIn_nosfc, g

begin

  g = 9.81

  nFiles = dimsizes(fList)

  f = addfiles(fList,"r")
  zIn = addfiles_GetVar(f,fList,"GHT")

  ; remove surface (in first layer)
  dims = dimsizes(zIn)
  nt = dims(0)
  nl = dims(1)
  zIn_nosfc = zIn(:,1:nl-1,:,:) 

  ; compute geostrophic wind in grid coordinates, then rotate 
  zLine = 0.5*(zIn_nosfc(:,:,yll,:)+zIn_nosfc(:,:,yll+1,:))
  dPhi = (zLine(:,:,xll+1)-zLine(:,:,xll))/dx

  datIn = (g/fCor)*dPhi

  return(datIn)

end

;--------------------------------------------------------------

function find_upstream_inds(Ma:numeric,cent:integer)

; finds a profile of indices in the variable wind direction that is the 
; upstream point (looks in last dimension)

local dim_to_look, dims, ndims

begin

  dims = dimsizes(Ma)
  ndims = dimsizes(dims)

  inds = new((/dims(0:ndims-2)/),"integer")

  inds = where(Ma(:,:,cent) .ge. 0, 0, 1) 

  return(inds)

end

;--------------------------------------------------------------

function avg_uv(fList:string,var:string,ll:integer)

; averages U in the y-direction to get the wind at the same y-location
; as the grid center
; OR
; averages V in the x-direction to get the wind at the same x-location
; as the grid center


local f, M, dNames

begin

  f = addfiles(fList,"r")

  if ( var .eq. "U" .or. var .eq. "u")
    M = addfiles_GetVar(f,fList,"UU")
    Ma = 0.5*(M(:,:,ll,:)+M(:,:,ll+1,:))
  end if
  if ( var .eq. "V" .or. var .eq. "v")
    M = addfiles_GetVar(f,fList,"VV")
    Ma = 0.5*(M(:,:,:,ll)+M(:,:,:,ll+1))
  end if

  delete(M)
  return(Ma)

end

;--------------------------------------------------------------

function avg_mass(fList:string,var:string,dir:string,ll:integer)


; averages mass coordinate variables in either the X or Y direction

local f, M, Mtmp, dNames, Qv


begin

  f = addfiles(fList,"r")
  Mtmp = addfiles_GetVar(f,fList,var)

  ; convert variables if needed
  if ( var .eq. "RH" ) then
    Qv = get_qv(f,fList,Mtmp)
    Mtmp = (/Qv/)
    delete(Qv)
  end if

  if ( var .eq. "TT" ) then
    TH = get_theta(f,fList,Mtmp)
    Mtmp = (/TH/)
    delete(TH)
  end if

  if ( dir .eq. "Y" .or. dir .eq. "y")
    dNames = getfilevardims(f[0],var)
    M = Mtmp($dNames(0)$|:,$dNames(1)$|:,$dNames(3)$|:,$dNames(2)$|:)
  end if
  if ( dir .eq. "X" .or. dir .eq. "x")
    M = Mtmp
  end if

  Ma = 0.5*(M(:,:,:,ll)+M(:,:,:,ll+1))

  return(Ma)

end

;--------------------------------------------------------------

function destagger_dim(x:numeric)

; destaggers last dimension - for now assumumes 3D input, but can generalize

local dims, ndims, sdim

begin

  dims = dimsizes(x)
  ndims = dimsizes(dims)

  if ( ndims .ne. 3 ) then
    print("destagger_dim cannot destagger unless 3 dimensions")
    return(x)
  end if 

  sdim = dims(ndims-1)

  y = 0.5*(x(:,:,0:sdim-2) + x(:,:,1:sdim-1))

  return(y)

end

;--------------------------------------------------------------

function get_neighbors(fList:string, var:string, ll:integer)

; grabs U to N,S of grid center, or V to E,W of grid center

local f, Mtmp

begin
 
  f = addfiles(fList,"r")

  if ( var .eq. "U" .or. var .eq. "u")
    Mtmp = addfiles_GetVar(f,fList,"UU")
    M = Mtmp(:,:,:,ll)
  end if

  if ( var .eq. "V" .or. var .eq. "v")
    Mtmp = addfiles_GetVar(f,fList,"VV")
    M = Mtmp(:,:,ll,:)
  end if

  return(M)

end

;--------------------------------------------------------------

function get_surface_vars(f:file, xll:integer, yll:integer)

; 1. Surface pressure is base state (WRF) plus perturbation.
; Assume no perturbation, then sfc pressure is only a function of the 
; WRF terrain and base state temp
; 2. Qv from RH
; 3. U,V,T just averaged (winds rotated outside of here)

local Rd, t00, p00, l00, g, terrain_tmp, Lv, Rv, e0, T0, eps, es, T, e, psurf, tmp, RH, T, P, qv, U, V

begin

  Rd = 287.0
  p00 = 1.0e5
  t00 = 290.0
  l00 = 50.0
  g = 9.81

  Lv = 2.5e6
  Rv = 461.6
  Rd = 287.0
  e0 = 0.6112
  T0 = 273.15
  eps = Rd/Rv

  terrain_tmp = f->HGT_M(0,:,:)
  terrain = 0.25*(terrain_tmp(yll,xll) + terrain_tmp(yll+1,xll)+ \\
        terrain_tmp(yll,xll+1) + terrain_tmp(yll+1,xll+1))

  psurf = p00 * exp ( -t00/l00 + ( (t00/l00)^2 - 2.*g*terrain/l00/Rd )^0.5 )

  s = True
  s@terrain = terrain
  s@psurf = psurf

  ; use input sfc pressure and temp to get qv
  tmp = f->RH(0,0,:,:)
  RH = 0.25*(tmp(yll,xll) + tmp(yll+1,xll)+ \\
        tmp(yll,xll+1) + tmp(yll+1,xll+1))
  delete(tmp)
  tmp = f->TT(0,0,:,:)
  T = 0.25*(tmp(yll,xll) + tmp(yll+1,xll)+ \\
        tmp(yll,xll+1) + tmp(yll+1,xll+1))
  delete(tmp)
  tmp = f->PRES(0,0,:,:)
  P = 0.25*(tmp(yll,xll) + tmp(yll+1,xll)+ \\
        tmp(yll,xll+1) + tmp(yll+1,xll+1))
  delete(tmp)

  es = e0*1000.0*exp(Lv/Rv*(1/T0 - 1/T))
  e = RH/100.0 * es
  qv = eps*e/(P-e)

  s@qv2 = qv
  s@t2  = T

  ; winds just avereged 
  tmp = f->UU(0,0,:,:)
  U = avg(tmp(:,xll+1))
  delete(tmp)
  tmp = f->VV(0,0,:,:)
  V = avg(tmp(yll+1,:))
  delete(tmp)

  s@u10  = U
  s@v10  = V

  return(s)

end

;--------------------------------------------------------------

function get_profile_vars(f:file,z:numeric,xll:integer,yll:integer)

; 1. Find input levels greater than the terrain and strip them out
; 2. Qv from RH
; 3. U,V just averaged (winds rotated outside of here)
; 4. Theta from T and P

local Rd, t00, p00, l00, g, terrain_tmp, Lv, Rv, e0, T0, eps, es, T, e, tmp, RH, T, P, qv, p, U, V, P0, TH

begin

  Rd = 287.0
  p00 = 1.0e5
  t00 = 290.0
  l00 = 50.0
  g = 9.81
  P0 = 100000.0

  Lv = 2.5e6
  Rv = 461.6
  Rd = 287.0
  e0 = 0.6112
  T0 = 273.15
  eps = Rd/Rv

  terrain_tmp = f->HGT_M(0,:,:)
  terrain = 0.25*(terrain_tmp(yll,xll) + terrain_tmp(yll+1,xll)+ \\
        terrain_tmp(yll,xll+1) + terrain_tmp(yll+1,xll+1))

  pInds = ind(z .gt. terrain)

  p = True

  p@z = z(pInds)

  ; use input pressure and temp to get qv
  tmp = f->PRES(0,pInds,:,:)
  P = 0.25*(tmp(:,yll,xll) + tmp(:,yll+1,xll)+ \\
        tmp(:,yll,xll+1) + tmp(:,yll+1,xll+1))
  delete(tmp)

  tmp = f->RH(0,pInds,:,:)
  RH = 0.25*(tmp(:,yll,xll) + tmp(:,yll+1,xll)+ \\
        tmp(:,yll,xll+1) + tmp(:,yll+1,xll+1))
  delete(tmp)

  tmp = f->TT(0,pInds,:,:)
  T = 0.25*(tmp(:,yll,xll) + tmp(:,yll+1,xll)+ \\
        tmp(:,yll,xll+1) + tmp(:,yll+1,xll+1))
  delete(tmp)

  TH = T*(P0/P)^(2.0/7.0)

  es = e0*1000.0*exp(Lv/Rv*(1/T0 - 1/T))
  e = RH/100.0 * es
  qv = eps*e/(P-e)

  p@qv = qv
  p@t  = TH

  ; winds just avereged 
  tmp = f->UU(0,pInds,:,:)
  U = dim_avg(tmp(:,:,xll+1))
  delete(tmp)
  tmp = f->VV(0,pInds,:,:)
  V = dim_avg(tmp(:,yll+1,:))
  delete(tmp)

  p@u  = U
  p@v  = V

  return(p)

end

;--------------------------------------------------------------

function get_soil_vars(f:file,xll:integer,yll:integer)

; just get soil levels and horizontally average

local deep_soil_temp, skin_temp, tmp, slTemp, soil_level, soil_temp, slMois, soil_mois, slTcnt, slMcnt

begin

  s = True

  ; deep soil is *I THINK* SOILTEMP
  tmp = f->SOILTEMP(0,:,:)
  deep_soil_temp = 0.25*(tmp(yll,xll) + tmp(yll+1,xll)+ \\
        tmp(yll,xll+1) + tmp(yll+1,xll+1))
  delete(tmp)
 
  s@deep_soil_temp = deep_soil_temp

  ; skin temp is *I THINK* SKINTEMP
  tmp = f->SKINTEMP(0,:,:)
  skin_temp = 0.25*(tmp(yll,xll) + tmp(yll+1,xll)+ \\
        tmp(yll,xll+1) + tmp(yll+1,xll+1))
  delete(tmp)

  s@skin_temp = skin_temp

  varNames = getfilevarnames(f)

  nVars = dimsizes(varNames)

  slTCnt = 0
  slMCnt = 0

  do iV = 0, nVars - 1

    vChar = stringtochar(varNames(iV))

    if ( vChar(0:1) .eq. "ST" .and. dimsizes(vChar) .gt. 3 ) then
      slTop = stringtofloat(chartostring(vChar(2:4)))
      slBot = stringtofloat(chartostring(vChar(5:7)))
      slMid = 0.5*(slTop+slBot) / 100
      
      tmp = f->$varNames(iV)$(0,:,:)
      slTemp = 0.25*(tmp(yll,xll) + tmp(yll+1,xll)+ \\
               tmp(yll,xll+1) + tmp(yll+1,xll+1))
      delete(tmp)

      if ( slTCnt .gt. 0 ) then
         tmp = (/array_append_record(soil_level,slMid,0)/)
         delete(soil_level)
         soil_level = tmp
         delete(tmp)
         tmp = (/array_append_record(soil_temp,slTemp,0)/)
         delete(soil_temp)
         soil_temp = tmp
         delete(tmp)
      else
         soil_level = slMid
         soil_level@_FillValue = -999
         soil_temp = slTemp
         soil_temp@_FillValue = -999
      end if

      slTCnt = slTCnt + 1 
    end if

    if ( vChar(0:1) .eq. "SM" .and. dimsizes(vChar) .gt. 3 ) then
      
      tmp = f->$varNames(iV)$(0,:,:)
      slMois = 0.25*(tmp(yll,xll) + tmp(yll+1,xll)+ \\
               tmp(yll,xll+1) + tmp(yll+1,xll+1))
      delete(tmp)

      if ( slMCnt .gt. 0 ) then
         tmp = (/array_append_record(soil_mois,slMois,0)/)
         delete(soil_mois)
         soil_mois = tmp
         delete(tmp)
      else
         soil_mois = slMois
         soil_mois@_FillValue = -999
      end if

      slMCnt = slMCnt + 1 
    end if

    delete(vChar)

  end do

  s@soil_level = soil_level
  s@soil_temp  = soil_temp
  s@soil_mois  = soil_mois
  return(s)

end
