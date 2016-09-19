load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRF_contributed.ncl"

lat1s=150
lat2s=300
lon1s=150
lon2s=390

opts=True
opts@extrapolate=False
opts@field_type="ght"

z=fspan(0.1,18.0,30)
z@units="km"

filelist=systemfunc("ls ./MOR/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")

DBZ=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)

QRAIN=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QRAIN",-1),"ght_agl",z,opts)
QVAPOR=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QVAPOR",-1),"ght_agl",z,opts)
QCLOUD=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QCLOUD",-1),"ght_agl",z,opts)
QICE=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QICE",-1),"ght_agl",z,opts)
QSNOW=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QSNOW",-1),"ght_agl",z,opts)
QNRAIN=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QNRAIN",-1),"ght_agl",z,opts)
QNGRAUPEL=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QNGRAUPEL",-1),"ght_agl",z,opts)
QNSNOW=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QNSNOW",-1),"ght_agl",z,opts)
QNICE=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QNICE",-1),"ght_agl",z,opts)
QGRAUP=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QGRAUP",-1),"ght_agl",z,opts)

idbz=DBZ(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_total=idbz
tmp_total=0
do ii=0,29
  tmp_total(:,ii,:,:)=where(idbz(:,0,:,:).ge.20,111.1,0)
end do

qrain_tmp=QRAIN(:,:,lat1s:lat2s,lon1s:lon2s)
qvapor_tmp=QVAPOR(:,:,lat1s:lat2s,lon1s:lon2s)
qcloud_tmp=QCLOUD(:,:,lat1s:lat2s,lon1s:lon2s)
qice_tmp=QICE(:,:,lat1s:lat2s,lon1s:lon2s)
qsnow_tmp=QSNOW(:,:,lat1s:lat2s,lon1s:lon2s)
qgraup_tmp=QGRAUP(:,:,lat1s:lat2s,lon1s:lon2s)
qnice_tmp=QNICE(:,:,lat1s:lat2s,lon1s:lon2s)
qnsnow_tmp=QNSNOW(:,:,lat1s:lat2s,lon1s:lon2s)
qnrain_tmp=QNRAIN(:,:,lat1s:lat2s,lon1s:lon2s)
qngraup_tmp=QNGRAUPEL(:,:,lat1s:lat2s,lon1s:lon2s)

qrain_total=where(tmp_total.ge.20,qrain_tmp,0)
qrain_total!0="time"
qrain_total!1="level"
qrain_total&level=z

qvapor_total=where(tmp_total.ge.20,qvapor_tmp,0)
qvapor_total!0="time"
qvapor_total!1="level"
qvapor_total&level=z

qcloud_total=where(tmp_total.ge.20,qcloud_tmp,0)
qcloud_total!0="time"
qcloud_total!1="level"
qcloud_total&level=z

qice_total=where(tmp_total.ge.20,qice_tmp,0)
qice_total!0="time"
qice_total!1="level"
qice_total&level=z

qsnow_total=where(tmp_total.ge.20,qsnow_tmp,0)
qsnow_total!0="time"
qsnow_total!1="level"
qsnow_total&level=z

qgraup_total=where(tmp_total.ge.20,qgraup_tmp,0)
qgraup_total!0="time"
qgraup_total!1="level"
qgraup_total&level=z

qnice_total=where(tmp_total.ge.20,qnice_tmp,0)
qnice_total!0="time"
qnice_total!1="level"
qnice_total&level=z

qnsnow_total=where(tmp_total.ge.20,qnsnow_tmp,0)
qnsnow_total!0="time"
qnsnow_total!1="level"
qnsnow_total&level=z

qnrain_total=where(tmp_total.ge.20,qnrain_tmp,0)
qnrain_total!0="time"
qnrain_total!1="level"
qnrain_total&level=z

qngraup_total=where(tmp_total.ge.20,qngraup_tmp,0)
qngraup_total!0="time"
qngraup_total!1="level"
qngraup_total&level=z

setfileoption("nc","Format","LargeFile")
outfile=addfile("microphysics.nc","c")
outfile->MOR_qrain_total=qrain_total
outfile->MOR_qvapor_total=qvapor_total
outfile->MOR_qcloud_total=qcloud_total
outfile->MOR_qice_total=qice_total
outfile->MOR_qsnow_total=qsnow_total
outfile->MOR_qgraup_total=qgraup_total
outfile->MOR_qnice_total=qnice_total
outfile->MOR_qnsnow_total=qnsnow_total
outfile->MOR_qnrain_total=qnrain_total
outfile->MOR_qngraup_total=qngraup_total
print("MOR")

filelist=systemfunc("ls ./MOR_H/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")

DBZ=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)

