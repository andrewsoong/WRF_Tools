;-----------------------------------------------------------
;    layer_anal_assim.ncl
;
;
;    Project: WRF-Hydro IOC for National Water Center
;
;    Authors: Logan Karsten
;             National Center for Atmospheric Research
;             Research Applications Laboratory
;             karsten@ucar.edu
;             303-497-2693
;
;
;    Purpose: This is a top level NCL script that will 
;             layer RAP, HRRR, and MRMS (precip) data
;             for use in the analysis and assimilation
;             operational WRF-Hydro configuration.
;             This script uses a gap-filling measure
;             to combine RAP, HRRR, and MRMS precipitation
;             developed by David Kitzmiller at the 
;             National Water Center.
;
;    Usage ncl 'hrrrBFile="./hrrr_bias_m02.grib2"'
;              'mrmsBFile="./mrms_bias_m02.grib2"'
;              'rapBFile="./rap_bias_m02.grib2"'
;              'hrrrWFile="./hrrr_weight_m02.grib2"'
;              'mrmsWFile="./mrms_weight_m02.grib2"'
;              'rapWFile="./rap_weight_m02.grib2"'
;              'hrrr0File="./hrrr_f00.grib2"'
;              'hrrr3File="./hrrr_f03.grib2"'
;              'rap0File="./rap_f00.grib2"'
;              'rap3File="./rap_f03.grib2"'
;              'mrmsFile="./mrms.grib2"'
;              'process="2"'
;              'outPath="./201502011200.LDASIN_DOMAIN1"'
;
;-----------------------------------------------------------

