load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/time_axis_labels.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRF_contributed.ncl"
load "$GEODIAG_ROOT/geodiag.ncl"

datafile=addfile("energy_all.nc","r")

MOR_cloud_evap         =  datafile->MOR_cloud_evap
MOR_rain_evap          =  datafile->MOR_rain_evap
MOR_snow_melt          =  datafile->MOR_snow_melt
MOR_graup_melt         =  datafile->MOR_graup_melt
MOR_snow_melt_evap     =  datafile->MOR_snow_melt_evap
MOR_graup_melt_evap    =  datafile->MOR_graup_melt_evap

MORH_cloud_evap        =  datafile->MORH_cloud_evap
MORH_rain_evap         =  datafile->MORH_rain_evap
MORH_snow_melt         =  datafile->MORH_snow_melt
MORH_graup_melt        =  datafile->MORH_graup_melt
MORH_snow_melt_evap    =  datafile->MORH_snow_melt_evap
MORH_graup_melt_evap   =  datafile->MORH_graup_melt_evap

WSM_cloud_evap         =  datafile->WSM_cloud_evap
WSM_rain_evap          =  datafile->WSM_rain_evap
WSM_snow_melt          =  datafile->WSM_snow_melt
WSM_graup_melt         =  datafile->WSM_graup_melt
WSM_praut              =  datafile->WSM_praut
WSM_pracw              =  datafile->WSM_pracw

WDM_cloud_evap         =  datafile->WDM_cloud_evap
WDM_rain_evap          =  datafile->WDM_rain_evap
WDM_snow_melt          =  datafile->WDM_snow_melt
WDM_graup_melt         =  datafile->WDM_graup_melt
WDM_praut              =  datafile->WDM_praut
WDM_pracw              =  datafile->WDM_pracw

WDMH_cloud_evap        =  datafile->WDMH_cloud_evap
WDMH_rain_evap         =  datafile->WDMH_rain_evap
WDMH_snow_melt         =  datafile->WDMH_snow_melt
WDMH_graup_melt        =  datafile->WDMH_graup_melt
WDMH_praut             =  datafile->WDMH_praut
WDMH_pracw             =  datafile->WDMH_pracw

MOR_cloud_evap_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(MOR_cloud_evap,3),2),0)
MORH_cloud_evap_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(MORH_cloud_evap,3),2),0)
WSM_cloud_evap_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(WSM_cloud_evap,3),2),0)
WDM_cloud_evap_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(WDM_cloud_evap,3),2),0)
WDMH_cloud_evap_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(WDMH_cloud_evap,3),2),0)

MOR_rain_evap_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(MOR_rain_evap,3),2),0)
MORH_rain_evap_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(MORH_rain_evap,3),2),0)
WSM_rain_evap_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(WSM_rain_evap,3),2),0)
WDM_rain_evap_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(WDM_rain_evap,3),2),0)
WDMH_rain_evap_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(WDMH_rain_evap,3),2),0)

MOR_snow_melt_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(MOR_snow_melt,3),2),0)
MORH_snow_melt_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(MORH_snow_melt,3),2),0)
WSM_snow_melt_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(WSM_snow_melt,3),2),0)
WDM_snow_melt_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(WDM_snow_melt,3),2),0)
WDMH_snow_melt_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(WDMH_snow_melt,3),2),0)

MOR_graup_melt_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(MOR_graup_melt,3),2),0)
MORH_graup_melt_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(MORH_graup_melt,3),2),0)
WSM_graup_melt_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(WSM_graup_melt,3),2),0)
WDM_graup_melt_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(WDM_graup_melt,3),2),0)
WDMH_graup_melt_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(WDMH_graup_melt,3),2),0)

MOR_snow_melt_evap_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(MOR_snow_melt_evap,3),2),0)
MOR_graup_melt_evap_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(MOR_graup_melt_evap,3),2),0)

MORH_snow_melt_evap_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(MORH_snow_melt_evap,3),2),0)
MORH_graup_melt_evap_avg=dim_avg_n_Wrap(dim_sum_n_Wrap(dim_sum_n_Wrap(MORH_graup_melt_evap,3),2),0)

