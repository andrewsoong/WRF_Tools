;-----------------------------------------------------------
;    CFSv2_bias_correct_mod.ncl
;
;    Project: WRF-Hydro IOC for the National Water Center
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
;    Purpose: This is a module file that contains various 
;             NCL functions to serve CFSv2 bias-correction.
;
;-----------------------------------------------------------

;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
;load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/ut_string.ncl"
;load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"

;================================================================
; This function extracts the CFSv2 distribution parameters
; used for bias correction. Inputs are the CFSv2 parameter
; files for the beginning of the 6-hour forecast time period
; and the end of the forecast time period. Additionally, 
; xstart, xend, ystart, yend for sub-setting required.
;================================================================
function extract_cfs_parm(var:string,file0:string,file1:string,\
                           xs:integer,xe:integer,ys:integer,ye:integer)
local nx, ny, ystart, yend, xstart, xend, dataOut, dfile, param_1, \
      param_2, lat, lon, cfs_lat, cfs_lon, zero_pcp, prev_param_1, \
      prev_param_2, prev_zero_pcp, cfs_param_1, cfs_param_2, \
      prev_cfs_param_1, prev_cfs_param_2, nmiss, z, z2, xTemp, yTemp 
begin
  ; Calculate array sizes
  nx = xe - xs + 1
  ny = ye - ys + 1
  ystart = ys
  yend = ye
  xstart = xs
  xend = xe
  ; Establish output arrays
  if (var .eq. "prate") then
    dataOut = new((/8,ny,nx/),"double") ; Need one variable to store lat/
                                        ; lon. Precip data also requires
                                        ; zero precip probability.
  else 
    dataOut = new((/4,ny,nx/),"double")
  end if

  ; CFSv2 parameter data for valid forecast time
  dfile = addfile(file1,"r")
  param_1 = dfile->DISTRIBUTION_PARAM_1
  param_2 = dfile->DISTRIBUTION_PARAM_2
  lat = dfile->lat_0
  lon = dfile->lon_0
  latSize = dimsizes(lat)
  lonSize = dimsizes(lon)
  nxGlobe = lonSize(0)
  nyGlobe = latSize(0)
  lat_arr = new((/nyGlobe,nxGlobe/),"double")
  lon_arr = new((/nyGlobe,nxGlobe/),"double")
  do xTemp = xs,xe
    lat_arr(ys:ye,xTemp) = lat(ys:ye)
  end do
  do yTemp = ys,ye 
    lon_arr(yTemp,xs:xe) = lon(xs:xe)
  end do
  cfs_lat = lat(ystart:yend)
  cfs_lon = lon(xstart:xend)
  if(var .eq. "prate") then
    zero_pcp = dfile->ZERO_PRECIP_PROB
  end if

  ; CFSv2 parameter data for previous valid forecast time
  dfile = addfile(file0,"r")
  prev_param_1 = dfile->DISTRIBUTION_PARAM_1
  prev_param_2 = dfile->DISTRIBUTION_PARAM_2
  if(var .eq. "prate") then
    prev_zero_pcp = dfile->ZERO_PRECIP_PROB
  end if

  cfs_param_1 = param_1(ystart:yend,xstart:xend)
  cfs_param_2 = param_2(ystart:yend,xstart:xend)
  prev_cfs_param_1 = prev_param_1(ystart:yend,xstart:xend)
  prev_cfs_param_2 = prev_param_2(ystart:yend,xstart:xend)
  if(var .eq. "prate") then
    cfs_zero_pcp = zero_pcp(ystart:yend,xstart:xend)
    prev_cfs_zero_pcp = prev_zero_pcp(ystart:yend,xstart:xend)
  end if

  ; reset missing values to make sure everything is consistent...
  ; some of the netcdf distribution files have incorrect attributes
  ; or missing values that differ from stated fill value
  ; also check for NaNs just in case the distributional fit went awry
  prev_cfs_param_1@_FillValue = 3e+20
  prev_cfs_param_2@_FillValue = 3e+20
  prev_cfs_param_1 = where(prev_cfs_param_1 .gt. 500000,3e+20,prev_cfs_param_1)
  prev_cfs_param_2 = where(prev_cfs_param_2 .gt. 500000,3e+20,prev_cfs_param_2)
  prev_cfs_param_1 = where(isnan_ieee(prev_cfs_param_1),3e+20,prev_cfs_param_1)
  prev_cfs_param_2 = where(isnan_ieee(prev_cfs_param_2),3e+20,prev_cfs_param_2)

  if(var .eq. "prate") then
    cfs_zero_pcp@_FillValue = 3e+20
    cfs_zero_pcp = where(cfs_zero_pcp .gt. 500000,3e+20,cfs_zero_pcp)
    cfs_zero_pcp = where(isnan_ieee(cfs_zero_pcp),3e+20,cfs_zero_pcp)

    prev_cfs_zero_pcp@_FillValue = 3e+20
    prev_cfs_zero_pcp = where(prev_cfs_zero_pcp .gt. 500000,3e+20,prev_cfs_zero_pcp)
    prev_cfs_zero_pcp = where(isnan_ieee(prev_cfs_zero_pcp),3e+20,prev_cfs_zero_pcp)
  end if

  ; Regrid CFSv2 params to remove any missing values if necessary
  nmiss = num(ismissing(cfs_param_1))
 
  if(nmiss .gt. 0) then
    z = grid2triple(cfs_lon,cfs_lat,cfs_param_1)
    z2 = grid2triple(cfs_lon,cfs_lat,cfs_param_2)
    cfs_param_1 = triple2grid(z(0,:),z(1,:),z(2,:),cfs_lon-0.00001,cfs_lat+0.00001,True)
    cfs_param_2 = triple2grid(z2(0,:),z2(1,:),z2(2,:),cfs_lon-0.00001,cfs_lat+0.00001,True)

    delete(z)
    delete(z2)
  end if

  ;previous cfs forecast time distributions
  nmiss = num(ismissing(prev_cfs_param_1))
  if(nmiss .gt. 0) then
    z = grid2triple(cfs_lon,cfs_lat,prev_cfs_param_1)
    z2 = grid2triple(cfs_lon,cfs_lat,prev_cfs_param_2)

    prev_cfs_param_1 = triple2grid(z(0,:),z(1,:),z(2,:),cfs_lon-0.00001,cfs_lat+0.00001,True)
    prev_cfs_param_2 = triple2grid(z2(0,:),z2(1,:),z2(2,:),cfs_lon-0.00001,cfs_lat+0.00001,True)

    delete(z)
    delete(z2)
  end if

  if(var .eq. "prate") then
    nmiss = num(ismissing(cfs_zero_pcp))
    if(nmiss .gt. 0) then
      z = grid2triple(cfs_lon,cfs_lat,cfs_zero_pcp)
      cfs_zero_pcp = triple2grid(z(0,:),z(1,:),z(2,:),cfs_lon-0.00001,cfs_lat-0.00001,True)
      delete(z)

      z = grid2triple(cfs_lon,cfs_lat,prev_cfs_zero_pcp)
      prev_cfs_zero_pcp = triple2grid(z(0,:),z(1,:),z(2,:),cfs_lon-0.00001,cfs_lat-0.00001,True)
      delete(z)
    end if
  end if

  dataOut(0,:,:) = cfs_param_1(:,:)
  dataOut(1,:,:) = cfs_param_2(:,:)
  dataOut(2,:,:) = prev_cfs_param_1(:,:)
  dataOut(3,:,:) = prev_cfs_param_2(:,:)
  if(var .eq. "prate") then
    dataOut(4,:,:) = cfs_zero_pcp(:,:)
    dataOut(5,:,:) = prev_cfs_zero_pcp(:,:)
    ;dataOut(6,:,:) = lat_arr(ystart:yend,xstart:xend)
    ;dataOut(7,:,:) = lon_arr(ystart:yend,xstart:xend)
  end if

  delete(param_1)
  delete(param_2)
  delete(cfs_param_1)
  delete(cfs_param_2)
  delete(prev_param_1)
  delete(prev_param_2)
  delete(prev_cfs_param_1)
  delete(prev_cfs_param_2)
  delete(lat)
  delete(lon)
  if(var .eq. "prate") then
    delete(zero_pcp)
    delete(prev_zero_pcp)
    delete(cfs_zero_pcp)
    delete(prev_cfs_zero_pcp)
  end if

  return(dataOut)
  
