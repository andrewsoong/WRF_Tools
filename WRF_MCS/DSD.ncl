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

filelist=systemfunc("ls ./MOR/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")

DBZ=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)

N0=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"RAIN_N0",-1),"ght_agl",z,opts)
LAMB=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"RAIN_LAMB",-1),"ght_agl",z,opts)

idbz=DBZ(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_conv=idbz
tmp_stra=idbz
tmp_total=idbz
tmp_conv=0
tmp_stra=0
tmp_total=0
do ii=0,29
  tmp_conv(:,ii,:,:)=where(idbz(:,0,:,:).gt.40,111.1,0)
  tmp_stra(:,ii,:,:)=where(idbz(:,0,:,:).ge.20.and.idbz(:,0,:,:).le.40,333.3,0)
  tmp_total(:,ii,:,:)=where(idbz(:,0,:,:).ge.20,111.1,0)
end do

n0tmp=N0(:,:,lat1s:lat2s,lon1s:lon2s)
lambtmp=LAMB(:,:,lat1s:lat2s,lon1s:lon2s)

n0_conv=where(tmp_conv.gt.40,n0tmp,0)
n0_conv!0="time"
n0_conv!1="level"
n0_conv&level=z

n0_trail=where(tmp_stra.ge.20.and.tmp_stra.le.40,n0tmp,0)
n0_trail!0="time"
n0_trail!1="level"
n0_trail&level=z

n0_total=where(tmp_total.ge.20,n0tmp,0)
n0_total!0="time"
n0_total!1="level"
n0_total&level=z

lamb_conv=where(tmp_conv.gt.40,lambtmp,0)
lamb_conv!0="time"
lamb_conv!1="level"
lamb_conv&level=z

lamb_trail=where(tmp_stra.ge.20.and.tmp_stra.le.40,lambtmp,0)
lamb_trail!0="time"
lamb_trail!1="level"
lamb_trail&level=z

lamb_total=where(tmp_total.ge.20,lambtmp,0)
lamb_total!0="time"
lamb_total!1="level"
lamb_total&level=z

setfileoption("nc","Format","LargeFile")
outfile=addfile("RDSD.nc","c")
outfile->MOR_n0_conv=n0_conv
outfile->MOR_n0_trail=n0_trail
outfile->MOR_n0_total=n0_total
outfile->MOR_lamb_conv=lamb_conv
outfile->MOR_lamb_trail=lamb_trail
outfile->MOR_lamb_total=lamb_total

print("MOR")







filelist=systemfunc("ls ./MOR_H/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")

DBZ=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)

N0=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"RAIN_N0",-1),"ght_agl",z,opts)
LAMB=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"RAIN_LAMB",-1),"ght_agl",z,opts)

idbz=DBZ(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_conv=idbz
tmp_stra=idbz
tmp_total=idbz
tmp_conv=0
tmp_stra=0
tmp_total=0
do ii=0,29
  tmp_conv(:,ii,:,:)=where(idbz(:,0,:,:).gt.40,111.1,0)
  tmp_stra(:,ii,:,:)=where(idbz(:,0,:,:).ge.20.and.idbz(:,0,:,:).le.40,333.3,0)
  tmp_total(:,ii,:,:)=where(idbz(:,0,:,:).ge.20,111.1,0)
end do

n0tmp=N0(:,:,lat1s:lat2s,lon1s:lon2s)
lambtmp=LAMB(:,:,lat1s:lat2s,lon1s:lon2s)

n0_conv=where(tmp_conv.gt.40,n0tmp,0)
n0_conv!0="time"
n0_conv!1="level"
n0_conv&level=z

n0_trail=where(tmp_stra.ge.20.and.tmp_stra.le.40,n0tmp,0)
n0_trail!0="time"
n0_trail!1="level"
n0_trail&level=z

n0_total=where(tmp_total.ge.20,n0tmp,0)
n0_total!0="time"
n0_total!1="level"
n0_total&level=z

lamb_conv=where(tmp_conv.gt.40,lambtmp,0)
lamb_conv!0="time"
lamb_conv!1="level"
lamb_conv&level=z

lamb_trail=where(tmp_stra.ge.20.and.tmp_stra.le.40,lambtmp,0)
lamb_trail!0="time"
lamb_trail!1="level"
lamb_trail&level=z

lamb_total=where(tmp_total.ge.20,lambtmp,0)
lamb_total!0="time"
lamb_total!1="level"
lamb_total&level=z

outfile->MOR_H_n0_conv=n0_conv
outfile->MOR_H_n0_trail=n0_trail
outfile->MOR_H_n0_total=n0_total
outfile->MOR_H_lamb_conv=lamb_conv
outfile->MOR_H_lamb_trail=lamb_trail
outfile->MOR_H_lamb_total=lamb_total

print("MOR_H")





filelist=systemfunc("ls ./WDM6/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")

DBZ=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)

