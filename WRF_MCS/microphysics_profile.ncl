load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/time_axis_labels.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRF_contributed.ncl"
load "$GEODIAG_ROOT/geodiag.ncl"

datafile=addfile("microphysics.nc","r")

MOR_qvapor_total=datafile->MOR_qvapor_total
MOR_qcloud_total=datafile->MOR_qcloud_total
MOR_qice_total=datafile->MOR_qice_total
MOR_qsnow_total=datafile->MOR_qsnow_total
MOR_qgraup_total=datafile->MOR_qgraup_total
MOR_qnice_total=datafile->MOR_qnice_total
MOR_qnsnow_total=datafile->MOR_qnsnow_total
MOR_qnrain_total=datafile->MOR_qnrain_total
MOR_qngraup_total=datafile->MOR_qngraup_total
MOR_qrain_total=datafile->MOR_qrain_total

MOR_H_qrain_total=datafile->MOR_H_qrain_total
MOR_H_qvapor_total=datafile->MOR_H_qvapor_total
MOR_H_qcloud_total=datafile->MOR_H_qcloud_total
MOR_H_qice_total=datafile->MOR_H_qice_total
MOR_H_qsnow_total=datafile->MOR_H_qsnow_total
MOR_H_qgraup_total=datafile->MOR_H_qgraup_total
MOR_H_qnice_total=datafile->MOR_H_qnice_total
MOR_H_qnsnow_total=datafile->MOR_H_qnsnow_total
MOR_H_qnrain_total=datafile->MOR_H_qnrain_total
MOR_H_qngraup_total=datafile->MOR_H_qngraup_total

WDM_qrain_total=datafile->WDM_qrain_total
WDM_qvapor_total=datafile->WDM_qvapor_total
WDM_qcloud_total=datafile->WDM_qcloud_total
WDM_qice_total=datafile->WDM_qice_total
WDM_qsnow_total=datafile->WDM_qsnow_total
WDM_qgraup_total=datafile->WDM_qgraup_total
WDM_qncloud_total=datafile->WDM_qncloud_total
WDM_qnrain_total=datafile->WDM_qnrain_total

WDM_H_qrain_total=datafile->WDM_H_qrain_total
WDM_H_qvapor_total=datafile->WDM_H_qvapor_total
WDM_H_qcloud_total=datafile->WDM_H_qcloud_total
WDM_H_qice_total=datafile->WDM_H_qice_total
WDM_H_qsnow_total=datafile->WDM_H_qsnow_total
WDM_H_qgraup_total=datafile->WDM_H_qgraup_total
WDM_H_qncloud_total=datafile->WDM_H_qncloud_total
WDM_H_qnrain_total=datafile->WDM_H_qnrain_total

WSM_qrain_total=datafile->WSM_qrain_total
WSM_qvapor_total=datafile->WSM_qvapor_total
WSM_qcloud_total=datafile->WSM_qcloud_total
WSM_qice_total=datafile->WSM_qice_total
WSM_qsnow_total=datafile->WSM_qsnow_total
WSM_qgraup_total=datafile->WSM_qgraup_total
WSM_qncloud_total=datafile->WSM_qncloud_total
WSM_qnrain_total=datafile->WSM_qnrain_total

MOR_qrain_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_qrain_total,3),2),0)
MOR_qvapor_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_qvapor_total,3),2),0)
MOR_qcloud_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_qcloud_total,3),2),0)
MOR_qice_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_qice_total,3),2),0)
MOR_qsnow_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_qsnow_total,3),2),0)
MOR_qgraup_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_qgraup_total,3),2),0)
MOR_qnice_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_qnice_total,3),2),0)
MOR_qnsnow_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_qnsnow_total,3),2),0)
MOR_qnrain_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_qnrain_total,3),2),0)
MOR_qngraup_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_qngraup_total,3),2),0)