QRAIN=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QRAIN",-1),"ght_agl",z,opts)
QVAPOR=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QVAPOR",-1),"ght_agl",z,opts)
QCLOUD=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QCLOUD",-1),"ght_agl",z,opts)
QICE=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QICE",-1),"ght_agl",z,opts)
QSNOW=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QSNOW",-1),"ght_agl",z,opts)
QNRAIN=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QNRAIN",-1),"ght_agl",z,opts)
QNGRAUPEL=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QNGRAUPEL",-1),"ght_agl",z,opts)
QNSNOW=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QNSNOW",-1),"ght_agl",z,opts)
QNICE=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QNICE",-1),"ght_agl",z,opts)
QGRAUP=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QGRAUP",-1),"ght_agl",z,opts)

idbz=DBZ(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_total=idbz
tmp_total=0
do ii=0,29
  tmp_total(:,ii,:,:)=where(idbz(:,0,:,:).ge.20,111.1,0)
end do

qrain_tmp=QRAIN(:,:,lat1s:lat2s,lon1s:lon2s)
qvapor_tmp=QVAPOR(:,:,lat1s:lat2s,lon1s:lon2s)
qcloud_tmp=QCLOUD(:,:,lat1s:lat2s,lon1s:lon2s)
qice_tmp=QICE(:,:,lat1s:lat2s,lon1s:lon2s)
qsnow_tmp=QSNOW(:,:,lat1s:lat2s,lon1s:lon2s)
qgraup_tmp=QGRAUP(:,:,lat1s:lat2s,lon1s:lon2s)
qnice_tmp=QNICE(:,:,lat1s:lat2s,lon1s:lon2s)
qnsnow_tmp=QNSNOW(:,:,lat1s:lat2s,lon1s:lon2s)
qnrain_tmp=QNRAIN(:,:,lat1s:lat2s,lon1s:lon2s)
qngraup_tmp=QNGRAUPEL(:,:,lat1s:lat2s,lon1s:lon2s)

qrain_total=where(tmp_total.ge.20,qrain_tmp,0)
qrain_total!0="time"
qrain_total!1="level"
qrain_total&level=z

qvapor_total=where(tmp_total.ge.20,qvapor_tmp,0)
qvapor_total!0="time"
qvapor_total!1="level"
qvapor_total&level=z

qcloud_total=where(tmp_total.ge.20,qcloud_tmp,0)
qcloud_total!0="time"
qcloud_total!1="level"
qcloud_total&level=z

qice_total=where(tmp_total.ge.20,qice_tmp,0)
qice_total!0="time"
qice_total!1="level"
qice_total&level=z

qsnow_total=where(tmp_total.ge.20,qsnow_tmp,0)
qsnow_total!0="time"
qsnow_total!1="level"
qsnow_total&level=z

qgraup_total=where(tmp_total.ge.20,qgraup_tmp,0)
qgraup_total!0="time"
qgraup_total!1="level"
qgraup_total&level=z

qnice_total=where(tmp_total.ge.20,qnice_tmp,0)
qnice_total!0="time"
qnice_total!1="level"
qnice_total&level=z

qnsnow_total=where(tmp_total.ge.20,qnsnow_tmp,0)
qnsnow_total!0="time"
qnsnow_total!1="level"
qnsnow_total&level=z

qnrain_total=where(tmp_total.ge.20,qnrain_tmp,0)
qnrain_total!0="time"
qnrain_total!1="level"
qnrain_total&level=z

qngraup_total=where(tmp_total.ge.20,qngraup_tmp,0)
qngraup_total!0="time"
qngraup_total!1="level"
qngraup_total&level=z

outfile->MOR_H_qrain_total=qrain_total
outfile->MOR_H_qvapor_total=qvapor_total
outfile->MOR_H_qcloud_total=qcloud_total
outfile->MOR_H_qice_total=qice_total
outfile->MOR_H_qsnow_total=qsnow_total
outfile->MOR_H_qgraup_total=qgraup_total
outfile->MOR_H_qnice_total=qnice_total
outfile->MOR_H_qnsnow_total=qnsnow_total
outfile->MOR_H_qnrain_total=qnrain_total
outfile->MOR_H_qngraup_total=qngraup_total
print("MOR_H")

filelist=systemfunc("ls ./WDM6/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")

DBZ=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)

QRAIN=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QRAIN",-1),"ght_agl",z,opts)
QVAPOR=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QVAPOR",-1),"ght_agl",z,opts)
QCLOUD=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QCLOUD",-1),"ght_agl",z,opts)
QICE=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QICE",-1),"ght_agl",z,opts)
QSNOW=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QSNOW",-1),"ght_agl",z,opts)
QNRAIN=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QNRAIN",-1),"ght_agl",z,opts)
QNCLOUD=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QNCLOUD",-1),"ght_agl",z,opts)
QGRAUP=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QGRAUP",-1),"ght_agl",z,opts)

