load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$GEODIAG_ROOT/geodiag.ncl"

scheme="dbz_convection"
timeslice01="2014-05-22_04:00:00"
timeslice02="2014-05-22_08:00:00"
namess=scheme+timeslice01

npoints=9
thick=10.0  

wrffile01=addfile("./wrfout/wrfout_d03_"+timeslice01,"r")
wrffile02=addfile("./wrfout/wrfout_d03_"+timeslice02,"r")

opts=True
opts@extrapolate=True
opts@field_type="ght"

dbz_tmp = wrf_user_getvar(wrffile01,"dbz",-1)
dbz1=wrf_user_vert_interp(wrffile01,dbz_tmp,"ght_agl",0.5,opts)
dbz1_convec=where(dbz1.le.40,dbz1@_FillValue,dbz1)
dbz1_strati=where(dbz1.lt.40.and.dbz1.ge.20,dbz1,dbz1@_FillValue)

dbz_tmp = wrf_user_getvar(wrffile02,"dbz",-1)
dbz2=wrf_user_vert_interp(wrffile02,dbz_tmp,"ght_agl",0.5,opts)
dbz2_convec=where(dbz2.le.40,dbz2@_FillValue,dbz2)
dbz2_strati=where(dbz2.lt.40.and.dbz2.ge.20,dbz2,dbz2@_FillValue)


lat = wrf_user_getvar(wrffile01,"XLAT",0)
lon = wrf_user_getvar(wrffile02,"XLONG",0)

dbz1_convec@lat2d = lat
dbz1_convec@lon2d = lon

dbz1_strati@lat2d = lat
dbz1_strati@lon2d = lon

dbz2_convec@lat2d = lat
dbz2_convec@lon2d = lon

dbz2_strati@lat2d = lat
dbz2_strati@lon2d = lon


dom_dims = dimsizes(dbz1(0,0,:,:))
dom_rank = dimsizes(dom_dims)
nx1 = dom_dims(dom_rank - 1) - 1
ny1 = dom_dims(dom_rank - 2) - 1

res                 = True

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
res@mpLeftCornerLatF   = lat(0,0)
res@mpLeftCornerLonF   = lon(0,0)
res@mpRightCornerLatF  = lat(ny1,nx1)
res@mpRightCornerLonF  = lon(ny1,nx1)
;res@mpLeftCornerLatF=21.204
;res@mpRightCornerLatF=24.804
;res@mpLeftCornerLonF=111.555
;res@mpRightCornerLonF=115.155
res@lbLabelAutoStride = True
res@gsnMaximize     = True    ; Maximize plot in frame
res@gsnLeftString =""
res@gsnCenterString=scheme


res2                 = True
res2@cnFillOn        = False
res2@cnLinesOn       = True
res2@cnLineLabelsOn  = True
res2@cnInfoLabelOn   = False
res2@cnLevelSelectionMode = "ExplicitLevels"
res2@cnLevels=ispan(5,55,5)
res2@gsnLeftString = ""
res2@gsnRightString = ""
res2@gsnDraw         = False
res2@gsnFrame        = False
res2@cnLineColor="black"

res3                 = True
res3@cnFillOn        = False
res3@cnLinesOn       = True
res3@cnLineLabelsOn  = True
res3@cnInfoLabelOn   = False
res3@cnLevelSelectionMode = "ExplicitLevels"
res3@cnLevels=ispan(5,55,5)
res3@gsnLeftString = ""
res3@gsnRightString = ""
res3@gsnDraw         = False
res3@gsnFrame        = False
res3@cnLineColor="red"

res4                 = True
res4@cnFillOn        = False
res4@cnLinesOn       = True
res4@cnLineLabelsOn  = True
res4@cnInfoLabelOn   = False
res4@cnLevelSelectionMode = "ExplicitLevels"
res4@cnLevels=ispan(5,55,5)
res4@gsnLeftString = ""
res4@gsnRightString = ""
res4@gsnDraw         = False
res4@gsnFrame        = False
res4@cnLineColor="blue"


wks = gsn_open_wks("pdf", namess)
gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")
plot_dbz = gsn_csm_contour_map(wks,dbz1_convec(0,0,:,:),res)
plot_dbz1 = gsn_csm_contour(wks,dbz1_strati(0,0,:,:),res2)
plot_dbz2 = gsn_csm_contour(wks,dbz2_convec(0,0,:,:),res3)
plot_dbz3 = gsn_csm_contour(wks,dbz2_strati(0,0,:,:),res4)

overlay(plot_dbz,plot_dbz1)
overlay(plot_dbz,plot_dbz2)
overlay(plot_dbz,plot_dbz3)

ress=True
ress@gsLineColor      = "red"
ress@gsLineThicknessF = 10.0

lat1s=150
lat2s=300
lon1s=150
lon2s=390

dum = new(4,graphic)
dum(0)=gsn_add_polyline(wks,plot_dbz,lon(lat1s,lon1s:lon2s),lat(lat1s,lon1s:lon2s),ress)
dum(1)=gsn_add_polyline(wks,plot_dbz,lon(lat1s:lat2s,lon1s),lat(lat1s:lat2s,lon1s),ress)
dum(2)=gsn_add_polyline(wks,plot_dbz,lon(lat2s,lon1s:lon2s),lat(lat2s,lon1s:lon2s),ress)
dum(3)=gsn_add_polyline(wks,plot_dbz,lon(lat1s:lat2s,lon2s),lat(lat1s:lat2s,lon2s),ress)



attach_china_map(wks, plot_dbz)
draw(plot_dbz) 
frame(wks)

