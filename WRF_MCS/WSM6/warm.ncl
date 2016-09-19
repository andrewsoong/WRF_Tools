load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$GEODIAG_ROOT/geodiag.ncl"

scheme="WSM6"
names=scheme+"warm"
scalefactor=10000.0

opts=True
opts@extrapolate=False
opts@field_type="ght"

wrffile=addfile("./wrfout/wrfout_d03_2014-05-22_06:00:00","r")

z=fspan(0.1,18.0,22)
z@units="km"

x1=113.1
x2=113.8
y1=23.4
y2=22.7

xxx=fspan(x1,x2,100)
yyy=fspan(y1,y2,100)

xxx1=fspan(x1+0.1,x2+0.1,100)
yyy1=fspan(y1+0.1,y2+0.1,100)

xxx2=fspan(x1-0.1,x2-0.1,100)
yyy2=fspan(y1-0.1,y2-0.1,100)

dxxx=x2-x1
dyyy=y2-y1

lattmp = wrf_user_getvar(wrffile,"XLAT",0)
lontmp = wrf_user_getvar(wrffile,"XLONG",0)

tmp00= wrf_user_getvar(wrffile,"rh",-1)
tmp=wrf_user_vert_interp(wrffile,tmp00,"ght_agl",z,opts)
RH=(rcm2points_Wrap(lattmp,lontmp,tmp,yyy,xxx,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy1,xxx1,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy2,xxx2,2))/3.0
RH!1="level"
RH!2="points"

tmp00= wrf_user_getvar(wrffile,"QRAIN",-1)
tmp=wrf_user_vert_interp(wrffile,tmp00,"ght_agl",z,opts)
QRAIN=(rcm2points_Wrap(lattmp,lontmp,tmp,yyy,xxx,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy1,xxx1,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy2,xxx2,2))/3.0*scalefactor
QRAIN!1="level"
QRAIN!2="points"

tmp00= wrf_user_getvar(wrffile,"QCLOUD",-1)
tmp=wrf_user_vert_interp(wrffile,tmp00,"ght_agl",z,opts)
QCLOUD=(rcm2points_Wrap(lattmp,lontmp,tmp,yyy,xxx,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy1,xxx1,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy2,xxx2,2))/3.0*scalefactor
QCLOUD!1="level"
QCLOUD!2="points"

tmp00= wrf_user_getvar(wrffile,"QICE",-1)
tmp11= wrf_user_getvar(wrffile,"QSNOW",-1)
tmp22= wrf_user_getvar(wrffile,"QGRAUP",-1)
tmp=wrf_user_vert_interp(wrffile,tmp00,"ght_agl",z,opts)+wrf_user_vert_interp(wrffile,tmp11,"ght_agl",z,opts)+wrf_user_vert_interp(wrffile,tmp22,"ght_agl",z,opts)
QTOTALICE=(rcm2points_Wrap(lattmp,lontmp,tmp,yyy,xxx,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy1,xxx1,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy2,xxx2,2))/3.0*scalefactor
QTOTALICE!1="level"
QTOTALICE!2="points"

tmp00= wrf_user_getvar(wrffile,"tc",-1)
tmp=wrf_user_vert_interp(wrffile,tmp00,"ght_agl",z,opts)
TT=(rcm2points_Wrap(lattmp,lontmp,tmp,yyy,xxx,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy1,xxx1,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy2,xxx2,2))/3.0
TT!1="level"
TT!2="points"

RH&level=z
QRAIN&level=z
QCLOUD&level=z
QTOTALICE&level=z
TT&level=z
RH&points=fspan(0.0,109.0,100)
QRAIN&points=fspan(0.0,109.0,100)
QCLOUD&points=fspan(0.0,109.0,100)
QTOTALICE&points=fspan(0.0,109.0,100)
TT&points=fspan(0.0,109.0,100)

res                 = True
res@cnFillOn        = True 
res@cnLinesOn       = False 
res@cnLineLabelsOn  = False
res@cnInfoLabelOn   = False
res@gsnSpreadColors = True
res@vpWidthF=0.60
res@vpHeightF=0.35
res@cnLevelSelectionMode = "ExplicitLevels"
res@cnLevels=ispan(10,90,10)
res@gsnDraw         = False
res@gsnFrame        = False
res@gsnMaximize=True
res@gsnLeftString=""
res@gsnRightString=""
res@tiMainString=scheme
res@lbLabelBarOn=True
res@lbOrientation           = "vertical" 
res@tiXAxisString=""
res@tmXBLabelsOn =True

resQ=True
resQ@cnLineLabelsOn  = True
resQ@cnInfoLabelOn   = False
resQ@cnLineThicknessF =5.0
resQ@cnLineColor="red"
resQ@gsnDraw         = False
resQ@gsnFrame        = False
resQ@gsnLeftString=""
resQ@gsnRightString=""
resQ@cnLevelSelectionMode = "ExplicitLevels"
resQ@cnLevels=ispan(0,200,4)
resQ@cnLineLabelDensityF   = 3

resI=True
resI@cnLineLabelsOn  = True
resI@cnInfoLabelOn   = False
resI@cnLineThicknessF =5.0
resI@cnLineColor="yellow"
resI@gsnDraw         = False
resI@gsnFrame        = False
resI@gsnLeftString=""
resI@gsnRightString=""
resI@cnLevelSelectionMode = "ExplicitLevels"
resI@cnLevels=ispan(0,200,4)
resI@cnLineLabelDensityF   = 1

resC=True
resC@cnLineLabelsOn  = True
resC@cnInfoLabelOn   = False
resC@cnLineThicknessF =5.0
resC@cnLineColor="green"
resC@gsnDraw         = False
resC@gsnFrame        = False
resC@gsnLeftString=""
resC@gsnRightString=""
resC@cnLevelSelectionMode = "ExplicitLevels"
resC@cnLevels=ispan(0,200,4)
resC@cnLineLabelDensityF   = 1

reszero=True
reszero@cnLevelSelectionMode = "ExplicitLevels"
reszero@cnLevels=(/0.0/)
reszero@gsnDraw         = False
reszero@gsnFrame        = False
reszero@cnLineThicknessF =5.0
reszero@cnLineColor="black"
reszero@cnInfoLabelOn  = False

wks = gsn_open_wks("eps", names)
gsn_define_colormap(wks,"WhiteBlue")
plot = gsn_csm_contour(wks,RH(0,:,:) , res)
plot01=gsn_csm_contour(wks,QRAIN(0,:,:) , resQ)
plot03=gsn_csm_contour(wks,QTOTALICE(0,:,:) , resI)
plot04=gsn_csm_contour(wks,QCLOUD(0,:,:) , resC)
plot05=gsn_csm_contour(wks,TT(0,:,:) , reszero)
overlay(plot,plot01)
overlay(plot,plot03)
overlay(plot,plot04)
overlay(plot,plot05)
draw(plot)