N0=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"RAIN_N0",-1),"ght_agl",z,opts)
LAMB=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"RAIN_LAMB",-1),"ght_agl",z,opts)

idbz=DBZ(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_conv=idbz
tmp_stra=idbz
tmp_total=idbz
tmp_conv=0
tmp_stra=0
tmp_total=0
do ii=0,29
  tmp_conv(:,ii,:,:)=where(idbz(:,0,:,:).gt.40,111.1,0)
  tmp_stra(:,ii,:,:)=where(idbz(:,0,:,:).ge.20.and.idbz(:,0,:,:).le.40,333.3,0)
  tmp_total(:,ii,:,:)=where(idbz(:,0,:,:).ge.20,111.1,0)
end do

n0tmp=N0(:,:,lat1s:lat2s,lon1s:lon2s)
lambtmp=LAMB(:,:,lat1s:lat2s,lon1s:lon2s)

n0_conv=where(tmp_conv.gt.40,n0tmp,0)
n0_conv!0="time"
n0_conv!1="level"
n0_conv&level=z

n0_trail=where(tmp_stra.ge.20.and.tmp_stra.le.40,n0tmp,0)
n0_trail!0="time"
n0_trail!1="level"
n0_trail&level=z

n0_total=where(tmp_total.ge.20,n0tmp,0)
n0_total!0="time"
n0_total!1="level"
n0_total&level=z

lamb_conv=where(tmp_conv.gt.40,lambtmp,0)
lamb_conv!0="time"
lamb_conv!1="level"
lamb_conv&level=z

lamb_trail=where(tmp_stra.ge.20.and.tmp_stra.le.40,lambtmp,0)
lamb_trail!0="time"
lamb_trail!1="level"
lamb_trail&level=z

lamb_total=where(tmp_total.ge.20,lambtmp,0)
lamb_total!0="time"
lamb_total!1="level"
lamb_total&level=z

outfile->WDM_n0_conv=n0_conv
outfile->WDM_n0_trail=n0_trail
outfile->WDM_n0_total=n0_total
outfile->WDM_lamb_conv=lamb_conv
outfile->WDM_lamb_trail=lamb_trail
outfile->WDM_lamb_total=lamb_total

print("WDM")



filelist=systemfunc("ls ./WDM6_H/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")

DBZ=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)

N0=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"RAIN_N0",-1),"ght_agl",z,opts)
LAMB=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"RAIN_LAMB",-1),"ght_agl",z,opts)

