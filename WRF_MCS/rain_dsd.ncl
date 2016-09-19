load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"

datasum1 = asciiread("bada_all_data_tmp",32,"float")
datasum1@missing_value=999999.000000
datasum1@_FillValue=999999.000000

datasum2 = asciiread("hecheng_all_data_tmp",32,"float")
datasum2@missing_value=999999.000000
datasum2@_FillValue=999999.000000

datasum3 = asciiread("chengcun_all_data_tmp",32,"float")
datasum3@missing_value=999999.000000
datasum3@_FillValue=999999.000000

datasum4 = asciiread("shuangjie_all_data_tmp",32,"float")
datasum4@missing_value=999999.000000
datasum4@_FillValue=999999.000000

datasum=(datasum1+datasum2+datasum3+datasum4)/4.0*1000


rain_size=(/0.062,0.187,0.312,0.437,0.562,0.687,0.812,0.937,1.062,1.187,1.375,1.625,1.875,2.125,2.375,2.750,3.250,3.750,4.250,4.750,5.500,6.500,7.500,8.500,9.500,11.000,13.000,15.000,17.000,19.000,21.500,24.500/)

datafile=addfile("RDSD.nc","r")

;MOR
mor_n0s=datafile->MOR_n0_total
mor_lams=datafile->MOR_lamb_total
mor_n0=dim_avg_n_Wrap(ndtooned(mor_n0s),0)
mor_lam=dim_avg_n_Wrap(ndtooned(mor_lams),0)
mor_nr=1.29*mor_n0*2.718^(-mor_lam*rain_size/1000.0)

;MOR_H
mor_h_n0s=datafile->MOR_H_n0_total
mor_h_lams=datafile->MOR_H_lamb_total
mor_h_n0=dim_avg_n_Wrap(ndtooned(mor_h_n0s),0)
mor_h_lam=dim_avg_n_Wrap(ndtooned(mor_h_lams),0)
mor_h_nr=1.29*mor_h_n0*2.718^(-mor_h_lam*rain_size/1000.0)

;WDM
wdm_n0s=datafile->WDM_n0_total
wdm_lams=datafile->WDM_lamb_total
wdm_n0=dim_avg_n_Wrap(ndtooned(wdm_n0s),0)
wdm_lam=dim_avg_n_Wrap(ndtooned(wdm_lams),0)
wdm_nr=8.0*1e6*wdm_lam*rain_size/1000.0*2.718^(-wdm_lam*rain_size/1000.0)

;WDM_H
wdm_h_n0s=datafile->WDMH_n0_total
wdm_h_lams=datafile->WDMH_lamb_total
wdm_h_n0=dim_avg_n_Wrap(ndtooned(wdm_h_n0s),0)
wdm_h_lam=dim_avg_n_Wrap(ndtooned(wdm_h_lams),0)
wdm_h_nr=8.0*1e6*wdm_h_lam*rain_size/1000.0*2.718^(-wdm_h_lam*rain_size/1000.0)

;WSM
wsm_n0s=datafile->WSM_n0_total
wsm_lams=datafile->WSM_lamb_total
wsm_n0=dim_avg_n_Wrap(ndtooned(wsm_n0s),0)
wsm_lam=dim_avg_n_Wrap(ndtooned(wsm_lams),0)
wsm_nr=8.0*1e6*2.718^(-wsm_lam*rain_size/1000.0)

model_dsd=new((/6,32/),"float")
model_dsd(0,:)=mor_nr
model_dsd(1,:)=mor_h_nr
model_dsd(2,:)=wdm_nr
model_dsd(3,:)=wdm_h_nr
model_dsd(4,:)=wsm_nr
model_dsd(5,:)=datasum

res=True
res@gsnFrame           = False
res@vpHeightF          = 0.7
res@vpWidthF           = 0.35
res@tiMainFontHeightF  = 0.018
res@tiXAxisFontHeightF = 0.018
res@tiYAxisFontHeightF = 0.018
res@xyLineThicknessF   = 2.0
res@xyLineColors=(/"red","black","orange","blue","green","purple"/)
res@xyMarkLineModes=(/"Lines","Lines","Lines","Lines","Lines","Markers"/)
res@xyExplicitLegendLabels = (/"MOR","MOR_H","WDM6","WDM6_H","WSM6","OBS"/)
res@tiXAxisString="Size: mm"
res@tiYAxisString="N(D): m~S~-4"
res@xyYStyle="Log"
res@xyMarkerSizeF=0.01
res@vpXF              = 0.13
res@vpYF              = 0.85
res@tiMainString      = "Rain Distribution"
res@pmLegendWidthF               = 0.1
res@pmLegendHeightF              = 0.2
res@lgLabelFontHeightF           = .015
res@pmLegendSide                 = "Top"
res@pmLegendParallelPosF         = .23
res@pmLegendOrthogonalPosF       = -1.05
res@pmLegendDisplayMode          = "Always"
res@trXMaxF               = 7.500
res@lbPerimOn=False

wks=gsn_open_wks("eps" ,"rain_size_distribution")
gsn_define_colormap(wks,"ncl_default")
plot=gsn_csm_xy(wks,rain_size(0:22),model_dsd(:,0:22),res)



datafiless=addfile("energy_all.nc","r")
WSM_pracw=datafiless->WSM_pracw
WDM_praut=datafiless->WDM_praut
WDM_pracw=datafiless->WDM_pracw
WDMH_praut=datafiless->WDMH_praut
WDMH_pracw=datafiless->WDMH_pracw
WSM_praut=datafiless->WSM_praut
model_micro=new((/6,30/),"float")
model_micro(0,:)=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_praut,3),2),0)
model_micro(1,:)=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WSM_praut,3),2),0)
model_micro(2,:)=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDMH_praut,3),2),0)
model_micro(3,:)=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDM_pracw,3),2),0)
model_micro(4,:)=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WSM_pracw,3),2),0)
model_micro(5,:)=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(WDMH_pracw,3),2),0)
model_micro=model_micro*1e8
z=fspan(0.1,18.0,30)
z@units="km"

resss=True
resss@gsnFrame           = False
resss@vpHeightF          = 0.7
resss@vpWidthF           = 0.35
resss@tiMainFontHeightF  = 0.018
resss@tiXAxisFontHeightF = 0.018
resss@tiYAxisFontHeightF = 0.018
resss@xyLineThicknessF   = 2.0
resss@xyLineColors=(/"red","black","orange","blue","green","purple"/)
resss@xyExplicitLegendLabels = (/"WDM_praut","WSM_praut","WDM_H_praut","WDM_pracw","WSM_pracw","WDM_H_pracw"/)
resss@tiXAxisString="scale factor: 1e-8"
resss@tiYAxisString="km"
resss@vpXF              = 0.6
resss@vpYF              = 0.85
resss@tiMainString      = "Autoconvestion and Accretion"
resss@pmLegendWidthF               = 0.1
resss@pmLegendHeightF              = 0.2
resss@lgLabelFontHeightF           = .015
resss@pmLegendSide                 = "Top"
resss@pmLegendParallelPosF         = .60
resss@pmLegendOrthogonalPosF       = -0.5
resss@pmLegendDisplayMode          = "Always"

plot=gsn_csm_xy(wks,model_micro,z,resss)



