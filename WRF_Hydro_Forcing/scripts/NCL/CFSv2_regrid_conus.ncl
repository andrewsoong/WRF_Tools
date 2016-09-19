;-----------------------------------------------------------------------------------------
;    CFSv2_regrid_conus.ncl
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
;    Purpose: This is a top-level NCL script that will
;             regrid bias-corrected CFSv2 interpolated
;             hourly data to the conus IOC WRF-Hydro 
;             domain. 
;
;    Usage: ncl 'srcfilename="/d4/karsten/IOC/tmp/CFSv2_bias_corrected_TMP_
;                             2015020100_2015021413.M02.nc"'
;               'outfilename='/d4/karsten/IOC/tmp/CFSv2_bias_corrected_TMP_
;                            2015020100_2015021413_regridded.M02.nc"'
;               'dstGridName='/d4/karsten/IOC/param/geo_dst.nc"'
;               'wgtFileName='/d4/karsten/IOC/param/CFSv2_bilinear_weights_conus.nc"'
;
;------------------------------------------------------------------------------------------

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/ut_string.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"

begin

  ;---------------------------------------------------
  ; Read in source and destination grid NetCDF files
  ;---------------------------------------------------

  dstfile = addfile(dstGridName,"r")
  dlon3d=dstfile->XLONG_M
  dlat3d=dstfile->XLAT_M

  dlon2d=dlon3d(0,:,:)
  dlat2d=dlat3d(0,:,:)

  dims=dimsizes(dlat2d)
  nlat = dims(0)
  nlon = dims(1)
 
  opt               = True
  opt@WghtFileName  = wgtFileName
  opt@CopyVarAtts   = True
  opt@CopyVarCoords = False
  opt@Debug         = False
 
  ;--------------------------------------------------
  ; Open source data file to be regridded
  ;--------------------------------------------------

  datfile = addfile(srcfilename,"r")
  
  ;--------------
  ; Regrid data
  ;-------------

  T2D_regrid = ESMF_regrid_with_weights(datfile->T2D(:,:),wgtFileName,opt)
  Q2D_regrid = ESMF_regrid_with_weights(datfile->Q2D(:,:),wgtFileName,opt)
  U2D_regrid = ESMF_regrid_with_weights(datfile->U2D(:,:),wgtFileName,opt)
  V2D_regrid = ESMF_regrid_with_weights(datfile->V2D(:,:),wgtFileName,opt)
  PSFC_regrid = ESMF_regrid_with_weights(datfile->PSFC(:,:),wgtFileName,opt)
  RAINRATE_regrid = ESMF_regrid_with_weights(datfile->RAINRATE(:,:),wgtFileName,opt)
  LWDOWN_regrid = ESMF_regrid_with_weights(datfile->LWDOWN(:,:),wgtFileName,opt)
  SWDOWN_regrid = ESMF_regrid_with_weights(datfile->SWDOWN(:,:),wgtFileName,opt)

  ;------------------------------------------
  ; Output to NetCDF file
  ;------------------------------------------

  ; Open NetCDF file for writing
  ncdf = addfile(outfilename,"c")

  ; Define global attributes
  fAtt = True
  fAtt@title = "Regridded bias corrected CFSv2 forecast data"
  fAtt@creation_date = systemfunc("date")
  fAtt@author = "National Center for Atmospheric Research"
  fAtt@Conventions = "None"
  fileattdef(ncdf,fAtt)

  ; Definte coordinate variables and their dimensionality
  dimNames = (/"lat","lon"/)
  dimSizes = (/nlat,nlon/)
  dimUnlim = (/False,False/)
  filedimdef(ncdf,dimNames,dimSizes,dimUnlim)

  ; Predefine the dimensionality of the variables to be written out
  filevardef(ncdf,"T2D",typeof(T2D_regrid),dimNames)
  filevarattdef(ncdf,"T2D",T2D_regrid)
  ncdf->T2D = (/T2D_regrid/) 

  filevardef(ncdf,"Q2D",typeof(Q2D_regrid),dimNames)
  filevarattdef(ncdf,"Q2D",Q2D_regrid)
  ncdf->Q2D = (/Q2D_regrid/)

  filevardef(ncdf,"U2D",typeof(U2D_regrid),dimNames)
  filevarattdef(ncdf,"U2D",U2D_regrid)
  ncdf->U2D = (/U2D_regrid/)
  
  filevardef(ncdf,"V2D",typeof(V2D_regrid),dimNames)
  filevarattdef(ncdf,"V2D",V2D_regrid)
  ncdf->V2D = (/V2D_regrid/)
 
  filevardef(ncdf,"PSFC",typeof(PSFC_regrid),dimNames)
  filevarattdef(ncdf,"PSFC",PSFC_regrid)
  ncdf->PSFC = (/PSFC_regrid/)

  filevardef(ncdf,"RAINRATE",typeof(RAINRATE_regrid),dimNames)
  filevarattdef(ncdf,"RAINRATE",RAINRATE_regrid)
  ncdf->RAINRATE = (/RAINRATE_regrid/)
  
  filevardef(ncdf,"LWDOWN",typeof(LWDOWN_regrid),dimNames)
  filevarattdef(ncdf,"LWDOWN",LWDOWN_regrid)
  ncdf->LWDOWN = (/LWDOWN_regrid/)
 
  filevardef(ncdf,"SWDOWN",typeof(SWDOWN_regrid),dimNames)
  filevarattdef(ncdf,"SWDOWN",SWDOWN_regrid)
  ncdf->SWDOWN = (/SWDOWN_regrid/)

end