idbz=DBZ(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_total=idbz
tmp_total=0
do ii=0,29
  tmp_total(:,ii,:,:)=where(idbz(:,0,:,:).ge.20,111.1,0)
end do

qrain_tmp=QRAIN(:,:,lat1s:lat2s,lon1s:lon2s)
qvapor_tmp=QVAPOR(:,:,lat1s:lat2s,lon1s:lon2s)
qcloud_tmp=QCLOUD(:,:,lat1s:lat2s,lon1s:lon2s)
qice_tmp=QICE(:,:,lat1s:lat2s,lon1s:lon2s)
qsnow_tmp=QSNOW(:,:,lat1s:lat2s,lon1s:lon2s)
qgraup_tmp=QGRAUP(:,:,lat1s:lat2s,lon1s:lon2s)
qncloud_tmp=QNSNOW(:,:,lat1s:lat2s,lon1s:lon2s)
qnrain_tmp=QNRAIN(:,:,lat1s:lat2s,lon1s:lon2s)

qrain_total=where(tmp_total.ge.20,qrain_tmp,0)
qrain_total!0="time"
qrain_total!1="level"
qrain_total&level=z

qvapor_total=where(tmp_total.ge.20,qvapor_tmp,0)
qvapor_total!0="time"
qvapor_total!1="level"
qvapor_total&level=z

qcloud_total=where(tmp_total.ge.20,qcloud_tmp,0)
qcloud_total!0="time"
qcloud_total!1="level"
qcloud_total&level=z

qice_total=where(tmp_total.ge.20,qice_tmp,0)
qice_total!0="time"
qice_total!1="level"
qice_total&level=z

qsnow_total=where(tmp_total.ge.20,qsnow_tmp,0)
qsnow_total!0="time"
qsnow_total!1="level"
qsnow_total&level=z

qgraup_total=where(tmp_total.ge.20,qgraup_tmp,0)
qgraup_total!0="time"
qgraup_total!1="level"
qgraup_total&level=z

qnrain_total=where(tmp_total.ge.20,qnrain_tmp,0)
qnrain_total!0="time"
qnrain_total!1="level"
qnrain_total&level=z

qncloud_total=where(tmp_total.ge.20,qncloud_tmp,0)
qncloud_total!0="time"
qncloud_total!1="level"
qncloud_total&level=z

outfile->WDM_qrain_total=qrain_total
outfile->WDM_qvapor_total=qvapor_total
outfile->WDM_qcloud_total=qcloud_total
outfile->WDM_qice_total=qice_total
outfile->WDM_qsnow_total=qsnow_total
outfile->WDM_qgraup_total=qgraup_total
outfile->WDM_qncloud_total=qncloud_total
outfile->WDM_qnrain_total=qnrain_total
print("WDM6")

filelist=systemfunc("ls ./WDM6_H/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")

DBZ=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)

QRAIN=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QRAIN",-1),"ght_agl",z,opts)
QVAPOR=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QVAPOR",-1),"ght_agl",z,opts)
QCLOUD=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QCLOUD",-1),"ght_agl",z,opts)
QICE=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QICE",-1),"ght_agl",z,opts)
QSNOW=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QSNOW",-1),"ght_agl",z,opts)
QNRAIN=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QNRAIN",-1),"ght_agl",z,opts)
QNCLOUD=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QNCLOUD",-1),"ght_agl",z,opts)
QGRAUP=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QGRAUP",-1),"ght_agl",z,opts)

