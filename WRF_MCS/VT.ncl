load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"

datafile=addfile("VT_HG.nc","r")

graupel_vt_mor=datafile->graupel_vt_mor
hail_vt_mor=datafile->hail_vt_mor
graupel_vt_wdm=datafile->graupel_vt_wdm
hail_vt_wdm=datafile->hail_vt_wdm

model_micro=new((/4,30/),"float")
model_micro(0,:)=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(graupel_vt_mor,3),2),0)
model_micro(1,:)=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(hail_vt_mor,3),2),0)
model_micro(2,:)=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(graupel_vt_wdm,3),2),0)
model_micro(3,:)=dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(hail_vt_wdm,3),2),0)
z=fspan(0.1,18.0,30)
z@units="km"

wks=gsn_open_wks("pdf" ,"VT_HG")
gsn_define_colormap(wks,"ncl_default")

resss=True
resss@gsnFrame           = False
resss@vpHeightF          = 0.7
resss@vpWidthF           = 0.35
resss@tiMainFontHeightF  = 0.018
resss@tiXAxisFontHeightF = 0.018
resss@tiYAxisFontHeightF = 0.018
resss@xyLineThicknessF   = 2.0
resss@xyLineColors=(/"red","black","orange","blue"/)
resss@xyExplicitLegendLabels = (/"MOR_GRAUP","MOR_HAIL","WDM_GRAUP","WDM_HAIL"/)
resss@tiXAxisString=""
resss@tiYAxisString="km"
resss@vpXF              = 0.6
resss@vpYF              = 0.85
resss@tiMainString      = "Fall Speed"
resss@pmLegendWidthF               = 0.03
resss@pmLegendHeightF              = 0.2
resss@lgLabelFontHeightF           = .015
resss@pmLegendSide                 = "Top"
resss@pmLegendParallelPosF         = .75
resss@pmLegendOrthogonalPosF       = -0.4
resss@pmLegendDisplayMode          = "Always"

plot=gsn_csm_xy(wks,model_micro,z,resss)



