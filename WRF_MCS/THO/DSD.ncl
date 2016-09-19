load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"

rain_size=(/0.062,0.187,0.312,0.437,0.562,0.687,0.812,0.937,1.062,1.187,1.375,1.625,1.875,2.125,2.375,2.750,3.250,3.750,4.250,4.750,5.500,6.500,7.500,8.500,9.500,11.000,13.000,15.000,17.000,19.000,21.500,24.500/)

wrffile=addfile("./wrfout/wrfout_d03_2014-05-22_06:00:00","r")
dsdfile=addfile("rainDSD.nc","r")

N0r=dsdfile->N0r
lamr=dsdfile->lamr

lattmp = wrf_user_getvar(wrffile,"XLAT",0)
lontmp = wrf_user_getvar(wrffile,"XLONG",0)

n0=rcm2points_Wrap(lattmp,lontmp,N0r,22.06666667,111.95,2)
lam=rcm2points_Wrap(lattmp,lontmp,N0r,22.06666667,111.95,2)
print(n0)
print(lam)
;res=True
;res@xyYStyle="Log"
;res@xyMarkLineModes   = "Markers"
;res@gsnMaximize=True
;res@vpWidthF=0.45
;res@vpHeightF=0.60 
;
;
;wks = gsn_open_wks ("pdf","xy")   
;plot = gsn_csm_xy(wks,rain_size,datasum,res) 
;
