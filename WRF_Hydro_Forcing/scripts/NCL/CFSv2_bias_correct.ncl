;------------------------------------------------------------------------------------------
;    CFSv2_bias_correct.ncl
;
;
;    Project: WRF-Hydro IOC for National Water Center
;
;    Authors: Linlin Pan
;             National Center for Atmospheric Research
;             Research Applications Laboratory
;             lpan@ucar.edu
;             303-497-2752
;
;             Logan Karsten
;             National Center for Atmospheric Research
;             Research Applications Laboratory
;             karsten@ucar.edu
;             303-497-2693
;
;    Purpose: This is a top-level NCL script that will
;             apply CFSv2 and NLDAS2 parametric distributional
;             fits to correct CFSv2 data to fit the NLDAS
;             distribution. This script will open parameter files
;             and call NCL functions to perform the fitting.
;
;    Remarks: This corrects the CFSv2 fitted climatology to match
;             the fitted NLDAS2 climatology. There are of 
;             course errors in the fit, which is something
;             to look at going forward. Output will be NetCDF
;             files for each of the six hours in one CFSv2 forecast
;             cycle. In the future, perhaps parameter files could
;             be combined to simplify IO.
;
;    Usage: ncl 'fileIn="./CFSv2/20151113/18/04/flxf2015112918.04.2015111318.grb2"'
;               'tmpDir="./tmp_out"'
;               'nldasParamHr1="./para/nldas2/climo/nldas2_112913_dist_params.nc"'
;               'nldasParamHr2="./para/nldas2/climo/nldas2_112914_dist_params.nc"'
;               'nldasParamHr3="./para/nldas2/climo/nldas2_112915_dist_params.nc"'
;               'nldasParamHr4="./para/nldas2/climo/nldas2_112916_dist_params.nc"'
;               'nldasParamHr5="./para/nldas2/climo/nldas2_112917_dist_params.nc"'
;               'nldasParamHr6="./para/nldas2/climo/nldas2_112918_dist_params.nc"'
;               'cfs2TParam0="./para/cfsv2/climo/cfs_tmp2m_1129_12_dist_params.nc"'
;               'cfs2TParam1="./para/cfsv2/climo/cfs_tmp2m_1129_18_dist_params.nc"'
;               'cfsSWParam0="./para/cfsv2/climo/cfs_dswsfc_1129_12_dist_params.nc"'
;               'cfsSWParam1="./para/cfsv2/climo/cfs_dswsfc_1129_18_dist_params.nc"'
;               'cfsLWParam0="./para/cfsv2/climo/cfs_dlwsfc_1129_12_dist_params.nc"'
;               'cfsLWParam1="./para/cfsv2/climo/cfs_dlwsfc_1129_18_dist_params.nc"'
;               'cfsPCPParam0="./para/cfsv2/climo/cfs_prate_1129_12_dist_params.nc"'
;               'cfsPCPParam1="./para/cfsv2/climo/cfs_prate_1129_18_dist_params.nc"'
;               'cfsPRESParam0="./para/cfsv2/climo/cfs_pressfc_1129_12_dist_params.nc"'
;               'cfsPRESParam1="./para/cfsv2/climo/cfs_pressfc_1129_18_dist_params.nc"'
;               'cfsUParam0="./para/cfsv2/climo/cfs_ugrd_1129_12_dist_params.nc"'
;               'cfsUParam1="./para/cfsv2/climo/cfs_ugrd_1129_18_dist_params.nc"'
;               'cfsVParam0="./para/cfsv2/climo/cfs_vgrd_1129_12_dist_params.nc"'
;               'cfsVParam1="./para/cfsv2/climo/cfs_vgrd_1129_18_dist_params.nc"'
;               'cfs2QParam0="./para/cfsv2/climo/cfs_q2m_1129_12_dist_params.nc"'
;               'cfs2QParam1="./para/cfsv2/climo/cfs_q2m_1129_18_dist_params.nc"'
;               'cycleYYYYMMDDHH="2015111318"'
;               'fcstYYYYMMDDHH="2015112918"'
;               'prevYYYYMMDDHH="2015112912"'
;               'corrFile="./nldas_param_cfsv2_subset_grid_correspondence.nc"'
;               'fileInPrev="./CFSv2/20151113/18/04/flxf2015112918.04.2015111312.grb2"'
;               'em="02"'
;
;------------------------------------------------------------------------------------------

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/ut_string.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"