end

;================================================================
; This function extracts the NLDAS2 distribution parameters 
; used for bias correction. Inputs are the six NLDAS2 parameter
; files for each of the six hours in a six-hour CFSv2 forecast 
; time period.
;================================================================
function extract_nldas_parm(var:string,file1:string,file2:string, \
                             file3:string,file4:string,file5:string, \
                             file6:string)
local n, fname, dfile, nldas_lat, nldas_lon, dsizes, dataOut, \
      param_1, param_2, zero_pcp 
begin
  ; Loop through six hours of CFSv2 forecast period.
  do n = 0,5 ; Grab files from prev_tim to valid_time (includes 
             ; valid_time, not prev_time)
    if (n .eq. 0) then 
      fname = file1
    else if (n .eq. 1) then
      fname = file2
    else if (n .eq. 2) then
      fname = file3
    else if (n .eq. 3) then
      fname = file4
    else if (n .eq. 4) then
      fname = file5
    else if (n .eq. 5) then
      fname = file6
    end if
    end if
    end if
    end if
    end if
    end if

    ; Open file
    dfile = addfile(fname,"r")

    ; Calculate grid information
    nldas_lat = dfile->lat_0
    nldas_lon = dfile->lon_0
    dsizes = dimsizes(nldas_lat)
    nlat_nldas = dsizes(0)
    dsizes = dimsizes(nldas_lon)
    nlon_nldas = dsizes(0)
    delete(dsizes)

    if (n .eq. 0) then 
      if (var .eq. "prate") then
        ; Create output arrays
        dataOut = new((/18,nlat_nldas,nlon_nldas/),"double")
      else
        dataOut = new((/12,nlat_nldas,nlon_nldas/),"double")
      end if
    end if

    ; Read variable depending on which CFSv2 variable we are working with
    if (var .eq. "2t") then
      param_1 = dfile->T2M_PARAM_1
      param_2 = dfile->T2M_PARAM_2
    else if (var .eq. "u") then
      param_1 = dfile->UGRD10M_PARAM_1
      param_2 = dfile->UGRD10M_PARAM_2
    else if (var .eq. "v") then
      param_1 = dfile->VGRD10M_PARAM_1
      param_2 = dfile->VGRD10M_PARAM_2
    else if (var .eq. "sw") then
      param_1 = dfile->SW_PARAM_1
      param_2 = dfile->SW_PARAM_2
    else if (var .eq. "lw") then
      param_1 = dfile->LW_PARAM_1
      param_2 = dfile->LW_PARAM_2
    else if (var .eq. "pres") then
      param_1 = dfile->PSFC_PARAM_1
      param_2 = dfile->PSFC_PARAM_2
    else if (var .eq. "q") then
      param_1 = dfile->Q2M_PARAM_1
      param_2 = dfile->Q2M_PARAM_2
    else if (var .eq. "prate") then
      param_1 = dfile->PRATE_PARAM_1
      param_2 = dfile->PRATE_PARAM_2
      zero_pcp = dfile->ZERO_PRECIP_PROB
    end if
    end if
    end if
    end if 
    end if
    end if
    end if
    end if

    ; Deal with missing values
    if (var .eq. "sw") then
      param_1 = where(param_1 .gt. 500000 .or. param_1 .eq. 0,3e+20,param_1)
    else
      param_1 = where(param_1 .gt. 500000,3e+20,param_1)
    end if

    param_1@_FillValue = 3e+20
    param_2@_FillValue = 3e+20
    param_2 = where(param_2 .gt. 500000,3e+20,param_2)
    param_1 = where(isnan_ieee(param_1),3e+20,param_1)
    param_2 = where(isnan_ieee(param_2),3e+20,param_2)

    if (var .eq. "prate") then 
      zero_pcp@_FillValue = 3e+20
      zero_pcp = where(zero_pcp .gt. 500000,3e+20,zero_pcp)
      zero_pcp = where(isnan_ieee(zero_pcp),3e+20,zero_pcp) 
    end if

    ; Place data in output array
    dataOut(n,:,:) = param_1
    dataOut((n+6),:,:) = param_2  
    if (var .eq. "prate") then
      dataOut((n+12),:,:) = zero_pcp 
    end if 

    delete(param_1)
    delete(param_2)
    if (var .eq. "prate") then
      delete(zero_pcp)
    end if

  end do

  return(dataOut) 