MOR_cloud_evap_sum=dim_sum_n_Wrap(ndtooned(MOR_cloud_evap),0)
MORH_cloud_evap_sum=dim_sum_n_Wrap(ndtooned(MORH_cloud_evap),0)
WSM_cloud_evap_sum=dim_sum_n_Wrap(ndtooned(WSM_cloud_evap),0)
WDM_cloud_evap_sum=dim_sum_n_Wrap(ndtooned(WDM_cloud_evap),0)
WDMH_cloud_evap_sum=dim_sum_n_Wrap(ndtooned(WDMH_cloud_evap),0)

MOR_rain_evap_sum=dim_sum_n_Wrap(ndtooned(MOR_rain_evap),0)
MORH_rain_evap_sum=dim_sum_n_Wrap(ndtooned(MORH_rain_evap),0)
WSM_rain_evap_sum=dim_sum_n_Wrap(ndtooned(WSM_rain_evap),0)
WDM_rain_evap_sum=dim_sum_n_Wrap(ndtooned(WDM_rain_evap),0)
WDMH_rain_evap_sum=dim_sum_n_Wrap(ndtooned(WDMH_rain_evap),0)

MOR_snow_melt_sum=dim_sum_n_Wrap(ndtooned(MOR_snow_melt),0)
MORH_snow_melt_sum=dim_sum_n_Wrap(ndtooned(MORH_snow_melt),0)
WSM_snow_melt_sum=dim_sum_n_Wrap(ndtooned(WSM_snow_melt),0)
WDM_snow_melt_sum=dim_sum_n_Wrap(ndtooned(WDM_snow_melt),0)
WDMH_snow_melt_sum=dim_sum_n_Wrap(ndtooned(WDMH_snow_melt),0)

MOR_graup_melt_sum=dim_sum_n_Wrap(ndtooned(MOR_graup_melt),0)
MORH_graup_melt_sum=dim_sum_n_Wrap(ndtooned(MORH_graup_melt),0)
WSM_graup_melt_sum=dim_sum_n_Wrap(ndtooned(WSM_graup_melt),0)
WDM_graup_melt_sum=dim_sum_n_Wrap(ndtooned(WDM_graup_melt),0)
WDMH_graup_melt_sum=dim_sum_n_Wrap(ndtooned(WDMH_graup_melt),0)

MOR_snow_melt_evap_sum=dim_sum_n_Wrap(ndtooned(MOR_snow_melt_evap),0)
MOR_graup_melt_evap_sum=dim_sum_n_Wrap(ndtooned(MOR_graup_melt_evap),0)

MORH_snow_melt_evap_sum=dim_sum_n_Wrap(ndtooned(MORH_snow_melt_evap),0)
MORH_graup_melt_evap_sum=dim_sum_n_Wrap(ndtooned(MORH_graup_melt_evap),0)

z=fspan(0.1,18.0,30)
z@units="km"

cloud_evap=new((/5,30/),"float")
cloud_evap(0,:)=MOR_cloud_evap_avg
cloud_evap(1,:)=MORH_cloud_evap_avg
cloud_evap(2,:)=WSM_cloud_evap_avg
cloud_evap(3,:)=WDM_cloud_evap_avg
cloud_evap(4,:)=WDMH_cloud_evap_avg
cloud_evap=cloud_evap*-1.0

rain_evap=new((/5,30/),"float")
rain_evap(0,:)=MOR_rain_evap_avg
rain_evap(1,:)=MORH_rain_evap_avg
rain_evap(2,:)=WSM_rain_evap_avg
rain_evap(3,:)=WDM_rain_evap_avg
rain_evap(4,:)=WDMH_rain_evap_avg
rain_evap=rain_evap*-1.0

