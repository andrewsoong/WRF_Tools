load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/time_axis_labels.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRF_contributed.ncl"
load "$GEODIAG_ROOT/geodiag.ncl"

scheme="Lin"
thick=5

ethfile=addfile("eth.nc","r")
eth=ethfile->eth

wafile=addfile("wa.nc","r")
wa=wafile->wa

filelist=systemfunc("ls ./wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist, "r")
times  = wrf_times_c(wrffiles[96:126]->Times,0)

nt=145
nz=30
ny=354
nx=435

opts=True
opts@extrapolate=False
opts@field_type="ght"
zlev=fspan(0.1,3,30)
zlev@units="km"
wrffiles=addfile("./wrfout/wrfout_d03_2014-05-21_12:00:00","r")

lat1s=195
lat2s=210
lon1s=260
lon2s=275

ethmin=new((/nt,nz/),"float")
wamin=new((/nt,nz/),"float")
do ii=0,nt-1
  do jj=0,nz-1
    ethmin(ii,jj)=dim_min_n_Wrap(ndtooned(eth(ii,jj,lat1s:lat2s,lon1s:lon2s)),0)
    wamin(ii,jj)=dim_max_n_Wrap(ndtooned(wa(ii,jj,lat1s:lat2s,lon1s:lon2s)),0)
  end do
end do
ethmin!0="time"
ethmin!1="lev"
ethmin&lev=zlev
wamin!0="time"
wamin!1="lev"
wamin&lev=zlev

res                 = True
res@gsnDraw         = False
res@gsnFrame        = False

reswa=res

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

restick           = True
restick@ttmFormat = "%H:%M"   ;"%N/%D %H:%M"
restick@ttmNumTicks=2
restick@ttmMajorStride = 6
time_axis_labels(times,res,restick)
res@tmXBValues=ispan(0,30,6)
delete(res@tmXBMinorValues)

reswa@cnFillOn        = False
reswa@cnLineLabelsOn  = True
reswa@cnInfoLabelOn   = False
reswa@cnLevelSelectionMode = "ExplicitLevels"
reswa@cnLevels=ispan(-10,10,1)
reswa@cnLineThicknessF=thick

wks = gsn_open_wks("eps", scheme+"coldpool")
gsn_define_colormap(wks,"MPL_bwr")
plot00=gsn_csm_contour(wks,ethmin(lev|:,time|96:126), res)
plot01=gsn_csm_contour(wks,wamin(lev|:,time|96:126), reswa)
overlay(plot00,plot01)

draw(plot00)
frame(wks)