begin

  ; Load bias correction module file containing correction/combine routines
  load "$CFS_NCL_BIAS_MOD"

  ; Determine if this is a initial time step or not.
  if (toint(cycleYYYYMMDDHH) .eq. toint(fcstYYYYMMDDHH))
    fFlag = 1
  else
    fFlag = 0
  end if

  ; Open input file and extract variables to be corrected
  inFile = addfile(fileIn,"r")

  cfs_lat1d = inFile->lat_0
  cfs_lon1d = inFile->lon_0

  cfs2mTIn = inFile->TMP_P0_L103_GGA0
  cfsUIn = inFile->UGRD_P0_L103_GGA0
  cfsVIn = inFile->VGRD_P0_L103_GGA0
  cfsDSIn = inFile->DSWRF_P0_L1_GGA0
  cfsDLIn = inFile->DLWRF_P0_L1_GGA0
  cfsPCPIn = inFile->PRATE_P0_L1_GGA0
  cfsQIn = inFile->SPFH_P0_L103_GGA0
  cfsPRESIn = inFile->PRES_P0_L1_GGA0

  ; Open previous forecast time variables that will be
  ; used for interpolation.
  inFilePrev = addfile(fileInPrev,"r")

  cfs2mTInPrev = inFilePrev->TMP_P0_L103_GGA0
  cfsUInPrev = inFilePrev->UGRD_P0_L103_GGA0
  cfsVInPrev = inFilePrev->VGRD_P0_L103_GGA0
  cfsDSInPrev = inFilePrev->DSWRF_P0_L1_GGA0
  cfsDLInPrev = inFilePrev->DLWRF_P0_L1_GGA0
  cfsPCPInPrev = inFilePrev->PRATE_P0_L1_GGA0
  cfsQInPrev = inFilePrev->SPFH_P0_L103_GGA0
  cfsPRESInPrev = inFilePrev->PRES_P0_L1_GGA0

  ; Subset the data from 15 to 60 N and -150 to 50 W.
  ; That corresponds to (30:78,224:331) (lat,lon).
  ; It encompasses the WRF-Hydro IOC domain.
  xstart = 224
  xend   = 331
  ystart = 30
  yend   = 78
  nx = xend - xstart + 1
  ny = yend - ystart + 1

  lat_arr = new((/ny,nx/),"float")
  lon_arr = new((/ny,nx/),"float")
  xClick = 0
  yClick = 0
  do xTemp = xstart, xend
    lon_arr(:,xClick) = cfs_lon1d(xTemp)
    xClick = xClick + 1
  end do
  do yTemp = ystart, yend
    lat_arr(yClick,:) = cfs_lat1d(yTemp)
    yClick = yClick + 1
  end do
  lat_arr = lat_arr(::-1,:)

  cfs2mTSub = cfs2mTIn(ystart:yend,xstart:xend)
  cfsUSub = cfsUIn(ystart:yend,xstart:xend)
  cfsVSub = cfsVIn(ystart:yend,xstart:xend)
  cfsDSSub = cfsDSIn(ystart:yend,xstart:xend)
  cfsDLSub = cfsDLIn(ystart:yend,xstart:xend)
  cfsPCPSub = cfsPCPIn(ystart:yend,xstart:xend)
  cfsQSub = cfsQIn(ystart:yend,xstart:xend)
  cfsPRESSub = cfsPRESIn(ystart:yend,xstart:xend)

  cfs2mTSubPrev = cfs2mTInPrev(ystart:yend,xstart:xend)
  cfsUSubPrev = cfsUInPrev(ystart:yend,xstart:xend)
  cfsVSubPrev = cfsVInPrev(ystart:yend,xstart:xend)
  cfsDSSubPrev = cfsDSInPrev(ystart:yend,xstart:xend)
  cfsDLSubPrev = cfsDLInPrev(ystart:yend,xstart:xend)
  cfsPCPSubPrev = cfsPCPInPrev(ystart:yend,xstart:xend)
  cfsQSubPrev = cfsQInPrev(ystart:yend,xstart:xend)
  cfsPRESSubPrev = cfsPRESInPrev(ystart:yend,xstart:xend)

  delete(cfs2mTIn)
  delete(cfsUIn)
  delete(cfsVIn)
  delete(cfsDSIn)
  delete(cfsDLIn)
  delete(cfsPCPIn)
  delete(cfsQIn)
  delete(cfsPRESIn)

  delete(cfs2mTInPrev)
  delete(cfsUInPrev)
  delete(cfsVInPrev)
  delete(cfsDSInPrev)
  delete(cfsDLInPrev)
  delete(cfsPCPInPrev)
  delete(cfsQInPrev)
  delete(cfsPRESInPrev)

  dSizes = dimsizes(cfs2mTSub)
  nlat = dSizes(0)
  nlon = dSizes(1)
  delete(dSizes)

  ;-------------------------------------------------------------------------------------------
  ; Apply parametric distribution correction.
  ; Want to end up with hourly CFSv2 corrected data.
  ; This means that we need to interpolate the 6-hrly data (use linear interpolation in time)
  ; and then apply the hourly NLDAS distribution corrections.
  ;-------------------------------------------------------------------------------------------

  ;-------------------------------------------
  ; Since we only have one forecast time step, 
  ; will only need to loop through 6-hour gap.
  ;-------------------------------------------

  ; Declare output array, which will hold ALL output variables for all time steps.
  ; These arrays will then be used at the end to output combined hourly files.
  ; These files will go onto further refinement through regridding and topographic
  ; adjustments.

  cfs_adjusted_2T = new((/6,nlat,nlon/),"double")
  cfs_adjusted_U = new((/6,nlat,nlon/),"double")
  cfs_adjusted_V = new((/6,nlat,nlon/),"double")
  cfs_adjusted_SW = new((/6,nlat,nlon/),"double")
  cfs_adjusted_LW = new((/6,nlat,nlon/),"double")
  cfs_adjusted_PRES = new((/6,nlat,nlon/),"double")
  cfs_adjusted_PCP = new((/6,nlat,nlon/),"double")
  cfs_adjusted_Q = new((/6,nlat,nlon/),"double")

  ; Open correspondance file
  cFile = addfile(corrFile,"r")
  grid_lon = cFile->grid_lon
  grid_lat = cFile->grid_lat
  grid_s_lon = cFile->start_lon
  grid_e_lon = cFile->end_lon
  grid_s_lat = cFile->start_lat
  grid_e_lat = cFile->end_lat

  ;-----------------------------------------------------------------------------
  ; open cfsv2 distribution files
  ; open the distribution file corresponding to the current forecast valid time
  ; and the one 6-hrs prior
  ;-----------------------------------------------------------------------------

  param_cfs_2T = new((/4,ny,nx/),"double")
  param_cfs_U = new((/4,ny,nx/),"double")
  param_cfs_V = new((/4,ny,nx/),"double")
  param_cfs_SW = new((/4,ny,nx/),"double")
  param_cfs_LW = new((/4,ny,nx/),"double")
  param_cfs_PCP = new((/8,ny,nx/),"double")
  param_cfs_PRES = new((/4,ny,nx/),"double")
  param_cfs_Q = new((/4,ny,nx/),"double")

  param_cfs_2T = extract_cfs_parm("2t",cfs2TParam0,cfs2TParam1,xstart,xend,ystart,yend)
  param_cfs_U = extract_cfs_parm("u",cfsUParam0,cfsUParam1,xstart,xend,ystart,yend)
  param_cfs_V = extract_cfs_parm("v",cfsVParam0,cfsVParam1,xstart,xend,ystart,yend)
  param_cfs_SW = extract_cfs_parm("sw",cfsSWParam0,cfsSWParam1,xstart,xend,ystart,yend)
  param_cfs_LW = extract_cfs_parm("lw",cfsLWParam0,cfsLWParam1,xstart,xend,ystart,yend)
  param_cfs_PCP = extract_cfs_parm("prate",cfsPCPParam0,cfsPCPParam1,xstart,xend,ystart,yend)
  param_cfs_PRES = extract_cfs_parm("pres",cfsPRESParam0,cfsPRESParam1,xstart,xend,ystart,yend)
  param_cfs_Q = extract_cfs_parm("q",cfs2QParam0,cfs2QParam1,xstart,xend,ystart,yend)

  ; Assign CFSv2 lat/lon data and attributes which will later be outputed to a 
  ; NetCDF file
  cfsLatSub = param_cfs_PCP(6,:,:)
  cfsLonSub = param_cfs_PCP(7,:,:)
  cfsLatSub@units = "Degrees North"
  cfsLonSub@units = "Degrees West"
  cfsLatSub@long_name = "CFSv2 Sub-Window Latitude"
  cfsLonSub@long_name = "CFSv2 Sub-Window Longitude"

  ;-----------------------------------------
  ; Open and read NLDAS2 distribution files 
  ;-----------------------------------------

  ; Open one NLDAS file to extract grid info
  dfile = addfile(nldasParamHr1,"r")
  nldas_lat = dfile->lat_0
  nldas_lon = dfile->lon_0
  dsizes = dimsizes(nldas_lat)
  nlat_nldas = dsizes(0)
  dsizes = dimsizes(nldas_lon)
  nlon_nldas = dsizes(0)
  delete(dsizes)

  ; Create NLDAS parameter arrays to hold data.
  param_nldas_2T = new((/12,nlat_nldas,nlon_nldas/),"double")
  param_nldas_U = new((/12,nlat_nldas,nlon_nldas/),"double")
  param_nldas_V = new((/12,nlat_nldas,nlon_nldas/),"double")
  param_nldas_SW = new((/12,nlat_nldas,nlon_nldas/),"double")
  param_nldas_LW = new((/12,nlat_nldas,nlon_nldas/),"double")
  param_nldas_PCP = new((/18,nlat_nldas,nlon_nldas/),"double")
  param_nldas_PRES = new((/12,nlat_nldas,nlon_nldas/),"double")
  param_nldas_Q = new((/12,nlat_nldas,nlon_nldas/),"double")
 
  param_nldas_2T = extract_nldas_parm("2t",nldasParamHr1,nldasParamHr2, \
                   nldasParamHr3,nldasParamHr4,nldasParamHr5,nldasParamHr6)
  param_nldas_U = extract_nldas_parm("u",nldasParamHr1,nldasParamHr2, \
                  nldasParamHr3,nldasParamHr4,nldasParamHr5,nldasParamHr6)
  param_nldas_V = extract_nldas_parm("v",nldasParamHr1,nldasParamHr2, \
                  nldasParamHr3,nldasParamHr4,nldasParamHr5,nldasParamHr6)
  param_nldas_SW = extract_nldas_parm("sw",nldasParamHr1,nldasParamHr2, \
                   nldasParamHr3,nldasParamHr4,nldasParamHr5,nldasParamHr6)
  param_nldas_LW = extract_nldas_parm("lw",nldasParamHr1,nldasParamHr2, \
                   nldasParamHr3,nldasParamHr4,nldasParamHr5,nldasParamHr6)
  param_nldas_PCP = extract_nldas_parm("prate",nldasParamHr1,nldasParamHr2, \
                    nldasParamHr3,nldasParamHr4,nldasParamHr5,nldasParamHr6)
  param_nldas_PRES = extract_nldas_parm("pres",nldasParamHr1,nldasParamHr2, \
                     nldasParamHr3,nldasParamHr4,nldasParamHr5,nldasParamHr6)
  param_nldas_Q = extract_nldas_parm("q",nldasParamHr1,nldasParamHr2, \
                  nldasParamHr3,nldasParamHr4,nldasParamHr5,nldasParamHr6)

  ;--------------------------------------------
  ;NLDAS remapping to cover entire CFS domain
  ;--------------------------------------------

  ;use the nearest neighbor correspondence for the entire
  ;nldas grid file (including missing value points)
  ;run through and place at proper grid points
  ;everything else is missing value, to be later fille with
  ;cfs raw forecast values without bias correction

  nldas_param_cfs_2T = new((/12,nlat,nlon/),"double")
  nldas_param_cfs_U = new((/12,nlat,nlon/),"double")
  nldas_param_cfs_V = new((/12,nlat,nlon/),"double")
  nldas_param_cfs_SW = new((/12,nlat,nlon/),"double")
  nldas_param_cfs_LW = new((/12,nlat,nlon/),"double")
  nldas_param_cfs_PCP = new((/18,nlat,nlon/),"double")
  nldas_param_cfs_PRES = new((/12,nlat,nlon/),"double")
  nldas_param_cfs_Q = new((/12,nlat,nlon/),"double")

  nldas_param_cfs_2T = nldas_param_cfs_nn("2t",nlat,nlon,param_nldas_2T, \
                       grid_lat,grid_lon,grid_s_lat,grid_e_lat,grid_s_lon,grid_e_lon)
  nldas_param_cfs_U = nldas_param_cfs_nn("u",nlat,nlon,param_nldas_U, \
                       grid_lat,grid_lon,grid_s_lat,grid_e_lat,grid_s_lon,grid_e_lon)
  nldas_param_cfs_V = nldas_param_cfs_nn("v",nlat,nlon,param_nldas_V, \
                       grid_lat,grid_lon,grid_s_lat,grid_e_lat,grid_s_lon,grid_e_lon)
  nldas_param_cfs_SW = nldas_param_cfs_nn("sw",nlat,nlon,param_nldas_SW, \
                       grid_lat,grid_lon,grid_s_lat,grid_e_lat,grid_s_lon,grid_e_lon)
  nldas_param_cfs_LW = nldas_param_cfs_nn("lw",nlat,nlon,param_nldas_LW, \
                       grid_lat,grid_lon,grid_s_lat,grid_e_lat,grid_s_lon,grid_e_lon)
  nldas_param_cfs_PCP = nldas_param_cfs_nn("prate",nlat,nlon,param_nldas_PCP, \
                       grid_lat,grid_lon,grid_s_lat,grid_e_lat,grid_s_lon,grid_e_lon)
  nldas_param_cfs_PRES = nldas_param_cfs_nn("pres",nlat,nlon,param_nldas_PRES, \
                       grid_lat,grid_lon,grid_s_lat,grid_e_lat,grid_s_lon,grid_e_lon)
  nldas_param_cfs_Q = nldas_param_cfs_nn("q",nlat,nlon,param_nldas_Q, \
                      grid_lat,grid_lon,grid_s_lat,grid_e_lat,grid_s_lon,grid_e_lon)
  ;------------------------------------------------------
  ; Perform correction to CFSv2 data.
  ;------------------------------------------------------

  cfs_adjusted_2T = cfsv2_correct("2t",nlat,nlon,nldas_param_cfs_2T,param_cfs_2T, \
                   cfs2mTSub,cfs2mTSubPrev,fFlag)
   cfs_adjusted_Q = cfsv2_correct("q",nlat,nlon,nldas_param_cfs_Q,param_cfs_Q, \
                   cfsQSub,cfsQSubPrev,fFlag)
  cfs_adjusted_U = cfsv2_correct("u",nlat,nlon,nldas_param_cfs_U,param_cfs_U, \
                   cfsUSub,cfsUSubPrev,fFlag)
  cfs_adjusted_V = cfsv2_correct("v",nlat,nlon,nldas_param_cfs_V,param_cfs_V, \
                   cfsVSub,cfsVSubPrev,fFlag)
  cfs_adjusted_SW = cfsv2_correct("sw",nlat,nlon,nldas_param_cfs_SW,param_cfs_SW, \
                    cfsDSSub,cfsDSSubPrev,fFlag)
  cfs_adjusted_LW = cfsv2_correct("lw",nlat,nlon,nldas_param_cfs_LW,param_cfs_LW, \
                    cfsDLSub,cfsDLSubPrev,fFlag)
  cfs_adjusted_PRES = cfsv2_correct("pres",nlat,nlon,nldas_param_cfs_PRES,param_cfs_PRES, \
                      cfsPRESSub,cfsPRESSubPrev,fFlag)
  cfs_adjusted_PCP = cfsv2_correct("prate",nlat,nlon,nldas_param_cfs_PCP,param_cfs_PCP, \
                     cfsPCPSub,cfsPCPSubPrev,fFlag)

  ;------------------------------------------------------
  ; Output bias-corrected CFSv2 data to six hourly 
  ; NetCDF files for each hour within a CFSv2 forecast
  ; period. 
  ;------------------------------------------------------

  em_str = em
 
  yearPrev = toint(str_get_cols(prevYYYYMMDDHH,0,3))
  monthPrev = toint(str_get_cols(prevYYYYMMDDHH,4,5))
  dayPrev = toint(str_get_cols(prevYYYYMMDDHH,6,7))
  hrPrev = toint(str_get_cols(prevYYYYMMDDHH,8,9))

  init_time = cd_inv_calendar(yearPrev, monthPrev, dayPrev, hrPrev, 00, 00, \
                              "hours since 1900-1-1 00:00:0.0",0)
  if (fFlag .eq. 1) then
    numHr = 1 
  else
    numHr = 6
  end if
  do n = 1,numHr ; Loop through each six hours
    ; Assign local temporary adjusted output arrays
    cfs_adjusted_2T_hour = cfs_adjusted_2T(n-1,:,:)
    cfs_adjusted_Q_hour = cfs_adjusted_Q(n-1,:,:)
    cfs_adjusted_U_hour = cfs_adjusted_U(n-1,:,:)
    cfs_adjusted_V_hour = cfs_adjusted_V(n-1,:,:)
    cfs_adjusted_SW_hour = cfs_adjusted_SW(n-1,:,:)
    cfs_adjusted_LW_hour = cfs_adjusted_LW(n-1,:,:)
    cfs_adjusted_PRES_hour = cfs_adjusted_PRES(n-1,:,:)
    cfs_adjusted_PCP_hour = cfs_adjusted_PCP(n-1,:,:)
    
    if (fFlag .eq. 1) then 
      valid_time = init_time 
    else
      valid_time = init_time + n
    end if
    valid_time@units = "hours since 1900-1-1 00:00:0.0"
    fcst_time = cd_calendar(valid_time,0)

    fcstYYYYStr = sprinti("%0.4i",toint(fcst_time(0,0)))
    fcstMMStr = sprinti("%0.2i",toint(fcst_time(0,1)))
    fcstDDStr = sprinti("%0.2i",toint(fcst_time(0,2)))
    fcstHHStr = sprinti("%0.2i",toint(fcst_time(0,3)))
 
    ; Create output file name
    strArr = (/tmpDir,"/CFSv2_bias_corrected_TMP_",cycleYYYYMMDDHH, \
              "_",fcstYYYYStr,fcstMMStr,fcstDDStr,fcstHHStr,".M",em_str,".nc"/)
    out_file = str_concat(strArr)

    ; Open NetCDF file for writing
    ncdf = addfile(out_file,"c")

    ; Define global attributes
    fAtt = True
    fAtt@title = "Bias corrected CFSv2 forecast data"
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
    filevardef(ncdf,"T2D",typeof(cfs_adjusted_2T_hour),dimNames)
    filevarattdef(ncdf,"T2D",cfs_adjusted_2T_hour)
    ncdf->T2D = (/cfs_adjusted_2T_hour/)

    filevardef(ncdf,"PSFC",typeof(cfs_adjusted_PRES_hour),dimNames)
    filevarattdef(ncdf,"PSFC",cfs_adjusted_PRES_hour)
    ncdf->PSFC = (/cfs_adjusted_PRES_hour/)

    filevardef(ncdf,"U2D",typeof(cfs_adjusted_U_hour),dimNames)
    filevarattdef(ncdf,"U2D",cfs_adjusted_U_hour)
    ncdf->U2D = (/cfs_adjusted_U_hour/)
   
    filevardef(ncdf,"V2D",typeof(cfs_adjusted_V_hour),dimNames)
    filevarattdef(ncdf,"V2D",cfs_adjusted_V_hour)
    ncdf->V2D = (/cfs_adjusted_V_hour/)

    filevardef(ncdf,"Q2D",typeof(cfs_adjusted_Q_hour),dimNames)
    filevarattdef(ncdf,"Q2D",cfs_adjusted_Q_hour)
    ncdf->Q2D = (/cfs_adjusted_Q_hour/)

    filevardef(ncdf,"RAINRATE",typeof(cfs_adjusted_PCP_hour),dimNames)
    filevarattdef(ncdf,"RAINRATE",cfs_adjusted_PCP_hour)
    ncdf->RAINRATE = (/cfs_adjusted_PCP_hour/)

    filevardef(ncdf,"LWDOWN",typeof(cfs_adjusted_LW_hour),dimNames)
    filevarattdef(ncdf,"LWDOWN",cfs_adjusted_LW_hour)
    ncdf->LWDOWN = (/cfs_adjusted_LW_hour/)

    filevardef(ncdf,"SWDOWN",typeof(cfs_adjusted_SW_hour),dimNames)
    filevarattdef(ncdf,"SWDOWN",cfs_adjusted_SW_hour)
    ncdf->SWDOWN = (/cfs_adjusted_SW_hour/)
 
  end do

end  