snow_melt=new((/5,30/),"float")
snow_melt(0,:)=MOR_snow_melt_avg
snow_melt(1,:)=MORH_snow_melt_avg
snow_melt(2,:)=WSM_snow_melt_avg
snow_melt(3,:)=WDM_snow_melt_avg
snow_melt(4,:)=WDMH_snow_melt_avg
snow_melt=snow_melt*-1.0

graup_melt=new((/5,30/),"float")
graup_melt(0,:)=MOR_graup_melt_avg
graup_melt(1,:)=MORH_graup_melt_avg
graup_melt(2,:)=WSM_graup_melt_avg
graup_melt(3,:)=WDM_graup_melt_avg
graup_melt(4,:)=WDMH_graup_melt_avg
graup_melt=graup_melt*-1.0

melt_evap=new((/4,30/),"float")
melt_evap(0,:)=MOR_snow_melt_evap_avg
melt_evap(1,:)=MORH_snow_melt_evap_avg
melt_evap(2,:)=MOR_graup_melt_evap_avg
melt_evap(3,:)=MORH_graup_melt_evap_avg
melt_evap=melt_evap*-1.0

res=True
res@gsnFrame           = False 
res@vpHeightF          = 0.35
res@vpWidthF           = 0.20
res@tiMainFontHeightF  = 0.018
res@tiXAxisFontHeightF = 0.018
res@tiYAxisFontHeightF = 0.018
res@xyLineThicknessF   = 2.0
res@xyLineColors=(/"red","black","orange","blue","green"/) 
res@xyExplicitLegendLabels = (/"MOR","MOR_H","WSM6","WDM6","WDM6H"/)
res@tiYAxisString="km"
res@tiXAxisString="J/kg"

res_cloud_evap=res
res_rain_evap=res
res_snow_melt=res
res_graup_melt=res
res_melt_evap=res
delete(res_melt_evap@xyLineColors)
delete(res_melt_evap@xyExplicitLegendLabels)
res_melt_evap@xyLineColors=(/"red","orange","blue","green"/)
res_melt_evap@xyExplicitLegendLabels = (/"MOR_SNOW_EVAP","MOR_H_SNOW_EVAP","MOR_GRAUP_EVAP","MOR_H_GRAUP_EVAP"/)

wks=gsn_open_wks("eps" ,"micro_energy_budget")
gsn_define_colormap(wks,"ncl_default")

res_cloud_evap@vpXF              = 0.1 
res_cloud_evap@vpYF              = 0.93
res_cloud_evap@tiMainString      = "Cloud Evaporation"
res_cloud_evap@pmLegendWidthF               = 0.05       
res_cloud_evap@pmLegendHeightF              = 0.1               
res_cloud_evap@lgLabelFontHeightF           = .01                 
res_cloud_evap@pmLegendSide                 = "Top"
res_cloud_evap@pmLegendParallelPosF         = .70  
res_cloud_evap@pmLegendOrthogonalPosF       = -0.5
res_cloud_evap@pmLegendDisplayMode          = "Always"
plot=gsn_csm_xy(wks,cloud_evap,z,res_cloud_evap)

res_rain_evap@vpXF              = 0.4
res_rain_evap@vpYF              = 0.93
res_rain_evap@tiMainString      = "Rain Evaporation"
plot=gsn_csm_xy(wks,rain_evap,z,res_rain_evap)

res_snow_melt@vpXF              = 0.7
res_snow_melt@vpYF              = 0.93
res_snow_melt@tiMainString      = "Snow Melting"
plot=gsn_csm_xy(wks,snow_melt,z,res_snow_melt)

res_graup_melt@vpXF              = 0.1
res_graup_melt@vpYF              = 0.45
res_graup_melt@tiMainString      = "Graupel/Hail Melting"
plot=gsn_csm_xy(wks,graup_melt,z,res_graup_melt)

