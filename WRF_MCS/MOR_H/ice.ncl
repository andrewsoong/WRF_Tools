load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$GEODIAG_ROOT/geodiag.ncl"

scheme="Mor_H"
names=scheme+"ice"
scalefactor=10000.0

opts=True
opts@extrapolate=False
opts@field_type="ght"

wrffile=addfile("./wrfout/wrfout_d03_2014-05-22_06:00:00","r")

z=fspan(0.1,18.0,22)
z@units="km"

x1=113.0
x2=113.7
y1=23.5
y2=22.8

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

tmp00= wrf_user_getvar(wrffile,"eth",-1)
tmp=wrf_user_vert_interp(wrffile,tmp00,"ght_agl",z,opts)
ETH=(rcm2points_Wrap(lattmp,lontmp,tmp,yyy,xxx,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy1,xxx1,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy2,xxx2,2))/3.0
ETH!1="level"
ETH!2="points"

tmp00= wrf_user_getvar(wrffile,"QICE",-1)
tmp=wrf_user_vert_interp(wrffile,tmp00,"ght_agl",z,opts)
QICE=(rcm2points_Wrap(lattmp,lontmp,tmp,yyy,xxx,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy1,xxx1,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy2,xxx2,2))/3.0*scalefactor
QICE!1="level"
QICE!2="points"

tmp00= wrf_user_getvar(wrffile,"QSNOW",-1)
tmp=wrf_user_vert_interp(wrffile,tmp00,"ght_agl",z,opts)
QSNOW=(rcm2points_Wrap(lattmp,lontmp,tmp,yyy,xxx,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy1,xxx1,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy2,xxx2,2))/3.0*scalefactor
QSNOW!1="level"
QSNOW!2="points"

tmp00= wrf_user_getvar(wrffile,"QGRAUP",-1)
tmp=wrf_user_vert_interp(wrffile,tmp00,"ght_agl",z,opts)
QGRAUP=(rcm2points_Wrap(lattmp,lontmp,tmp,yyy,xxx,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy1,xxx1,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy2,xxx2,2))/3.0*scalefactor
QGRAUP!1="level"
QGRAUP!2="points"

tmp00= wrf_user_getvar(wrffile,"tc",-1)
tmp=wrf_user_vert_interp(wrffile,tmp00,"ght_agl",z,opts)
TT=(rcm2points_Wrap(lattmp,lontmp,tmp,yyy,xxx,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy1,xxx1,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy2,xxx2,2))/3.0
TT!1="level"
TT!2="points"

ETH&level=z
QICE&level=z
QSNOW&level=z
QGRAUP&level=z
TT&level=z
ETH&points=fspan(0.0,109.0,100)
QICE&points=fspan(0.0,109.0,100)
QSNOW&points=fspan(0.0,109.0,100)
QGRAUP&points=fspan(0.0,109.0,100)
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
res@cnLevels=ispan(340,420,4)
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

resG=True
resG@cnLineLabelsOn  = True
resG@cnInfoLabelOn   = False
resG@cnLineThicknessF =5.0
resG@cnLineColor="red"
resG@gsnDraw         = False
resG@gsnFrame        = False
resG@gsnLeftString=""
resG@gsnRightString=""
resG@cnLevelSelectionMode = "ExplicitLevels"
resG@cnLevels=ispan(0,200,4)
resG@cnLineLabelDensityF   = 1

resI=True
resI@cnLineLabelsOn  = True
resI@cnInfoLabelOn   = False
resI@cnLineThicknessF =5.0
resI@cnLineColor="green"
resI@gsnDraw         = False
resI@gsnFrame        = False
resI@gsnLeftString=""
resI@gsnRightString=""
resI@cnLevelSelectionMode = "ExplicitLevels"
resI@cnLevels=ispan(0,200,1)
resI@cnLineLabelDensityF   = 1

resC=True
resC@cnLineLabelsOn  = True
resC@cnInfoLabelOn   = False
resC@cnLineThicknessF =5.0
resC@cnLineColor="yellow"
resC@gsnDraw         = False
resC@gsnFrame        = False
resC@gsnLeftString=""
resC@gsnRightString=""
resC@cnLevelSelectionMode = "ExplicitLevels"
resC@cnLevels=ispan(0,200,2)
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
gsn_reverse_colormap(wks)
plot = gsn_csm_contour(wks,ETH(0,:,:) , res)
plot01=gsn_csm_contour(wks,QICE(0,:,:) , resI)
plot02=gsn_csm_contour(wks,QSNOW(0,:,:) , resC)
plot03=gsn_csm_contour(wks,QGRAUP(0,:,:) , resG)
plot04=gsn_csm_contour(wks,TT(0,:,:) , reszero)
overlay(plot,plot01)
overlay(plot,plot02)
overlay(plot,plot03)
overlay(plot,plot04)
draw(plot)

