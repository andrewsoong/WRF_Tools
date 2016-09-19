load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$GEODIAG_ROOT/geodiag.ncl"

scheme="Mor_H"
timeslice01="2014-05-22_05:00:00"
timeslice02="2014-05-22_06:00:00"

namess=scheme+"horizontal"+timeslice02

npoints=9
thick=10.0  

wrffile01=addfile("./wrfout/wrfout_d03_"+timeslice01,"r")
wrffile02=addfile("./wrfout/wrfout_d03_"+timeslice02,"r")
wrff1=addfile("./wrfout/wrfout_d03_2014-05-22_04:00:00","r")
wrff2=addfile("./wrfout/wrfout_d03_2014-05-22_08:00:00","r")

opts=True
opts@extrapolate=True
opts@field_type="ght"

dbz_tmp = wrf_user_getvar(wrffile02,"dbz",-1)
dbz=wrf_user_vert_interp(wrffile02,dbz_tmp,"ght_agl",0.5,opts)

utmp=wrf_user_getvar(wrffile02,"ua",-1)
uu=wrf_user_vert_interp(wrffile02,utmp,"ght_agl",0.5,opts)

vtmp=wrf_user_getvar(wrffile02,"va",-1)
vv=wrf_user_vert_interp(wrffile02,vtmp,"ght_agl",0.5,opts)

TT01=wrf_user_getvar(wrffile01,"T2",-1)
TT02=wrf_user_getvar(wrffile02,"T2",-1)
tt=TT02-TT01
copy_VarMeta(TT01,tt)
wrf_smooth_2d(tt,npoints)

rainnc1 = wrf_user_getvar(wrff1,"RAINNC",-1)
rainc1 = wrf_user_getvar(wrff1,"RAINC",-1)
tmp1=rainnc1+rainc1

rainnc2 = wrf_user_getvar(wrff2,"RAINNC",-1)
rainc2 = wrf_user_getvar(wrff2,"RAINC",-1)
tmp2=rainnc2+rainc2

total_rain=tmp2-tmp1

rainnc3 = wrf_user_getvar(wrffile01,"RAINNC",-1)
rainc3 = wrf_user_getvar(wrffile01,"RAINC",-1)
tmp3=rainnc3+rainc3

rainnc4 = wrf_user_getvar(wrffile02,"RAINNC",-1)
rainc4 = wrf_user_getvar(wrffile02,"RAINC",-1)
tmp4=rainnc4+rainc4

hour_rain=tmp4-tmp3

copy_VarMeta(rainnc1,total_rain)
copy_VarMeta(rainnc1,hour_rain)
wrf_smooth_2d(total_rain,npoints)
wrf_smooth_2d(hour_rain,npoints)

lat = wrf_user_getvar(wrffile01,"XLAT",0)
lon = wrf_user_getvar(wrffile02,"XLONG",0)

dbz@lat2d = lat
dbz@lon2d = lon

tt@lat2d = lat
tt@lon2d = lon

total_rain@lat2d = lat
total_rain@lon2d = lon

hour_rain@lat2d = lat
hour_rain@lon2d = lon

uu@lat2d = lat
uu@lon2d = lon
vv@lat2d = lat
vv@lon2d = lon

dom_dims = dimsizes(dbz(0,0,:,:))
dom_rank = dimsizes(dom_dims)
nx1 = dom_dims(dom_rank - 1) - 1
ny1 = dom_dims(dom_rank - 2) - 1

res                 = True
resTT =res
respre=res
respreh=res

res@cnFillOn        = True
res@cnLinesOn       = False
res@cnLineLabelsOn  = False
res@cnInfoLabelOn   = False
res@gsnSpreadColors = True
res@vpWidthF=0.60
res@vpHeightF=0.35 
res@cnLevelSelectionMode = "ExplicitLevels"
res@cnLevels=ispan(5,55,5)
res@gsnLeftString = ""
res@gsnRightString = ""
res@gsnDraw         = False
res@gsnFrame        = False

res@isShowProvince = True
res@isShowSouthChinaSea = False
res@isAddMask = False
res@isShowRivers = True
res@riverColor = "black"
res@riverThickness = 0.5
res@boundaryColor = "black"
res@boundaryThickness = 0.5
setup_china_map(res)

res@mpGridAndLimbOn       = True                ; Turn off lat/lon lines
res@mpGridLineDashPattern       = 2
res@pmTickMarkDisplayMode = "Always"             ; Turn on map tickmarks
res@mpLimitMode        = "Corners"               ; Portion of map to zoom
res@mpLeftCornerLatF=21.204
res@mpRightCornerLatF=24.804
res@mpLeftCornerLonF=111.555
res@mpRightCornerLonF=115.155
res@lbLabelAutoStride = True
res@gsnMaximize     = True    ; Maximize plot in frame
res@gsnLeftString =""
res@gsnCenterString=scheme