MOR_H_qrain_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_H_qrain_total,3),2),0)
MOR_H_qvapor_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_H_qvapor_total,3),2),0)
MOR_H_qcloud_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_H_qcloud_total,3),2),0)
MOR_H_qice_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_H_qice_total,3),2),0)
MOR_H_qsnow_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_H_qsnow_total,3),2),0)
MOR_H_qgraup_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_H_qgraup_total,3),2),0)
MOR_H_qnice_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_H_qnice_total,3),2),0)
MOR_H_qnsnow_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_H_qnsnow_total,3),2),0)
MOR_H_qnrain_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_H_qnrain_total,3),2),0)
MOR_H_qngraup_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(MOR_H_qngraup_total,3),2),0)

WDM_qrain_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_qrain_total,3),2),0)
WDM_qvapor_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_qvapor_total,3),2),0)
WDM_qcloud_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_qcloud_total,3),2),0)
WDM_qice_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_qice_total,3),2),0)
WDM_qsnow_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_qsnow_total,3),2),0)
WDM_qgraup_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_qgraup_total,3),2),0)
WDM_qncloud_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_qncloud_total,3),2),0)
WDM_qnrain_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_qnrain_total,3),2),0)

WDM_H_qrain_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_H_qrain_total,3),2),0)
WDM_H_qvapor_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_H_qvapor_total,3),2),0)
WDM_H_qcloud_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_H_qcloud_total,3),2),0)
WDM_H_qice_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_H_qice_total,3),2),0)
WDM_H_qsnow_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_H_qsnow_total,3),2),0)
WDM_H_qgraup_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_H_qgraup_total,3),2),0)
WDM_H_qncloud_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_H_qncloud_total,3),2),0)
WDM_H_qnrain_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_H_qnrain_total,3),2),0)

WSM_qrain_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WSM_qrain_total,3),2),0)
WSM_qvapor_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WSM_qvapor_total,3),2),0)
WSM_qcloud_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WSM_qcloud_total,3),2),0)
WSM_qice_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WSM_qice_total,3),2),0)
WSM_qsnow_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WSM_qsnow_total,3),2),0)
WSM_qgraup_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WSM_qgraup_total,3),2),0)
WSM_qncloud_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WSM_qncloud_total,3),2),0)
WSM_qnrain_ave=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WSM_qnrain_total,3),2),0)

z=fspan(0.1,18.0,30)
z@units="km"

cloud=new((/5,30/),"float")
cloud(0,:)=MOR_qcloud_ave
cloud(1,:)=MOR_H_qcloud_ave
cloud(2,:)=WDM_qcloud_ave
cloud(3,:)=WDM_H_qcloud_ave
cloud(4,:)=WSM_qcloud_ave
cloud=cloud*1e6

rain=new((/5,30/),"float")
rain(0,:)=MOR_qrain_ave
rain(1,:)=MOR_H_qrain_ave
rain(2,:)=WDM_qrain_ave
rain(3,:)=WDM_H_qrain_ave
rain(4,:)=WSM_qrain_ave
rain=rain*1e6

ice=new((/5,30/),"float")
ice(0,:)=MOR_qice_ave
ice(1,:)=MOR_H_qice_ave
ice(2,:)=WDM_qice_ave
ice(3,:)=WDM_H_qice_ave
ice(4,:)=WSM_qice_ave
ice=ice*1e6

snow=new((/5,30/),"float")
snow(0,:)=MOR_qsnow_ave
snow(1,:)=MOR_H_qsnow_ave
snow(2,:)=WDM_qsnow_ave
snow(3,:)=WDM_H_qsnow_ave
snow(4,:)=WSM_qsnow_ave
snow=snow*1e6

graup=new((/5,30/),"float")
graup(0,:)=MOR_qgraup_ave
graup(1,:)=MOR_H_qgraup_ave
graup(2,:)=WDM_qgraup_ave
graup(3,:)=WDM_H_qgraup_ave
graup(4,:)=WSM_qgraup_ave
graup=graup*1e6