end

;================================================================
; This function uses nearest neighbor correspondance for the 
; entire nldas grid file (including missing value points),
; run through and place at proper grid points. Everythin else
; is set as missing values, to be later filled with CFSv2 raw
; forecast values without bias-correction.
;================================================================
function nldas_param_cfs_nn(var:string,nlat:integer,nlon:integer, \
                             nldas_param_in[*][*][*]:double, \
                             grid_lat, grid_lon, \
                             sLat[1]:integer,eLat[1]:integer, \
                             sLon[1]:integer,eLon[1]:integer)
local dataOut, y, x, y_ind, x_ind
begin
  ;Establish output arrays
  if (var .eq. "prate") then
    dataOut = new((/18,nlat,nlon/),"double")
  else
    dataOut = new((/12,nlat,nlon/),"double")
  end if
  dataOut = 3e+20
  do y = sLat,eLat
    do x = sLon,eLon
      y_ind = y - sLat 
      x_ind = x - sLon 
 
      dataOut(:,y-1,x-1) = nldas_param_in(:,grid_lat(y_ind,x_ind),\
                           grid_lon(y_ind,x_ind)) 

    end do ; end x (lon) loop
  end do   ; end y (lat) loop

  dataOut@_FillValue = 3e+20
  return(dataOut)
