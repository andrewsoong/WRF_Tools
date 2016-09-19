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
GRAUP_VT=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"GRAUP_VT",-1),"ght_agl",z,opts)

filelist=systemfunc("ls ./MOR_H/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")
DBZ_H=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)
GRAUP_VT_H=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"GRAUP_VT",-1),"ght_agl",z,opts)

filelist=systemfunc("ls ./WDM6/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")
DBZ_WDM=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)
GRAUP_VT_WDM=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"GRAUP_VT",-1),"ght_agl",z,opts)

filelist=systemfunc("ls ./WDM6_H/wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist(96:120), "r")
DBZ_H_WDM=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"dbz",-1),"ght_agl",z,opts)
GRAUP_VT_H_WDM=wrf_user_vert_interp(wrffiles,wrf_user_getvar(wrffiles,"GRAUP_VT",-1),"ght_agl",z,opts)



idbz=DBZ(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_total=idbz
tmp_total=0

idbz_H=DBZ_H(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_total_H=idbz_H
tmp_total_H=0

idbz_WDM=DBZ_WDM(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_total_WDM=idbz_WDM
tmp_total_WDM=0

idbz_H_WDM=DBZ_H_WDM(:,:,lat1s:lat2s,lon1s:lon2s)
tmp_total_H_WDM=idbz_H_WDM
tmp_total_H_WDM=0


do ii=0,29
  tmp_total(:,ii,:,:)=where(idbz(:,0,:,:).ge.20,111.1,0)
  tmp_total_H(:,ii,:,:)=where(idbz_H(:,0,:,:).ge.20,111.1,0)
  tmp_total_WDM(:,ii,:,:)=where(idbz_WDM(:,0,:,:).ge.20,111.1,0)
  tmp_total_H_WDM(:,ii,:,:)=where(idbz_H_WDM(:,0,:,:).ge.20,111.1,0)
end do

GRAUP_VT_tmp=GRAUP_VT(:,:,lat1s:lat2s,lon1s:lon2s)
GRAUP_VT_H_tmp=GRAUP_VT_H(:,:,lat1s:lat2s,lon1s:lon2s)
GRAUP_VT_WDM_tmp=GRAUP_VT_WDM(:,:,lat1s:lat2s,lon1s:lon2s)
GRAUP_VT_H_WDM_tmp=GRAUP_VT_H_WDM(:,:,lat1s:lat2s,lon1s:lon2s)

graupel_vt_total=where(tmp_total.ge.20,GRAUP_VT_tmp,0)
graupel_vt_total!0="time"
graupel_vt_total!1="level"
graupel_vt_total&level=z

graupel_vt_h_total=where(tmp_total_H.ge.20,GRAUP_VT_H_tmp,0)
graupel_vt_h_total!0="time"
graupel_vt_h_total!1="level"
graupel_vt_h_total&level=z

graupel_vt_wdm_total=where(tmp_total_WDM.ge.20,GRAUP_VT_WDM_tmp,0)
graupel_vt_wdm_total!0="time"
graupel_vt_wdm_total!1="level"
graupel_vt_wdm_total&level=z

graupel_vt_h_wdm_total=where(tmp_total_H_WDM.ge.20,GRAUP_VT_H_tmp,0)
graupel_vt_h_wdm_total!0="time"
graupel_vt_h_wdm_total!1="level"
graupel_vt_h_wdm_total&level=z





print(dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(graupel_vt_total,3),2),0))
print(dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(graupel_vt_h_total,3),2),0))
print(dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(graupel_vt_wdm_total,3),2),0))
print(dim_avg_n_Wrap(dim_avg_n_Wrap(dim_avg_n_Wrap(graupel_vt_h_wdm_total,3),2),0))


setfileoption("nc","Format","LargeFile")
outfile=addfile("VT_HG.nc","c")
outfile->graupel_vt_mor=graupel_vt_total
outfile->hail_vt_mor=graupel_vt_h_total
outfile->graupel_vt_wdm=graupel_vt_wdm_total
outfile->hail_vt_wdm=graupel_vt_h_wdm_total











