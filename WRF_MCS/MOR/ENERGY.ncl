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

files=addfile("energy.nc","r")

CLOUD_EVAP=files->cloud_evap_total
CLOUD_EVAP=where(CLOUD_EVAP.le.0,CLOUD_EVAP,0)
cloud_evap=dim_sum_n_Wrap(dim_sum_n_Wrap(CLOUD_EVAP,3),2)

RAIN_EVAP=files->rain_evap_total
rain_evap=dim_sum_n_Wrap(dim_sum_n_Wrap(RAIN_EVAP,3),2)

snow=files->snow_melt_total
snow=where(snow.gt.0,0,snow)
snow=where(snow.lt.-20,0,snow)
snow_melt=dim_sum_n_Wrap(dim_sum_n_Wrap(snow,3),2)
print(min(ndtooned(snow)))

graup=files->graup_melt_total
graup=where(graup.gt.0,0,graup)
graup=where(graup.lt.-20,0,graup)
graup_melt=dim_sum_n_Wrap(dim_sum_n_Wrap(graup,3),2)
print(min(ndtooned(graup)))

snow_evap=files->snow_melt_evap_total
snow_evap=where(snow_evap.gt.0,0,snow_evap)
snow_evap=where(snow_evap.lt.-20,0,snow_evap)
snow_melt_evap=dim_sum_n_Wrap(dim_sum_n_Wrap(snow_evap,3),2)
print(min(ndtooned(snow_evap)))

graup_evap=files->graup_melt_evap_total
graup_evap=where(graup_evap.gt.0,0,graup_evap)
graup_evap=where(graup_evap.lt.-20,0,graup_evap)
graup_melt_evap=dim_sum_n_Wrap(dim_sum_n_Wrap(graup_evap,3),2)
print(min(ndtooned(graup_evap)))

total_cloud_evap=dim_sum_n_Wrap(dim_sum_n_Wrap(cloud_evap,1),0)
total_rain_evap=dim_sum_n_Wrap(dim_sum_n_Wrap(rain_evap,1),0)
total_snow_melt=dim_sum_n_Wrap(dim_sum_n_Wrap(snow_melt,1),0)
total_graup_melt=dim_sum_n_Wrap(dim_sum_n_Wrap(graup_melt,1),0)
total_snow_melt_evap=dim_sum_n_Wrap(dim_sum_n_Wrap(snow_melt_evap,1),0)
total_graup_melt_evap=dim_sum_n_Wrap(dim_sum_n_Wrap(graup_melt_evap,1),0)


res                 = True
res@gsnDraw         = False
res@gsnFrame        = False

res@cnFillOn        = True
res@cnLinesOn       = False
res@cnLineLabelsOn  = False
res@cnInfoLabelOn   = False
res@gsnSpreadColors = True
res@gsnMaximize=True
res@vpWidthF=0.60
res@vpHeightF=0.35
res@tmXTOn      = False
res@tmYLFormat  = "f"      ; remove trailing ".0"
;res@cnLevelSelectionMode = "ExplicitLevels"
;res@cnLevels=ispan(1000,9000,1000)

restick           = True
restick@ttmFormat = "%H:%M"   ;"%N/%D %H:%M"
restick@ttmNumTicks=2
restick@ttmMajorStride = 6
time_axis_labels(times,res,restick)
res@tmXBValues=fspan(0,25,5)
delete(res@tmXBMinorValues)
print(res)

resstr=True
resstr@gsnDraw         = False
resstr@gsnFrame        = False
resstr@cnFillOn        = False
resstr@cnLineLabelsOn  = True
resstr@cnInfoLabelOn   = False
;resstr@cnLevelSelectionMode = "ExplicitLevels"
;resstr@cnLevels=ispan(1000,9000,1000)
resstr@cnLineThicknessF=5

res@tiMainString=scheme+"_cloud_evap"
res@gsnLeftString="total: "+total_cloud_evap
wks = gsn_open_wks("eps", "cloud_evap")
plot00=gsn_csm_contour(wks,cloud_evap(level|:,time|:), res)
draw(plot00)
frame(wks)
delete(wks)

res@tiMainString=scheme+"_rain_evap"
res@gsnLeftString="total: "+total_rain_evap
wks = gsn_open_wks("eps", "rain_evap")
plot00=gsn_csm_contour(wks,rain_evap(level|:,time|:), res)
draw(plot00)
frame(wks)
delete(wks)

res@tiMainString=scheme+"_snow_melt"
res@gsnLeftString="total: "+total_snow_melt
wks = gsn_open_wks("eps", "snow_melt")
plot00=gsn_csm_contour(wks,snow_melt(level|:,time|:), res)
draw(plot00)
frame(wks)

res@tiMainString=scheme+"_graup_melt"
res@gsnLeftString="total: "+total_graup_melt
wks = gsn_open_wks("eps", "graup_melt")
plot00=gsn_csm_contour(wks,graup_melt(level|:,time|:), res)
draw(plot00)
frame(wks)

res@tiMainString=scheme+"_snow_melt_evap"
res@gsnLeftString="total: "+total_snow_melt_evap
wks = gsn_open_wks("eps", "snow_melt_evap")
plot00=gsn_csm_contour(wks,snow_melt_evap(level|:,time|:), res)
draw(plot00)
frame(wks)

res@tiMainString=scheme+"_graup_melt_evap"
res@gsnLeftString="total: "+total_graup_melt_evap
wks = gsn_open_wks("eps", "graup_melt_evap")
plot00=gsn_csm_contour(wks,graup_melt_evap(level|:,time|:), res)
draw(plot00)
frame(wks)

