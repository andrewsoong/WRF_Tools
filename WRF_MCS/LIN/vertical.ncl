load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$GEODIAG_ROOT/geodiag.ncl"

scheme="Lin"
names=scheme+"vertical"

opts=True
opts@extrapolate=False
opts@field_type="ght"

thick=3

wrffile=addfile("./wrfout/wrfout_d03_2014-05-22_06:00:00","r")
wrffile01=addfile("./wrfout/wrfout_d03_2014-05-22_05:00:00","r")

z=fspan(0.1,18.0,22)
z@units="km"

x1=113.2
x2=113.9
y1=23.2
y2=22.5

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

tmp00= wrf_user_getvar(wrffile,"dbz",-1)
tmp=wrf_user_vert_interp(wrffile,tmp00,"ght_agl",z,opts)
dbz=(rcm2points_Wrap(lattmp,lontmp,tmp,yyy,xxx,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy1,xxx1,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy2,xxx2,2))/3.0
dbz!1="level"
dbz!2="points"

tmp00= wrf_user_getvar(wrffile,"tk",-1)
tmp11=wrf_user_getvar(wrffile01,"tk",-1)
tmp0=wrf_user_vert_interp(wrffile,tmp00,"ght_agl",z,opts)
tmp1=wrf_user_vert_interp(wrffile01,tmp11,"ght_agl",z,opts)
tmp=tmp0-tmp1
TT=(rcm2points_Wrap(lattmp,lontmp,tmp,yyy,xxx,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy1,xxx1,2)+rcm2points_Wrap(lattmp,lontmp,tmp,yyy2,xxx2,2))/3.0
TT!1="level"
TT!2="points"

utmp00= wrf_user_getvar(wrffile,"ua",-1)
utmp=wrf_user_vert_interp(wrffile,utmp00,"ght_agl",z,opts)
u=(rcm2points_Wrap(lattmp,lontmp,utmp,yyy,xxx,2)+rcm2points_Wrap(lattmp,lontmp,utmp,yyy1,xxx1,2)+rcm2points_Wrap(lattmp,lontmp,utmp,yyy2,xxx2,2))/3.0
u!1="level"
u!2="points"

vtmp00= wrf_user_getvar(wrffile,"va",-1)
vtmp=wrf_user_vert_interp(wrffile,vtmp00,"ght_agl",z,opts)
v=(rcm2points_Wrap(lattmp,lontmp,vtmp,yyy,xxx,2)+rcm2points_Wrap(lattmp,lontmp,vtmp,yyy1,xxx1,2)+rcm2points_Wrap(lattmp,lontmp,vtmp,yyy2,xxx2,2))/3.0
v!1="level"
v!2="points"

theta=(u*dxxx+v*dyyy)/sqrt(dxxx*dxxx+dyyy*dyyy)/sqrt(u*u+v*v)
sintheta=sqrt(1-theta*theta)
uu=sqrt(u*u+v*v)*theta
uu!1="level"
uu!2="points"

vv=sqrt(u*u+v*v)*sintheta
vv!1="level"
vv!2="points"

wtmp00= wrf_user_getvar(wrffile,"wa",-1)
wtmp=wrf_user_vert_interp(wrffile,wtmp00,"ght_agl",z,opts)
w=(rcm2points_Wrap(lattmp,lontmp,wtmp,yyy,xxx,2)+rcm2points_Wrap(lattmp,lontmp,wtmp,yyy1,xxx1,2)+rcm2points_Wrap(lattmp,lontmp,wtmp,yyy2,xxx2,2))/3.0
w!1="level"
w!2="points"

dbz&level=z
uu&level=z
w&level=z 
vv&level=z
TT&level=z
;delete(dbz&points)
;delete(w&points)
;delete(TT&points)
dbz&points=fspan(0.0,109.0,100)
uu&points=fspan(0.0,109.0,100)
w&points=fspan(0.0,109.0,100)
vv&points=fspan(0.0,109.0,100)
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
res@cnLevels=ispan(5,55,5) 
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


resTT=True
resTT@cnLineLabelsOn  = True
resTT@cnLineLabelsOn  = True
resTT@cnInfoLabelOn   = False
resTT@cnLineThicknessF =thick
resTT@cnLineColor="blue"
resTT@gsnDraw         = False
resTT@gsnFrame        = False
resTT@gsnLeftString=""
resTT@gsnRightString=""
resTT@cnLevelSelectionMode = "ExplicitLevels"
resTT@cnLevels=ispan(4,32,6)


vcres=True
vcres@gsnDraw         = False
vcres@gsnFrame        = False
vcres@tfDoNDCOverlay=True
vcres@vcFillArrowsOn=False
vcres@vcRefLengthF=0.02
vcres@vcGlyphStyle="CurlyVector"
vcres@vcMinDistanceF=0.01
vcres@vcLineArrowThicknessF=1
vcres@gsnMaximize=True
vcres@vcRefAnnoOn               = True
vcres@vcRefMagnitudeF           = 20 
vcres@vcRefAnnoString1          = "20 m/s"
vcres@vcRefAnnoSide             = "Top"
vcres@vcRefAnnoString2On        = False
vcres@vcRefAnnoPerimOn          = False
vcres@vcRefAnnoOrthogonalPosF   = -0.15
vcres@vcRefAnnoParallelPosF     = 0.999
vcres@vcRefAnnoBackgroundColor  = "White"

resG=True
resG@cnLineLabelsOn  = True
resG@cnInfoLabelOn   = False
resG@cnLineThicknessF =thick
resG@cnLineColor="cyan"
resG@gsnDraw         = False
resG@gsnFrame        = False
resG@gsnLeftString=""
resG@gsnRightString=""
resG@cnLevelSelectionMode = "ExplicitLevels"
resG@cnLevels=ispan(-8,-1,1)
resG@cnLineLabelDensityF   = 1
resG@gsnContourNegLineDashPattern = 1

TT(0,6:,:)=0.0

wks = gsn_open_wks("eps", names)
gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")
plot = gsn_csm_contour(wks,dbz(0,:,:) , res)
plottt=gsn_csm_contour(wks,TT(0,:,:) , resG)
plotvv=gsn_csm_contour(wks,vv(0,:,:) , resTT)
overlay(plot,plottt)
overlay(plot,plotvv)
plot1=gsn_csm_vector(wks,uu(0,:,:),w(0,:,:),vcres)
overlay(plot,plot1)
draw(plot)

