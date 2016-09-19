load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/time_axis_labels.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRF_contributed.ncl"
load "$GEODIAG_ROOT/geodiag.ncl"

scheme="Mor"
thick=5

filelist=systemfunc("ls ./wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist, "r")
times  = wrf_times_c(wrffiles[96:120]->Times,0)

files=addfile("RDSD.nc","r")
n0_total=files->n0_total
lamb_total=files->lamb_total

n0_ave=dim_avg_n_Wrap(ndtooned(n0_total),0)
lamb_ave=dim_avg_n_Wrap(ndtooned(lamb_total),0)

print(n0_ave)
print(lamb_ave)

rain_size=(/0.062,0.187,0.312,0.437,0.562,0.687,0.812,0.937,1.062,1.187,1.375,1.625,1.875,2.125,2.375,2.750,3.250,3.750,4.250,4.750,5.500,6.500,7.500,8.500,9.500,11.000,13.000,15.000,17.000,19.000,21.500,24.500/)

nr=n0_ave*2.718^(-lamb_ave*rain_size/1000.0)
print(nr)
res=True
res@xyYStyle="Log"
res@xyMarkLineModes   = "Markers"
res@gsnMaximize=True
res@vpWidthF=0.45
res@vpHeightF=0.60 


wks = gsn_open_wks ("pdf","xy")   
plot = gsn_csm_xy(wks,rain_size,nr,res) 