idbz=DBZ(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_conv=idbz
tmp_stra=idbz
tmp_total=idbz
tmp_conv=0
tmp_stra=0
tmp_total=0
do ii=0,29
  tmp_conv(:,ii,:,:)=where(idbz(:,0,:,:).gt.40,111.1,0)
  tmp_stra(:,ii,:,:)=where(idbz(:,0,:,:).ge.20.and.idbz(:,0,:,:).le.40,333.3,0)
  tmp_total(:,ii,:,:)=where(idbz(:,0,:,:).ge.20,111.1,0)
end do

n0tmp=N0(:,:,lat1s:lat2s,lon1s:lon2s)
lambtmp=LAMB(:,:,lat1s:lat2s,lon1s:lon2s)

n0_conv=where(tmp_conv.gt.40,n0tmp,0)
n0_conv!0="time"
n0_conv!1="level"
n0_conv&level=z

n0_trail=where(tmp_stra.ge.20.and.tmp_stra.le.40,n0tmp,0)
n0_trail!0="time"
n0_trail!1="level"
n0_trail&level=z

n0_total=where(tmp_total.ge.20,n0tmp,0)
n0_total!0="time"
n0_total!1="level"
n0_total&level=z

lamb_conv=where(tmp_conv.gt.40,lambtmp,0)
lamb_conv!0="time"
lamb_conv!1="level"
lamb_conv&level=z

lamb_trail=where(tmp_stra.ge.20.and.tmp_stra.le.40,lambtmp,0)
lamb_trail!0="time"
lamb_trail!1="level"
lamb_trail&level=z

lamb_total=where(tmp_total.ge.20,lambtmp,0)
lamb_total!0="time"
lamb_total!1="level"
lamb_total&level=z

outfile->WDMH_n0_conv=n0_conv
outfile->WDMH_n0_trail=n0_trail
outfile->WDMH_n0_total=n0_total
outfile->WDMH_lamb_conv=lamb_conv
outfile->WDMH_lamb_trail=lamb_trail
outfile->WDMH_lamb_total=lamb_total

print("WDM_H")



filelist=systemfunc("ls ./WSM6/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")

DBZ=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)

N0=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"RAIN_N0",-1),"ght_agl",z,opts)
LAMB=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"RAIN_LAMB",-1),"ght_agl",z,opts)

idbz=DBZ(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_conv=idbz
tmp_stra=idbz
tmp_total=idbz
tmp_conv=0
tmp_stra=0
tmp_total=0
do ii=0,29
  tmp_conv(:,ii,:,:)=where(idbz(:,0,:,:).gt.40,111.1,0)
  tmp_stra(:,ii,:,:)=where(idbz(:,0,:,:).ge.20.and.idbz(:,0,:,:).le.40,333.3,0)
  tmp_total(:,ii,:,:)=where(idbz(:,0,:,:).ge.20,111.1,0)
end do

n0tmp=N0(:,:,lat1s:lat2s,lon1s:lon2s)
lambtmp=LAMB(:,:,lat1s:lat2s,lon1s:lon2s)

n0_conv=where(tmp_conv.gt.40,n0tmp,0)
n0_conv!0="time"
n0_conv!1="level"
n0_conv&level=z

n0_trail=where(tmp_stra.ge.20.and.tmp_stra.le.40,n0tmp,0)
n0_trail!0="time"
n0_trail!1="level"
n0_trail&level=z

n0_total=where(tmp_total.ge.20,n0tmp,0)
n0_total!0="time"
n0_total!1="level"
n0_total&level=z

lamb_conv=where(tmp_conv.gt.40,lambtmp,0)
lamb_conv!0="time"
lamb_conv!1="level"
lamb_conv&level=z

lamb_trail=where(tmp_stra.ge.20.and.tmp_stra.le.40,lambtmp,0)
lamb_trail!0="time"
lamb_trail!1="level"
lamb_trail&level=z

lamb_total=where(tmp_total.ge.20,lambtmp,0)
lamb_total!0="time"
lamb_total!1="level"
lamb_total&level=z

outfile->WSM_n0_conv=n0_conv
outfile->WSM_n0_trail=n0_trail
outfile->WSM_n0_total=n0_total
outfile->WSM_lamb_conv=lamb_conv
outfile->WSM_lamb_trail=lamb_trail
outfile->WSM_lamb_total=lamb_total
print("WSM")