begin

  ; Three potential scenarios exist:
  ; 1.) Only Rapid Refresh data is layered. 
  ; 2.) Only Rapid Refresh and HRRR data is layered.
  ; 3.) RAP/HRRR is layered, and MRMS is used for gap-filling
  ;     precipitation data.
  ; This is determined by the process flag

  processInt = toint(process)

  ; At the minimum, Rapid Refresh data will be used
  rap0 = addfile(rap0File,"r")
  rap3 = addfile(rap3File,"r")

  if(process .ge. 2) then ; Open HRRR data
    hrrr0 = addfile(hrrr0File,"r")
    hrrr3 = addfile(hrrr3File,"r") 
  end if
 
  if(process .eq. 3) then ; Open MRMS data
    mrms = addfile(mrmsFile,"r")
  end if

  ; Get dimension size
  dd = dimsizes(rap0->T2D)
  dimlat = dd(0)
  dimlon = dd(1)

  ; Calculate index of where HRRR data is missing
  if(process .ne. 1) then ; Only when layering required
    v1d = ndtooned(hrrr0->T2D)
    index = ind(ismissing(v1d))
  end if 

  ; Process all variables except precip first
  ; Temperature - Comes from 00hr forecast files
  if(process .ne. 1) then
    v1d = ndtooned(rap0->T2D) 
    v2d = ndtooned(hrrr0->T2D)
    v2d(index) = v1d(index)
    T2D = onedtond(v2d,(/dimlat,dimlon/))
  else
    T2D = rap0->T2D
  end if

  ; Specific Humidity - Comes from 00hr forecast files
  if(process .ne. 1) then
    v1d = ndtooned(rap0->Q2D)
    v2d = ndtooned(hrrr0->Q2D)
    v2d(index) = v1d(index)
    Q2D = onedtond(v2d,(/dimlat,dimlon/))
  else
    Q2D = rap0->Q2D
  end if

  ; U Wind - Comes from 00hr forecast files
  if(process .ne. 1) then
    v1d = ndtooned(rap0->U2D)
    v2d = ndtooned(hrrr0->U2D)
    v2d(index) = v1d(index)
    U2D = onedtond(v2d,(/dimlat,dimlon/))
  else
    U2D = rap0->U2D
  end if

  ; V Wind - Comes from 00hr forecast files
  if(process .ne. 1) then
    v1d = ndtooned(rap0->V2D)
    v2d = ndtooned(hrrr0->V2D)
    v2d(index) = v1d(index)
    V2D = onedtond(v2d,(/dimlat,dimlon/))
  else
    V2D = rap0->V2D
  end if 

  ; Pressure - Comes from 00hr forecast files
  if(process .ne. 1) then
    v1d = ndtooned(rap0->PSFC)
    v2d = ndtooned(hrrr0->PSFC)
    v2d(index) = v1d(index)
    PSFC = onedtond(v2d,(/dimlat,dimlon/))
  else
    PSFC = rap0->PSFC
  end if

  ; Downward Longwave - Comes from 03hr forecast files
  if(process .ne. 1) then
    v1d = ndtooned(rap3->LWDOWN)
    v2d = ndtooned(hrrr3->LWDOWN)
    v2d(index) = v1d(index)
    LWDOWN = onedtond(v2d,(/dimlat,dimlon/))
  else
    LWDOWN = rap3->LWDOWN
  end if

  ; Downward Shortwave - Comes from 03hr forecast files
  if(process .ne. 1) then
    v1d = ndtooned(rap3->SWDOWN)
    v2d = ndtooned(hrrr3->SWDOWN)
    v2d(index) = v1d(index)
    SWDOWN = onedtond(v2d,(/dimlat,dimlon/))
  else
    SWDOWN = rap3->SWDOWN
  end if

  ; Process precipitation - Dependent on option
  if(process .eq. 1) then
    RAINRATE = rap3->RAINRATE
  else if (process .eq. 2) then
    v1d = ndtooned(rap3->RAINRATE)
    v2d = ndtooned(hrrr3->RAINRATE)
    v2d(index) = v1d(index)
    RAINRATE = onedtond(v2d,(/dimlat,dimlon/))
  else ; Combin/gap-fill with MRMS
    ; Open parameter files
    fhrrrB = addfile(hrrrBFile,"r")
    fmrmsB = addfile(mrmsBFile,"r")
    frapB = addfile(rapBFile,"r")
    fhrrrW = addfile(hrrrWFile,"r")
    fmrmsW = addfile(mrmsWFile,"r")
    frapW = addfile(rapWFile,"r")
 
    ; Pull precip grids from three products being combined 
    rainHRRR = hrrr3->RAINRATE
    rainRAP = rap3->RAINRATE
    rainMRMS = mrms->precip_rate

    ; Pull param grids
    rainbH = (fhrrrB->POP_P0_L102_GLC0)
    rainbR = (frapB->POP_P0_L102_GLC0)
    rainwM = (fmrmsB->POP_P0_L102_GLC0)
    rainwH = (fhrrrW->APCP_P0_L102_GLC0)
    rainwR = (frapW->POP_P0_L102_GLC0)
    rainbM = (fmrmsW->POP_P0_L102_GLC0)    
  
    ; Set missing bias grid values to 1, which means to bias-correction
    ; will take place. 
    rainbR=where(ismissing(rainbR),1,rainbR)
    rainbH=where(ismissing(rainbH),1,rainbH)
    rainbM=where(ismissing(rainbM),1,rainbM)

    rainrr=rainRAP*rainwR*rainbR
    rainhh=rainHRRR*rainwH*rainbH
    rainmm=rainMRMS*rainwM*rainbM
    rain=rainrr+rainhh+rainmm
    rain = where(ismissing(rainmm).and.(.not.ismissing(rainhh)),rainrr+rainhh,rain)
    rain = where(ismissing(rainhh).and.(.not.ismissing(rainmm)),rainrr+rainmm,rain)
    rain = where(ismissing(rainmm).and.ismissing(rainhh),rainrr,rain)
    RAINRATE = rain

  end if
  end if

  ; Current data is 2D, need to add third time dimension for
  ; final output
  T2D_final = new((/1,dimlat,dimlon/),"double")
  Q2D_final = new((/1,dimlat,dimlon/),"double")
  U2D_final = new((/1,dimlat,dimlon/),"double")
  V2D_final = new((/1,dimlat,dimlon/),"double")
  PSFC_final = new((/1,dimlat,dimlon/),"double")
  RAINRATE_final = new((/1,dimlat,dimlon/),"double")
  LWDOWN_final = new((/1,dimlat,dimlon/),"double")
  SWDOWN_final = new((/1,dimlat,dimlon/),"double")

  T2D_final(0,:,:) = T2D(:,:)
  Q2D_final(0,:,:) = Q2D(:,:)
  U2D_final(0,:,:) = U2D(:,:)
  V2D_final(0,:,:) = V2D(:,:)
  PSFC_final(0,:,:) = PSFC(:,:)
  RAINRATE_final(0,:,:) = RAINRATE(:,:)
  LWDOWN_final(0,:,:) = LWDOWN(:,:)
  SWDOWN_final(0,:,:) = SWDOWN(:,:)

  ;--------------------------------
  ; Establish meta-data
  ;--------------------------------

  T2D_final@missing_value = 1.e+20
  T2D_final@_FillValue = 1.e+20
  T2D_final@remap = "remapped via ESMF_regrid_with_weights: Bilinear"
  T2D_final@units = "K"
  T2D_final@long_name = "2-m Air Temperature"

  Q2D_final@missing_value = 1.e+20
  Q2D_final@_FillValue = 1.e+20
  Q2D_final@remap = "remapped via ESMF_regrid_with_weights: Bilinear"
  Q2D_final@units = "kg/kg"
  Q2D_final@long_name = "2-m specific humidity"

  U2D_final@missing_value = 1.e+20
  U2D_final@_FillValue = 1.e+20
  U2D_final@remap = "remapped via ESMF_regrid_with_weights: Bilinear"
  U2D_final@units = "m/s"
  U2D_final@long_name = "10-m U-wind component"

  V2D_final@missing_value = 1.e+20
  V2D_final@_FillValue = 1.e+20
  V2D_final@remap = "remapped via ESMF_regrid_with_weights: Bilinear"
  V2D_final@units = "m/s"
  V2D_final@long_name = "10-m V-wind component"

  PSFC_final@missing_value = 1.e+20
  PSFC_final@_FillValue = 1.e+20
  PSFC_final@remap = "remapped via ESMF_regrid_with_weights: Bilinear"
  PSFC_final@units = "Pa"
  PSFC_final@long_name = "Surface Pressure"

  RAINRATE_final@missing_value = 1.e+20
  RAINRATE_final@_FillValue = 1.e+20
  RAINRATE_final@remap = "remapped via ESMF_regrid_with_weights: Bilinear"
  RAINRATE_final@units = "mm s^-1"
  RAINRATE_final@long_name = "RAINRATE"
  RAINRATE_final@description = "RAINRATE"

  LWDOWN_final@missing_value = 1.e+20
  LWDOWN_final@_FillValue = 1.e+20
  LWDOWN_final@remap = "remapped via ESMF_regrid_with_weights: Bilinear"
  LWDOWN_final@units = "W/m^2"
  LWDOWN_final@long_name = "Surface downward longwave radiation"

  SWDOWN_final@missing_value = 1.e+20
  SWDOWN_final@_FillValue = 1.e+20
  SWDOWN_final@remap = "remapped via ESMF_regrid_with_weights: Bilinear"
  SWDOWN_final@units = "W/m^2"
  SWDOWN_final@long_name = "Surface downward shortwave radiation"

  ;--------------------------------
  ; Output to final LDASIN files
  ;--------------------------------

  ; Open NetCDF file for writing
  ncdf = addfile(outPath,"c")

  ; Define global attributes
  fAtt = True
  fAtt@title = "Combined HRRR/RAP/MRMS forcing for Analysis and Assimilation WRF-Hydro configuration"
  fAtt@creation_date = systemfunc("date")
  fAtt@author = "National Center for Atmospheric Research"
  fAtt@Conventions = "None"
  fileattdef(ncdf,fAtt)

  ; Define coordinate variables and their dimensionality
  dimNames = (/"Time","south_north","west_east"/)
  dimNames2 = (/"south_north","west_east"/)
  dimSizes = (/-1,dimlat,dimlon/)
  dimUnlim = (/True,False,False/)
  filedimdef(ncdf,dimNames,dimSizes,dimUnlim)

  ; Predefine the dimensionality of the variables to be written out
  filevardef(ncdf,"T2D",typeof(T2D_final),dimNames)
  filevarattdef(ncdf,"T2D",T2D_final)
  ncdf->T2D = (/T2D_final/)

  filevardef(ncdf,"Q2D",typeof(Q2D_final),dimNames)
  filevarattdef(ncdf,"Q2D",Q2D_final)
  ncdf->Q2D = (/Q2D_final/)

  filevardef(ncdf,"U2D",typeof(U2D_final),dimNames)
  filevarattdef(ncdf,"U2D",U2D_final)
  ncdf->U2D = (/U2D_final/)

  filevardef(ncdf,"V2D",typeof(V2D_final),dimNames)
  filevarattdef(ncdf,"V2D",V2D_final)
  ncdf->V2D = (/V2D_final/)

  filevardef(ncdf,"PSFC",typeof(PSFC_final),dimNames)
  filevarattdef(ncdf,"PSFC",PSFC_final)
  ncdf->PSFC = (/PSFC_final/)

  filevardef(ncdf,"RAINRATE",typeof(RAINRATE_final),dimNames)
  filevarattdef(ncdf,"RAINRATE",RAINRATE_final)
  ncdf->RAINRATE = (/RAINRATE_final/)

  filevardef(ncdf,"LWDOWN",typeof(LWDOWN_final),dimNames)
  filevarattdef(ncdf,"LWDOWN",LWDOWN_final)
  ncdf->LWDOWN = (/LWDOWN_final/)

  filevardef(ncdf,"SWDOWN",typeof(SWDOWN_final),dimNames)
  filevarattdef(ncdf,"SWDOWN",SWDOWN_final)
  ncdf->SWDOWN = (/SWDOWN_final/)

end