res_melt_evap@vpXF              = 0.4
res_melt_evap@vpYF              = 0.45
res_melt_evap@tiMainString      = "Evaporation after melting"
res_melt_evap@pmLegendWidthF               = 0.05
res_melt_evap@pmLegendHeightF              = 0.1
res_melt_evap@lgLabelFontHeightF           = .008
res_melt_evap@pmLegendSide                 = "Top"
res_melt_evap@pmLegendParallelPosF         = 0.50
res_melt_evap@pmLegendOrthogonalPosF       = -0.5
res_melt_evap@pmLegendDisplayMode          = "Always"
plot=gsn_csm_xy(wks,melt_evap,z,res_melt_evap)

gsn_define_colormap(wks,"circular_2")   ;"ncl_default")
xx=fspan(0.5,23.5,24)
yy=(/WDM_rain_evap_sum,      WDMH_graup_melt_sum,    WSM_rain_evap_sum,  WDMH_rain_evap_sum,  \
     WDM_graup_melt_sum,     MOR_rain_evap_sum,      WSM_graup_melt_sum, MORH_rain_evap_sum,  \
     WSM_cloud_evap_sum,     WDM_cloud_evap_sum,     WDMH_cloud_evap_sum,MOR_cloud_evap_sum,  \
     MORH_cloud_evap_sum,    WSM_snow_melt_sum,      WDM_snow_melt_sum,  MOR_graup_melt_sum,  \
     MOR_snow_melt_evap_sum, MOR_graup_melt_evap_sum,MORH_snow_melt_sum, WDMH_snow_melt_sum,  \
     MORH_snow_melt_evap_sum,MOR_snow_melt_sum,      MORH_graup_melt_sum,MORH_graup_melt_evap_sum/)
yy=yy*-1/1e5
names=(/"WDM_rain_evap",      "WDMH_hail_melt",     "WSM_rain_evap",  "WDMH_rain_evap",  \
        "WDM_graup_melt",     "MOR_rain_evap",      "WSM_graup_melt", "MORH_rain_evap",  \
        "WSM_cloud_evap",     "WDM_cloud_evap",     "WDMH_cloud_evap","MOR_cloud_evap",  \
        "MORH_cloud_evap",    "WSM_snow_melt",      "WDM_snow_melt",  "MOR_graup_melt",  \
        "MOR_snow_melt_evap", "MOR_graup_melt_evap","MORH_snow_melt", "WDMH_snow_melt",  \
        "MORH_snow_melt_evap","MOR_snow_melt",      "MORH_hail_melt", "MORH_hail_melt_evap"/)
resbar                       = True         
resbar@vpHeightF          = 0.35
resbar@vpWidthF           = 0.20
resbar@vpXF              = 0.7
resbar@vpYF              = 0.45
resbar@gsnFrame              = False        
resbar@gsnXYBarChart         = True         
resbar@gsnXYBarChartBarWidth = 1          
resbar@gsnXYBarChartColors=ispan(2,25,1)
resbar@tmXBOn                = False        
resbar@trYMinF               = 0            
resbar@trXMinF               = 0            
resbar@trXMaxF               = 24
resbar@tiYAxisString="J/kg"
resbar@tiXAxisString="scale facor: 1e5"
resbar@tiMainFontHeightF  = 0.018
resbar@tiYAxisFontHeightF = 0.018
resbar@tiXAxisFontHeightF = 0.018
resbar@tiMainString          = "Total"
resbar@tmXBLabelsOn=True
resbar@tmXBValues =xx
resbar@tmXBLabels=names
plot = gsn_csm_xy (wks,xx,yy,resbar)
nboxes = dimsizes(resbar@gsnXYBarChartColors)
lbres                    = True        
lbres@lbBoxMajorExtentF  = 0.3     
lbres@lbFillColors       = ispan(25,2,1)
lbres@lbMonoFillPattern  = True         
lbres@lbLabelFontHeightF = 0.004       
lbres@lbLabelJust        = "CenterLeft" 
lbres@lbPerimOn=False
lbres@lbBoxMajorExtentF  = 0.8
lbres@vpWidthF           = 0.1    
lbres@vpHeightF          = 0.27    
lbres@lbBoxLinesOn=False
gsn_labelbar_ndc(wks,nboxes,names(::-1),0.79,0.45,lbres)
print(yy)
print(names)