idbz=DBZ(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_total=idbz
tmp_total=0
do ii=0,29
  tmp_total(:,ii,:,:)=where(idbz(:,0,:,:).ge.20,111.1,0)
end do

qrain_tmp=QRAIN(:,:,lat1s:lat2s,lon1s:lon2s)
qvapor_tmp=QVAPOR(:,:,lat1s:lat2s,lon1s:lon2s)
qcloud_tmp=QCLOUD(:,:,lat1s:lat2s,lon1s:lon2s)
qice_tmp=QICE(:,:,lat1s:lat2s,lon1s:lon2s)
qsnow_tmp=QSNOW(:,:,lat1s:lat2s,lon1s:lon2s)
qgraup_tmp=QGRAUP(:,:,lat1s:lat2s,lon1s:lon2s)
qncloud_tmp=QNSNOW(:,:,lat1s:lat2s,lon1s:lon2s)
qnrain_tmp=QNRAIN(:,:,lat1s:lat2s,lon1s:lon2s)

qrain_total=where(tmp_total.ge.20,qrain_tmp,0)
qrain_total!0="time"
qrain_total!1="level"
qrain_total&level=z

qvapor_total=where(tmp_total.ge.20,qvapor_tmp,0)
qvapor_total!0="time"
qvapor_total!1="level"
qvapor_total&level=z

qcloud_total=where(tmp_total.ge.20,qcloud_tmp,0)
qcloud_total!0="time"
qcloud_total!1="level"
qcloud_total&level=z

qice_total=where(tmp_total.ge.20,qice_tmp,0)
qice_total!0="time"
qice_total!1="level"
qice_total&level=z

qsnow_total=where(tmp_total.ge.20,qsnow_tmp,0)
qsnow_total!0="time"
qsnow_total!1="level"
qsnow_total&level=z

qgraup_total=where(tmp_total.ge.20,qgraup_tmp,0)
qgraup_total!0="time"
qgraup_total!1="level"
qgraup_total&level=z

qnrain_total=where(tmp_total.ge.20,qnrain_tmp,0)
qnrain_total!0="time"
qnrain_total!1="level"
qnrain_total&level=z

qncloud_total=where(tmp_total.ge.20,qncloud_tmp,0)
qncloud_total!0="time"
qncloud_total!1="level"
qncloud_total&level=z

outfile->WDM_H_qrain_total=qrain_total
outfile->WDM_H_qvapor_total=qvapor_total
outfile->WDM_H_qcloud_total=qcloud_total
outfile->WDM_H_qice_total=qice_total
outfile->WDM_H_qsnow_total=qsnow_total
outfile->WDM_H_qgraup_total=qgraup_total
outfile->WDM_H_qncloud_total=qncloud_total
outfile->WDM_H_qnrain_total=qnrain_total
print("WDM_H6")

filelist=systemfunc("ls ./WSM6/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")

DBZ=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)

QRAIN=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QRAIN",-1),"ght_agl",z,opts)
QVAPOR=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QVAPOR",-1),"ght_agl",z,opts)
QCLOUD=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QCLOUD",-1),"ght_agl",z,opts)
QICE=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QICE",-1),"ght_agl",z,opts)
QSNOW=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QSNOW",-1),"ght_agl",z,opts)
QGRAUP=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"QGRAUP",-1),"ght_agl",z,opts)

idbz=DBZ(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_total=idbz
tmp_total=0
do ii=0,29
  tmp_total(:,ii,:,:)=where(idbz(:,0,:,:).ge.20,111.1,0)
end do

qrain_tmp=QRAIN(:,:,lat1s:lat2s,lon1s:lon2s)
qvapor_tmp=QVAPOR(:,:,lat1s:lat2s,lon1s:lon2s)
qcloud_tmp=QCLOUD(:,:,lat1s:lat2s,lon1s:lon2s)
qice_tmp=QICE(:,:,lat1s:lat2s,lon1s:lon2s)
qsnow_tmp=QSNOW(:,:,lat1s:lat2s,lon1s:lon2s)
qgraup_tmp=QGRAUP(:,:,lat1s:lat2s,lon1s:lon2s)

qrain_total=where(tmp_total.ge.20,qrain_tmp,0)
qrain_total!0="time"
qrain_total!1="level"
qrain_total&level=z

qvapor_total=where(tmp_total.ge.20,qvapor_tmp,0)
qvapor_total!0="time"
qvapor_total!1="level"
qvapor_total&level=z

qcloud_total=where(tmp_total.ge.20,qcloud_tmp,0)
qcloud_total!0="time"
qcloud_total!1="level"
qcloud_total&level=z

qice_total=where(tmp_total.ge.20,qice_tmp,0)
qice_total!0="time"
qice_total!1="level"
qice_total&level=z

qsnow_total=where(tmp_total.ge.20,qsnow_tmp,0)
qsnow_total!0="time"
qsnow_total!1="level"
qsnow_total&level=z

qgraup_total=where(tmp_total.ge.20,qgraup_tmp,0)
qgraup_total!0="time"
qgraup_total!1="level"
qgraup_total&level=z

outfile->WSM_qrain_total=qrain_total
outfile->WSM_qvapor_total=qvapor_total
outfile->WSM_qcloud_total=qcloud_total
outfile->WSM_qice_total=qice_total
outfile->WSM_qsnow_total=qsnow_total
outfile->WSM_qgraup_total=qgraup_total
outfile->WSM_qncloud_total=qncloud_total
outfile->WSM_qnrain_total=qnrain_total
print("WSM6")

