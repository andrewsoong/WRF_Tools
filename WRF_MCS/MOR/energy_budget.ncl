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

cloud_evap_conv=dim_sum_n_Wrap(dim_sum_n_Wrap(files->cloud_evap_conv,3),2)
cloud_evap_trail=dim_sum_n_Wrap(dim_sum_n_Wrap(files->cloud_evap_trail,3),2)

rain_evap_conv=dim_sum_n_Wrap(dim_sum_n_Wrap(files->rain_evap_conv,3),2)
rain_evap_trail=dim_sum_n_Wrap(dim_sum_n_Wrap(files->rain_evap_trail,3),2)

snow=files->snow_melt_conv
snow=where(snow.gt.0,0,snow)
snow=where(snow.lt.-100,0,snow)
snow_melt_conv=dim_sum_n_Wrap(dim_sum_n_Wrap(snow,3),2)
print(min(ndtooned(snow_melt_conv)))
;snow_melt_trail=dim_sum_n_Wrap(dim_sum_n_Wrap(snow_melt_trail,3),2)

total_cloud_conv=dim_sum_n_Wrap(dim_sum_n_Wrap(cloud_evap_conv,1),0)
total_cloud_trail=dim_sum_n_Wrap(dim_sum_n_Wrap(cloud_evap_trail,1),0)
total_cloud=total_cloud_conv+total_cloud_trail

total_rain_conv=dim_sum_n_Wrap(dim_sum_n_Wrap(rain_evap_conv,1),0)
total_rain_trail=dim_sum_n_Wrap(dim_sum_n_Wrap(rain_evap_trail,1),0)
total_rain=total_rain_conv+total_rain_trail

total_snowmlt_conv=dim_sum_n_Wrap(dim_sum_n_Wrap(snow_melt_conv,1),0)
total_snowmlt_trail=dim_sum_n_Wrap(dim_sum_n_Wrap(snow_melt_trail,1),0)
total_snowmlt=total_snowmlt_conv+total_snowmlt_trail


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
res@tiMainString=scheme
res@cnLevelSelectionMode = "ExplicitLevels"
res@cnLevels=ispan(1000,9000,1000)
res@gsnLeftString="conv: "+total_cloud_conv
res@gsnRightString="trail: "+total_cloud_trail

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

wks = gsn_open_wks("eps", "cloud_evap")
gsn_define_colormap(wks,"MPL_Blues")
plot00=gsn_csm_contour(wks,cloud_evap_conv(level|:,time|:), res)
draw(plot00)
frame(wks)
delete(wks)

wks = gsn_open_wks("eps", "rain_evap")
delete(res@cnLevelSelectionMode)
delete(res@cnLevels)
res@gsnLeftString="conv: "+total_rain_conv
res@gsnRightString="trail: "+total_rain_trail
plot00=gsn_csm_contour(wks,rain_evap_conv(level|:,time|:), res)
draw(plot00)
frame(wks)
delete(wks)

wks = gsn_open_wks("eps", "snow_melt")
delete(res@cnLevelSelectionMode)
delete(res@cnLevels)
res@gsnLeftString="conv: "+total_snowmlt_conv
res@gsnRightString="trail: "+total_snowmlt_trail
print(min(ndtooned(snow_melt_conv)))
plot00=gsn_csm_contour(wks,snow_melt_conv(level|:,time|:), res)
draw(plot00)
frame(wks)