resTT@cnFillOn        = False
resTT@cnLinesOn       = True
resTT@cnLineLabelsOn  = True
resTT@gsnDraw         = False
resTT@gsnFrame        = False
resTT@gsnCenterString=""
resTT@gsnLeftString =""
resTT@gsnRightString =""
resTT@cnLevelSelectionMode = "ExplicitLevels"
resTT@cnLevels=(/-5,-1/)
resTT@cnInfoLabelOn   = False
resTT@cnLineLabelInterval        = 1             ; default = 2
resTT@cnLineLabelPlacementMode   = "constant"    ; choose constant label method
resTT@cnLineThicknessF=thick
resTT@cnLineColor       = "Blue"  ;"magenta4"


respre@cnFillOn        = False
respre@cnLinesOn       = True
respre@cnLineLabelsOn  = True
respre@gsnDraw         = False
respre@gsnFrame        = False
respre@gsnCenterString=""
respre@gsnLeftString =""
respre@gsnRightString =""
respre@cnLevelSelectionMode = "ExplicitLevels"
respre@cnLevels=(/4,20,30/)
respre@cnInfoLabelOn   = False
respre@cnLineLabelInterval        = 1             ; default = 2
respre@cnLineLabelPlacementMode   = "constant"    ; choose constant label method
respre@cnLineColor       = "black"  ;"magenta4"    ;"Blue"                  ; blue contour lines 
respre@cnLineDashPattern = 12    
respre@cnLineThicknessF=5

respreh@cnFillOn        = False
respreh@cnLinesOn       = True
respreh@cnLineLabelsOn  = True
respreh@gsnDraw         = False
respreh@gsnFrame        = False
respreh@gsnCenterString=""
respreh@gsnLeftString =""
respreh@gsnRightString =""
respreh@cnLevelSelectionMode = "ExplicitLevels"
respreh@cnLevels=(/10,30,50/)     ;(/4,12,20/)
respreh@cnInfoLabelOn   = False
respreh@cnLineLabelInterval        = 1             ; default = 2
respreh@cnLineLabelPlacementMode   = "constant"    ; choose constant label method
respreh@cnLineColor       = "magenta4"   ;"Blue"                  ; blue contour lines
respreh@cnLineDashPattern = 12
respreh@cnLineThicknessF=thick

res_vc=True
res_vc@gsnDraw         = False
res_vc@gsnFrame        = False
res_vc@gsnLeftString = ""
res_vc@gsnRightString = ""
res_vc@vcGlyphStyle   = "WindBarb"
res_vc@vcMonoWindBarbColor     = True 
res_vc@vcMinDistanceF=0.025
res_vc@vcRefAnnoOn    = False
res_vc@vcRefLengthF   = 0.02

 
wks = gsn_open_wks("eps", namess)
gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")
plot_tt=gsn_csm_contour(wks,tt(0,:,:),resTT)
plot_total_rain=gsn_csm_contour(wks,total_rain(0,:,:),respreh)
plot_dbz = gsn_csm_contour_map(wks,dbz(0,0,:,:),res)
plot_hour_rain=gsn_csm_contour(wks,hour_rain(0,:,:),respre)
plot_wind=gsn_csm_vector(wks,uu(0,0,:,:),vv(0,0,:,:),res_vc)
overlay(plot_dbz,plot_tt)
overlay(plot_dbz,plot_total_rain)
overlay(plot_dbz,plot_hour_rain)
overlay(plot_dbz,plot_wind)


ress=True
ress@gsLineColor      = "red"
ress@gsLineThicknessF = 10.0  

lat1s=205
lat2s=220
lon1s=255
lon2s=270
;
;dum = new(4,graphic)
;dum(0)=gsn_add_polyline(wks,plot_dbz,lon(lat1s,lon1s:lon2s),lat(lat1s,lon1s:lon2s),ress)
;dum(1)=gsn_add_polyline(wks,plot_dbz,lon(lat1s:lat2s,lon1s),lat(lat1s:lat2s,lon1s),ress)
;dum(2)=gsn_add_polyline(wks,plot_dbz,lon(lat2s,lon1s:lon2s),lat(lat2s,lon1s:lon2s),ress)
;dum(3)=gsn_add_polyline(wks,plot_dbz,lon(lat1s:lat2s,lon2s),lat(lat1s:lat2s,lon2s),ress)


slice = new(3,graphic)
resslice=True
resslice@gsLineColor      = "yellow"
resslice@gsLineThicknessF = 10.0

x1=113.0
x2=113.7
y1=23.5
y2=22.8

xxx=fspan(x1,x2,100)
yyy=fspan(y1,y2,100)
slice(0)=gsn_add_polyline(wks,plot_dbz,xxx,yyy,resslice)

xxx=fspan(x1+0.1,x2+0.1,100)
yyy=fspan(y1+0.1,y2+0.1,100)
slice(1)=gsn_add_polyline(wks,plot_dbz,xxx,yyy,resslice)

xxx=fspan(x1-0.1,x2-0.1,100)
yyy=fspan(y1-0.1,y2-0.1,100)
slice(2)=gsn_add_polyline(wks,plot_dbz,xxx,yyy,resslice)

attach_china_map(wks, plot_dbz)
draw(plot_dbz) 
frame(wks)

