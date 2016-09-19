load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/time_axis_labels.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRF_contributed.ncl"
load "$GEODIAG_ROOT/geodiag.ncl"

scheme="WDM6"
thick=5

lat1s=150
lat2s=300
lon1s=150
lon2s=390

opts=True
opts@extrapolate=False
opts@field_type="ght"

z=fspan(0.1,18.0,30)
z@units="km"

filelist=systemfunc("ls ./wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")
times  = wrf_times_c(wrffiles[:]->Times,0)

T3D=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"tk",-1),"ght_agl",z,opts)
DBZ=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)

; LATENT HEAT OF VAPORATION
XLS          = 2.85E6
XLV          = 2.5E6
XLF          = 3.50E5
XLV0         = 3.15E6
XLV1         = 2370.
t0c = 273.15
xlcal = XLV0-XLV1*(T3D-t0c)

CLOUD_EVAP=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"CLOUD_EVAP",-1),"ght_agl",z,opts)
RAIN_EVAP=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"RAIN_EVAP",-1),"ght_agl",z,opts)
SNOW_MELT=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"SNOW_MELT",-1),"ght_agl",z,opts)
GRAUP_MELT=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"GRAUP_MELT",-1),"ght_agl",z,opts)

PRAUT=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"SNOW_MELT_EVAP",-1),"ght_agl",z,opts)
PRACW=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"GRAUP_MELT_EVAP",-1),"ght_agl",z,opts)

CLOUD_EVAP_ENERGY=CLOUD_EVAP*xlcal
RAIN_EVAP_ENERGY=RAIN_EVAP*xlcal
SNOW_MELT_ENERGY=SNOW_MELT*XLF
GRAUP_MELT_ENERGY=GRAUP_MELT*XLF

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

cloud_evap_energy=CLOUD_EVAP_ENERGY(:,:,lat1s:lat2s,lon1s:lon2s)
rain_evap_energy=RAIN_EVAP_ENERGY(:,:,lat1s:lat2s,lon1s:lon2s)
snow_melt_energy=SNOW_MELT_ENERGY(:,:,lat1s:lat2s,lon1s:lon2s)
graup_melt_energy=GRAUP_MELT_ENERGY(:,:,lat1s:lat2s,lon1s:lon2s)

praut=PRAUT(:,:,lat1s:lat2s,lon1s:lon2s)
pracw=PRACW(:,:,lat1s:lat2s,lon1s:lon2s)

cloud_evap_conv=where(tmp_conv.gt.40,cloud_evap_energy,0)
cloud_evap_conv!0="time"
cloud_evap_conv!1="level"
cloud_evap_conv&level=z

cloud_evap_trail=where(tmp_stra.ge.20.and.tmp_stra.le.40,cloud_evap_energy,0)
cloud_evap_trail!0="time"
cloud_evap_trail!1="level"
cloud_evap_trail&level=z

cloud_evap_total=where(tmp_total.ge.20,cloud_evap_energy,0)
cloud_evap_total!0="time"
cloud_evap_total!1="level"
cloud_evap_total&level=z

rain_evap_conv=where(tmp_conv.gt.40,rain_evap_energy,0)
rain_evap_conv!0="time"
rain_evap_conv!1="level"
rain_evap_conv&level=z

rain_evap_trail=where(tmp_stra.ge.20.and.tmp_stra.le.40,rain_evap_energy,0)
rain_evap_trail!0="time"
rain_evap_trail!1="level"
rain_evap_trail&level=z

rain_evap_total=where(tmp_total.ge.20,rain_evap_energy,0)
rain_evap_total!0="time"
rain_evap_total!1="level"
rain_evap_total&level=z

snow_melt_conv=where(tmp_conv.gt.40,snow_melt_energy,0)
snow_melt_conv!0="time"
snow_melt_conv!1="level"
snow_melt_conv&level=z

snow_melt_trail=where(tmp_stra.ge.20.and.tmp_stra.le.40,snow_melt_energy,0)
snow_melt_trail!0="time"
snow_melt_trail!1="level"
snow_melt_trail&level=z

snow_melt_total=where(tmp_total.ge.20,snow_melt_energy,0)
snow_melt_total!0="time"
snow_melt_total!1="level"
snow_melt_total&level=z

graup_melt_conv=where(tmp_conv.gt.40,graup_melt_energy,0)
graup_melt_conv!0="time"
graup_melt_conv!1="level"
graup_melt_conv&level=z

graup_melt_trail=where(tmp_stra.ge.20.and.tmp_stra.le.40,graup_melt_energy,0)
graup_melt_trail!0="time"
graup_melt_trail!1="level"
graup_melt_trail&level=z

graup_melt_total=where(tmp_total.ge.20,graup_melt_energy,0)
graup_melt_total!0="time"
graup_melt_total!1="level"
graup_melt_total&level=z

praut_total=where(tmp_total.ge.20,praut,0)
praut_total!0="time"
praut_total!1="level"
praut_total&level=z

pracw_total=where(tmp_total.ge.20,pracw,0)
pracw_total!0="time"
pracw_total!1="level"
pracw_total&level=z

outfile=addfile("energy.nc","c")

outfile->cloud_evap_conv=cloud_evap_conv
outfile->cloud_evap_trail=cloud_evap_trail
outfile->cloud_evap_total=cloud_evap_total

outfile->rain_evap_conv=rain_evap_conv
outfile->rain_evap_trail=rain_evap_trail
outfile->rain_evap_total=rain_evap_total

outfile->snow_melt_conv=snow_melt_conv
outfile->snow_melt_trail=snow_melt_trail
outfile->snow_melt_total=snow_melt_total

outfile->graup_melt_conv=graup_melt_conv
outfile->graup_melt_trail=graup_melt_trail
outfile->graup_melt_total=graup_melt_total

outfile->praut=praut
outfile->pracw=pracw
