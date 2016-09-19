load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/time_axis_labels.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRF_contributed.ncl"
load "$GEODIAG_ROOT/geodiag.ncl"

lat1s=150
lat2s=300
lon1s=150
lon2s=390

opts=True
opts@extrapolate=False
opts@field_type="ght"

z=fspan(0.1,3.0,30)
z@units="km"

filelist=systemfunc("ls ./WSM6/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")
DBZ=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)
LAMB=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"CLOUD_LAMB",-1),"ght_agl",z,opts)
idbz=DBZ(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_total=idbz
tmp_total=0
do ii=0,29
  tmp_total(:,ii,:,:)=where(idbz(:,0,:,:).ge.20,111.1,0)
end do
lambtmp=LAMB(:,:,lat1s:lat2s,lon1s:lon2s)
lamb_total=where(tmp_total.ge.20,lambtmp,0)
lamb_total!0="time"
lamb_total!1="level"
lamb_total&level=z

setfileoption("nc","Format","LargeFile")
outfile=addfile("CDSD.nc","c")
outfile->WSM6_lamb_total=lamb_total


filelist=systemfunc("ls ./WDM6/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")
DBZ=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)
LAMB=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"CLOUD_LAMB",-1),"ght_agl",z,opts)
idbz=DBZ(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_total=idbz
tmp_total=0
do ii=0,29
  tmp_total(:,ii,:,:)=where(idbz(:,0,:,:).ge.20,111.1,0)
end do
lambtmp=LAMB(:,:,lat1s:lat2s,lon1s:lon2s)
lamb_total=where(tmp_total.ge.20,lambtmp,0)
lamb_total!0="time"
lamb_total!1="level"
lamb_total&level=z

outfile->WDM6_lamb_total=lamb_total


filelist=systemfunc("ls ./WDM6_H/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")
DBZ=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)
LAMB=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"CLOUD_LAMB",-1),"ght_agl",z,opts)
idbz=DBZ(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_total=idbz
tmp_total=0
do ii=0,29
  tmp_total(:,ii,:,:)=where(idbz(:,0,:,:).ge.20,111.1,0)
end do
lambtmp=LAMB(:,:,lat1s:lat2s,lon1s:lon2s)
lamb_total=where(tmp_total.ge.20,lambtmp,0)
lamb_total!0="time"
lamb_total!1="level"
lamb_total&level=z

outfile->WDM6H_lamb_total=lamb_total