end

;================================================================
; This function takes the grid of CFSv2 data, and performs 
; bias correction using already derived parameter values.
;================================================================
function cfsv2_correct(var:string,nlat:integer,nlon:integer, \
                        nldas_cfs_parm[*][*][*]:double, \
                        cfs_param[*][*][*]:double, \
                        cfs_data[*][*]:float, \
                        cfs_data_prev[*][*]:float,fFlag:integer)
local cfs_adjusted, npcp, bins, vals, x, y, n, t, cfs_param_1_interp, \
      cfs_param_2_interp, cfs_zero_pcp_interp, cfs_interp_forecast, \
      nldas_nearest_1, nldas_nearest_2, nldas_nearest_zero_pcp, \
      cfs_cdf, cfs_cdf_scaled, nldas_cdf, cfs_ind, cfs_cdf_val, \
      cfs_nldas_ind, pcp_pop_diff, randn, new_nldas_ind              
begin
  ;-----------------------------------------------------------
  ; Run through each CFSv2 grid cell and apply correction.
  ;-----------------------------------------------------------

  ;-----------------------------------------------------------
  ; Generate distribution look-up tables for CFSv2 and NLDAS
  ; distributions. Depends on which variable we are dealing 
  ; with.
  ;-----------------------------------------------------------

  ;-----------------------------------------------------------
  ; End product needs to be hourly corrected CFSv2 forecast
  ; data. Original CFSv2 is 6-hourly. We have hourly NLDAS
  ; parameter distributions. So, interpolate the CFSv2 6-hourly
  ; distributions using linear interpolation in time, then apply
  ; the corresponding NLDAS distribution. For the 0-6 hourly
  ; forecast, only interpolate the CFSv2 distributions, not
  ; the actual forecast values as we have none. So the 0-6
  ; hour timeframe will have the same input forecast for each
  ; hour, but different distribution corrections. Then, after
  ; 6 hours lead time, forecast and distributions will vary
  ; hourly via linear interpolation in time. For the actual 
  ; IOC implemenation, there should be a linear time blend betwen
  ; the 0-hour initial analysis and the CFSv2 6-hour CFSv2 forecast.
  ;----------------------------------------------------------

  ; Create output array to hold data.
  cfs_adjusted = new((/6,nlat,nlon/),"double")

  ; Establish contants
  npcp = 2000
  bins = 1000
  if (var .eq. "2t") 
    vals = fspan(200,330,1300)
  else if (var .eq. "u")
    vals = fspan(-50,50,1000)
  else if (var .eq. "v")
    vals = fspan(-50,50,1000)
  else if (var .eq. "sw")
    vals = fspan(0,1300,1000)
  else if (var .eq. "lw")
    vals = fspan(1,800,4000) 
  else if (var .eq. "prate")
    vals = fspan(0.01,100,npcp)
  else if (var .eq. "pres")
    vals = fspan(50000,1100000,3000)
  else if (var .eq. "q")
    vals = fspan(0.01d,40.0d,bins)
  end if
  end if
  end if
  end if
  end if
  end if
  end if
  end if

  ; Generate cdf for range of variables for each distribution so
  ; we can switch between the two. 

  if (var .eq. "prate") then
    spacing = vals(2) - vals(1)
    do x=0, nlon-1
      do y=0, nlat-1
        do n = 0,5 ; Loop through each hour
          t = n + 1

          ; Setup interpolated CFSv2 forecast and distribution values
          cfs_param_1_interp = cfs_param(2,y,x)*tofloat(1-t/6.0) + cfs_param(0,y,x)*tofloat(t/6.0)
          cfs_param_2_interp = cfs_param(3,y,x)*tofloat(1-t/6.0) + cfs_param(1,y,x)*tofloat(t/6.0)
          cfs_zero_pcp_interp = cfs_param(5,y,x)*tofloat(1-t/6.0) + cfs_param(4,y,x)*tofloat(t/6.0)

          ; interpolated CFSv2 forecast data
          if(fFlag .eq. 1) then
            cfs_interp_forecast = cfs_data(y,x)
          else
            cfs_interp_forecast = cfs_data_prev(y,x)*(1-tofloat(t/6.0)) + cfs_data(y,x)*tofloat(t/6.0)
          end if

          if(.not.ismissing(nldas_cfs_parm(n,y,x)) .and. .not.ismissing(nldas_cfs_parm((n+6),y,x))) then
            cfs_cdf = 1 - exp( -((vals/cfs_param_1_interp)^cfs_param_2_interp) )
            cfs_cdf_scaled = ((1-cfs_zero_pcp_interp)+cfs_cdf)/(max(cfs_cdf)+(1-cfs_zero_pcp_interp))
            ;find nearest nldas grid point and then calculate nldas cdf

            nldas_nearest_1 = nldas_cfs_parm(n,y,x)
            nldas_nearest_2 = nldas_cfs_parm((n+6),y,x)
            nldas_nearest_zero_pcp = nldas_cfs_parm((n+12),y,x)
            if(nldas_nearest_1 .eq. 0 .and. nldas_nearest_2 .eq. 0.0 .and. nldas_nearest_zero_pcp .eq. 0.0) then   
              ;if  everything in nldas parameter fit is zero, its invalid, fill with raw cfsv2
              cfs_adjusted(n,y,x) = cfs_interp_forecast
            else  ;valid point, see if we need to adjust cfsv2 precip
              if(nldas_nearest_2 .eq. 0.0) then  ;if second weibul parameter is zero, 
                                                 ;the distribution has no width, no 
                                                 ;precipitation outside first bin
                nldas_cdf = new(npcp,"double",1)
                nldas_nearest_zero_pcp = 1.0
              else
                nldas_cdf = 1 - exp( -((vals/nldas_nearest_1)^nldas_nearest_2) )
              end if
                
              ;compute adjusted value now using the CFSv2 forecast value and the two CDFs
              ;find index in vals array

              cfs_ind = minind(abs(vals-cfs_interp_forecast*3600.0 ) )
              cfs_cdf_val = cfs_cdf(cfs_ind)

              ;now whats the index of the closest cdf value in the nldas array?
              cfs_nldas_ind = minind(abs(cfs_cdf_val-nldas_cdf) )
 
              if(cfs_interp_forecast .eq. 0.0 .or. nldas_nearest_zero_pcp .eq. 1) then  
                ;if no rain in cfsv2, no rain in bias corrected field

                cfs_adjusted(n,y,x) = 0.0

              else  ;else there is rain in cfs forecast, so adjust it in some manner

                pcp_pop_diff = nldas_nearest_zero_pcp - cfs_zero_pcp_interp

                if(cfs_zero_pcp_interp .le. nldas_nearest_zero_pcp) then   
                  ;if cfsv2 zero precip probability is less than nldas, then do one adjustment

                  if(cfs_cdf_val .le. pcp_pop_diff) then   ;if cfsv2 precip cdf is still less 
                                                           ;than pop difference, set precip to zero
                    cfs_adjusted(n,y,x) = 0.0
                  else   ;cfsv2 precip cdf > nldas zero precip probability, 
                    ;so adjust cfsv2 to nldas2 precip
                    cfs_adjusted(n,y,x) = vals(cfs_nldas_ind)/3600.0     
                    ; convert back to mm/s   or kg/m2/s

                    ;check for unreasonable corrections of cfs rainfall
                    ;ad-hoc setting that cfsv2 precipitation should 
                    ;not be corrected by more than 3x
                    ;if it is, this indicated nldas2 distribution is 
                    ;unrealistic and default back to cfsv2 forecast value
                    if(cfs_adjusted(n,y,x)/cfs_interp_forecast .ge. 3.0) then
                      cfs_adjusted(n,y,x) = cfs_interp_forecast
                    end if
                  end if             

                else   ;cfsv2 zero precip prob > nldas zero preicp prob
                  if(cfs_cdf_val .le. abs(pcp_pop_diff)) then     
                    ;if cfsv2 cdf value less than pop difference, need to randomly 
                    ;generate precip, since we're in the zero portion of 
                    ;the nldas zero precip prob still

                    randn = random_uniform(0.0,abs(pcp_pop_diff),1)
                    new_nldas_ind = minind(abs(randn-nldas_cdf))
                    cfs_adjusted(n,y,x) = vals(new_nldas_ind)/3600.0

                    ;check for unreasonable corrections of cfs rainfall
                    ;ad-hoc setting that cfsv2 precipitation should 
                    ;not be corrected by more than 3x
                    ;if it is, this indicated nldas2 distribution is 
                    ;unrealistic and default back to cfsv2 forecast value
                    if(cfs_adjusted(n,y,x)/cfs_interp_forecast .ge. 3.0) then
                      cfs_adjusted(n,y,x) = cfs_interp_forecast
                    end if
                  else  ;if cfsv2 cdf value > nldas zero precip prob, adjust to nldas2
                    cfs_adjusted(n,y,x) = vals(cfs_nldas_ind)/3600.0   
                    ; convert back to mm/s  or kg/m2/s

                    ;check for unreasonable corrections of cfs rainfall
                    ;ad-hoc setting that cfsv2 precipitation should not 
                    ;be corrected by more than 3x
                    ;if it is, this indicated nldas2 distribution is 
                    ;unrealistic and default back to cfsv2 forecast value
                    if(cfs_adjusted(n,y,x)/cfs_interp_forecast .ge. 3.0) then
                      cfs_adjusted(n,y,x) = cfs_interp_forecast
                    end if

                  end if ;end if statement for random generation

                end if  ;end if statement for zero prob comparison

              end if   ;end cfs precip adjustment

            end if ;end if for valid nldas adjustment distribution

          else

            cfs_adjusted(n,y,x) = cfs_interp_forecast

          end if  ;end of missing value bias correction if statement

        end do ; end n (hourly interpolated time) loop

      end do ;end y loop
    end do ;end x loop
  else if (var .eq. "sw") then
    do x=0, nlon-1
      do y=0, nlat-1
        if(.not.ismissing(nldas_cfs_parm(0,y,x))) then
          do n = 0,5 ; Loop through each hour
            t = n + 1

            ; Setup interpolated CFSv2 forecast and distribution values
            cfs_param_1_interp = cfs_param(2,y,x)*tofloat(1-t/6.0) + cfs_param(0,y,x)*tofloat(t/6.0)
            
            ; interpolated CFSv2 forecast data
            if(fFlag .eq. 1) then
              cfs_interp_forecast = cfs_data(y,x)
            else
              cfs_interp_forecast = cfs_data_prev(y,x)*(1-tofloat(t/6.0)) + cfs_data(y,x)*tofloat(t/6.0)
            end if

            nldas_nearest_1 = nldas_cfs_parm(n,y,x)

            if(cfs_interp_forecast .gt. 2.0 .and. cfs_param_1_interp .gt. 2.0) then
              ;if(cfs_interp_forecast .gt. 10.0 .and. nldas_nearest_1 .eq. 0) then
              ;  cfs_adjusted(n,y,x) = cfs_interp_forecast
              ;else
                factor = nldas_nearest_1/cfs_param_1_interp
                cfs_adjusted(n,y,x) = cfs_interp_forecast * factor
              ;end if
            else
              cfs_adjusted(n,y,x) = 0.0d
            end if
 
          end do ; End of hourly NLDAS loop

        else
          do n = 0,5
            t = n + 1

            ; Interpolate CFSv2 forecast data
            if(fFlag .eq. 1) then
              cfs_interp_forecast = cfs_data(y,x)
            else
              cfs_interp_forecast = cfs_data_prev(y,x)*(1-tofloat(t/6.0)) + cfs_data(y,x)*tofloat(t/6.0)
            end if

            cfs_adjusted(n,y,x) = cfs_interp_forecast

          end do ; End of hourly NLDAS loop
        end if ; end of if check for bias correction

      end do ; end y loop
    
    end do ; end x loop

    cfs_adjusted = where(ismissing(cfs_adjusted),0.0,cfs_adjusted)

  else if (var .eq. "q") then
    spacing = vals(2) - vals(1)
    do x=0, nlon-1
      do y=0, nlat-1
        if(.not.ismissing(nldas_cfs_parm(0,y,x))) then
          do n = 0,5 ; Loop through each hour
            t = n + 1

            ; Setup interpolated CFSv2 forecast and distribution values
            cfs_param_1_interp = cfs_param(2,y,x)*tofloat(1-t/6.0) + cfs_param(0,y,x)*tofloat(t/6.0)
            cfs_param_2_interp = cfs_param(3,y,x)*tofloat(1-t/6.0) + cfs_param(1,y,x)*tofloat(t/6.0)
            ; interpolated CFSv2 forecast data
            if(fFlag .eq. 1) then
              cfs_interp_forecast = cfs_data(y,x)
            else
              cfs_interp_forecast = cfs_data_prev(y,x)*(1-tofloat(t/6.0)) + cfs_data(y,x)*tofloat(t/6.0)
            end if
            cfs_interp_forecast = cfs_interp_forecast * 1000.0  ; units are now g/kg

            cfs_cdf = 1 - exp( -((vals/cfs_param_1_interp)^cfs_param_2_interp) )
            
            nldas_nearest_1 = nldas_cfs_parm(n,y,x)
            nldas_nearest_2 = nldas_cfs_parm((n+6),y,x)

            nldas_cdf = 1 - exp( -((vals/nldas_nearest_1)^nldas_nearest_2) )

            ;compute adjusted value now using the CFSv2 forecast value and the two CDFs
            ;find index in vals array

            cfs_ind = minind(abs(vals-cfs_interp_forecast ) )
            cfs_cdf_val = cfs_cdf(cfs_ind)

            ;now whats the index of the closest cdf value in the nldas array?
            cfs_nldas_ind = minind(abs(cfs_cdf_val-nldas_cdf) )
            ;now we have the adjusted cfs variable value

            cfs_adjusted(n,y,x) = vals(cfs_nldas_ind)/1000.0 ; Convert back to kg/kg
 
          end do ; End of hourly NLDAS loop

        else
          do n = 0,5
            t = n + 1

            ; Interpolate CFSv2 forecast data
            if(fFlag .eq. 1) then
              cfs_interp_forecast = cfs_data(y,x)
            else
              cfs_interp_forecast = cfs_data_prev(y,x)*(1-tofloat(t/6.0)) + cfs_data(y,x)*tofloat(t/6.0)
            end if

            cfs_adjusted(n,y,x) = cfs_interp_forecast

          end do ; End of hourly NLDAS loop
        end if ; end of if check for bias correction

      end do ; end y loop

   end do ; end x loop
  else
    do x=0, nlon-1
      do y=0, nlat-1
        if(.not.ismissing(nldas_cfs_parm(0,y,x))) then
          do n = 0,5 ; Loop through each hour
            t = n + 1
            
            ; Setup interpolated CFSv2 forecast and distribution values
            cfs_param_1_interp = cfs_param(2,y,x)*tofloat(1-t/6.0) + cfs_param(0,y,x)*tofloat(t/6.0)
            cfs_param_2_interp = cfs_param(3,y,x)*tofloat(1-t/6.0) + cfs_param(1,y,x)*tofloat(t/6.0)
            ; interpolated CFSv2 forecast data
            if(fFlag .eq. 1) then
              cfs_interp_forecast = cfs_data(y,x)
            else
              cfs_interp_forecast = cfs_data_prev(y,x)*(1-tofloat(t/6.0)) + cfs_data(y,x)*tofloat(t/6.0)
            end if 
          
            pts = (vals-cfs_param_1_interp)/cfs_param_2_interp
            spacing = (vals(2)-vals(1))/cfs_param_2_interp
            cfs_pdf = (exp(-0.5*(pts^2))/sqrt(2*3.141592))*spacing
            cfs_cdf = cumsum(cfs_pdf,2)

            delete(pts)

            nldas_nearest_1 = nldas_cfs_parm(n,y,x)
            nldas_nearest_2 = nldas_cfs_parm((n+6),y,x)

            pts = (vals-nldas_nearest_1)/nldas_nearest_2
            spacing = (vals(2)-vals(1))/nldas_nearest_2
            nldas_pdf = (exp(-0.5*(pts^2))/sqrt(2*3.141592))*spacing
            if (var .eq. "lw") then
              nldas_cdf = cumsum(nldas_pdf,2)
            else if (var .eq. "pres") then
              nldas_cdf = cumsum(nldas_pdf,2)
            else
              nldas_cdf = dim_cumsum(nldas_pdf,2)
            end if
            end if

            ;compute adjusted value now using the CFSv2 forecast value and the two CDFs
            ;find index in vals array

            cfs_ind = minind(abs(vals-cfs_interp_forecast ) )
            cfs_cdf_val = cfs_cdf(cfs_ind)

            ;now whats the index of the closest cdf value in the nldas array?
            cfs_nldas_ind = minind(abs(cfs_cdf_val-nldas_cdf) )
            ;now we have the adjusted cfs variable value

            cfs_adjusted(n,y,x) = vals(cfs_nldas_ind)

          end do ; End of hourly NLDAS loop
        else
          do n = 0,5
            t = n + 1
           
            ; Interpolate CFSv2 forecast data
            if(fFlag .eq. 1) then
              cfs_interp_forecast = cfs_data(y,x)
            else
              cfs_interp_forecast = cfs_data_prev(y,x)*(1-tofloat(t/6.0)) + cfs_data(y,x)*tofloat(t/6.0)
            end if

            cfs_adjusted(n,y,x) = cfs_interp_forecast
 
          end do ; End of hourly NLDAS loop
        end if ; end of if check for bias correction
        
      end do ; end y loop
       
   end do ; end x loop

  end if
  end if
  end if

  ; Set attributes
  if (var .eq. "2t") then
    cfs_adjusted@units = "K"
    cfs_adjusted@long_name = "2-m Air Temperature"
  else if (var .eq. "prate") then
    cfs_adjusted@units = "mm s^-1"
    cfs_adjusted@long_name = "RAINRATE"
  else if (var .eq. "q") then
    cfs_adjusted@units = "kg/kg"
    cfs_adjusted@units = "2-m specific humidity" 
  else if (var .eq. "u") then
    cfs_adjusted@units = "m/s"
    cfs_adjusted@long_name = "10-m U-wind component"
  else if (var .eq. "v") then
    cfs_adjusted@units = "m/s"
    cfs_adjusted@long_name = "10-m V-wind component"
  else if (var .eq. "sw") then
    cfs_adjusted@units = "W/m^2"
    cfs_adjusted@long_name = "Surface downward shortwave radiation"
  else if (var .eq. "lw") then
    cfs_adjusted@units = "W/m^2"
    cfs_adjusted@long_name = "Surface downward longwave radiation"
  else if (var .eq. "pres") then
    cfs_adjusted@units = "Pa"
    cfs_adjusted@long_name = "Surface pressure"
  end if
  end if
  end if
  end if
  end if
  end if
  end if
  end if
 
  cfs_adjusted@_FillValue = 3e+20
  cfs_adjusted@missing_value = 3e+20

  return(cfs_adjusted)

end