vapor=new((/5,30/),"float")
vapor(0,:)=MOR_qvapor_ave
vapor(1,:)=MOR_H_qvapor_ave
vapor(2,:)=WDM_qvapor_ave
vapor(3,:)=WDM_H_qvapor_ave
vapor(4,:)=WSM_qvapor_ave
vapor=vapor*1e6

mornumber=new((/8,30/),"float")
mornumber(0,:)=MOR_qnrain_ave
mornumber(1,:)=MOR_qnsnow_ave
mornumber(2,:)=0 ;MOR_qnice_ave
mornumber(3,:)=MOR_qngraup_ave
mornumber(4,:)=MOR_H_qnrain_ave
mornumber(5,:)=MOR_H_qnsnow_ave
mornumber(6,:)=0 ;MOR_H_qnice_ave
mornumber(7,:)=MOR_H_qngraup_ave

wdmnumber=new((/6,30/),"float")
wdmnumber(0,:)=WDM_qncloud_ave
wdmnumber(1,:)=WDM_qnrain_ave
wdmnumber(2,:)=WDM_H_qncloud_ave
wdmnumber(3,:)=WDM_H_qnrain_ave
wdmnumber(4,:)=WSM_qncloud_ave
wdmnumber(5,:)=WSM_qnrain_ave

res=True
res@gsnFrame           = False 
res@vpHeightF          = 0.35
res@vpWidthF           = 0.20
res@tiMainFontHeightF  = 0.018
res@tiXAxisFontHeightF = 0.018
res@tiYAxisFontHeightF = 0.018
res@xyLineThicknessF   = 2.0
res@xyLineColors=(/"red","black","orange","blue","green"/) 
res@xyExplicitLegendLabels = (/"MOR","MOR_H","WDM6","WDM6_H","WSM6"/)
res@tiYAxisString="km"

res_cloud=res
res_rain=res
res_snow=res
res_graup=res
res_ice=res
res_vapor=res
res_mornumber=res
res_wdmnumber=res

wks=gsn_open_wks("eps" ,"micro_profile")
gsn_define_colormap(wks,"ncl_default")

res_cloud@vpXF              = 0.1
res_cloud@vpYF              = 0.93
res_cloud@tiMainString      = "Cloud Mass"
res_cloud@pmLegendWidthF               = 0.05       
res_cloud@pmLegendHeightF              = 0.1               
res_cloud@lgLabelFontHeightF           = .01                 
res_cloud@pmLegendSide                 = "Top"
res_cloud@pmLegendParallelPosF         = .70  
res_cloud@pmLegendOrthogonalPosF       = -0.5
res_cloud@pmLegendDisplayMode          = "Always"
plot=gsn_csm_xy(wks,cloud,z,res_cloud)

res_rain@vpXF              = 0.4
res_rain@vpYF              = 0.93
res_rain@tiMainString      = "Rain Mass"
delete(res_rain@tiYAxisString)
plot=gsn_csm_xy(wks,rain,z,res_rain)

res_ice@vpXF              = 0.7
res_ice@vpYF              = 0.93
res_ice@tiMainString      = "Ice Mass"
delete(res_ice@tiYAxisString)
plot=gsn_csm_xy(wks,ice,z,res_ice)

res_snow@vpXF              = 0.1
res_snow@vpYF              = 0.45
res_snow@tiMainString      = "Snow Mass"
plot=gsn_csm_xy(wks,snow,z,res_snow)

res_graup@vpXF              = 0.4
res_graup@vpYF              = 0.45
res_graup@tiMainString      = "Graupel/Hail Mass"
delete(res_graup@tiYAxisString)
plot=gsn_csm_xy(wks,graup,z,res_graup)

res_vapor@vpXF              = 0.7
res_vapor@vpYF              = 0.45
res_vapor@tiMainString      = "Vapor Mass"
delete(res_vapor@tiYAxisString)
plot=gsn_csm_xy(wks,vapor,z,res_vapor)

