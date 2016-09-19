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

cloud=files->cloud_evap_total
cloud=where(cloud.le.0,cloud,0)
cloud=where(cloud.lt.-10,0,cloud)
cloud_evap=dim_sum_n_Wrap(dim_sum_n_Wrap(cloud,3),2)
print(min(ndtooned(cloud)))

RAIN_EVAP=files->rain_evap_total
RAIN_EVAP=where(RAIN_EVAP.ge.0,0,RAIN_EVAP)
rain_evap=dim_sum_n_Wrap(dim_sum_n_Wrap(RAIN_EVAP,3),2)

snow=files->snow_melt_total
snow=where(snow.gt.0,0,snow)
snow=where(snow.lt.-10,0,snow)
snow_melt=dim_sum_n_Wrap(dim_sum_n_Wrap(snow,3),2)
print(min(ndtooned(snow)))

graup=files->graup_melt_total
graup=where(graup.gt.0,0,graup)
graup=where(graup.lt.-10,0,graup)
graup_melt=dim_sum_n_Wrap(dim_sum_n_Wrap(graup,3),2)
print(min(ndtooned(graup)))

PRAUT=files->praut
praut=dim_avg_n_Wrap(dim_avg_n_Wrap(PRAUT,3),2)*1e10
copy_VarMeta(graup_melt,praut)

PRACW=files->pracw
pracw=dim_avg_n_Wrap(dim_avg_n_Wrap(PRACW,3),2)*1e10
copy_VarMeta(graup_melt,pracw)

total_cloud_evap=dim_sum_n_Wrap(dim_sum_n_Wrap(cloud_evap,1),0)
total_rain_evap=dim_sum_n_Wrap(dim_sum_n_Wrap(rain_evap,1),0)
total_snow_melt=dim_sum_n_Wrap(dim_sum_n_Wrap(snow_melt,1),0)
total_graup_melt=dim_sum_n_Wrap(dim_sum_n_Wrap(graup_melt,1),0)

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
print(total_rain_evap)

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

res@tiMainString=scheme+"_praut"
res@gsnLeftString=""
wks = gsn_open_wks("eps", "praut")
plot00=gsn_csm_contour(wks,praut(level|:,time|:), res)
draw(plot00)
frame(wks)

res@tiMainString=scheme+"_pracw"
res@gsnLeftString=""
wks = gsn_open_wks("eps", "pracw")
plot00=gsn_csm_contour(wks,pracw(level|:,time|:), res)
draw(plot00)
frame(wks)

