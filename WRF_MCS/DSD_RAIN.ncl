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


r_d = 287.04


opts=True
opts@extrapolate=False
opts@field_type="ght"

z=fspan(0.1,3.0,30)
z@units="km"

filelist=systemfunc("ls ./MOR/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")
DBZ=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)
tk=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"tk",-1),"ght_agl",z,opts)
pressure=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"pressure",-1),"ght_agl",z,opts)*100.0
qv=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QVAPOR",-1),"ght_agl",z,opts)
rho = 0.622*pressure/(r_d*tk*(qv+0.622))
idbz=DBZ(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_total=idbz
tmp_total=0
do ii=0,29
  tmp_total(:,ii,:,:)=where(idbz(:,0,:,:).ge.20,111.1,0)
end do
rhotmp=rho(:,:,lat1s:lat2s,lon1s:lon2s)
rho_total=where(tmp_total.ge.20,rhotmp,0)
rho_total!0="time"
rho_total!1="level"
rho_total&level=z

setfileoption("nc","Format","LargeFile")
outfile=addfile("RHO.nc","c")
outfile->MOR_rho_total=rho_total


filelist=systemfunc("ls ./MOR_H/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")
DBZ=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)
tk=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"tk",-1),"ght_agl",z,opts)
pressure=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"pressure",-1),"ght_agl",z,opts)*100.0
qv=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QVAPOR",-1),"ght_agl",z,opts)
rho = 0.622*pressure/(r_d*tk*(qv+0.622))
idbz=DBZ(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_total=idbz
tmp_total=0
do ii=0,29
  tmp_total(:,ii,:,:)=where(idbz(:,0,:,:).ge.20,111.1,0)
end do
rhotmp=rho(:,:,lat1s:lat2s,lon1s:lon2s)
rho_total=where(tmp_total.ge.20,rhotmp,0)
rho_total!0="time"
rho_total!1="level"
rho_total&level=z

outfile->MOR_H_rho_total=rho_total

