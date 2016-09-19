load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/time_axis_labels.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRF_contributed.ncl"
load "$GEODIAG_ROOT/geodiag.ncl"

cor=new(7,"float")
rmse=new(7,"float")
names=(/"LIN","MOR","MOR_H","THO","WDM6","WDM6_H","WSM6"/)
flag=1

obsfile=addfile("PRE.nc","r")
obs=obsfile->PRE
lat=obsfile->lat
lon=obsfile->lon
delete(obs@_FillValue)
obs=where(obs.le.5,0,obs)
obs=where(obs.eq.9.96921e+36,0,obs)

wrff1=addfile("./LIN/wrfout/wrfout_d03_2014-05-22_04:00:00","r")
wrff2=addfile("./LIN/wrfout/wrfout_d03_2014-05-22_08:00:00","r")
lat2d=wrff1->XLAT(0,:,:)
lon2d=wrff1->XLONG(0,:,:)
rainnc1 = wrf_user_getvar(wrff1,"RAINNC",-1)
rainc1 = wrf_user_getvar(wrff1,"RAINC",-1)
tmp1=rainnc1+rainc1
rainnc2 = wrf_user_getvar(wrff2,"RAINNC",-1)
rainc2 = wrf_user_getvar(wrff2,"RAINC",-1)
tmp2=rainnc2+rainc2
total_rain=tmp2(0,:,:)-tmp1(0,:,:)

linpre=rcm2rgrid_Wrap(lat2d,lon2d,total_rain,lat,lon,1)
linpre=where(linpre.le.5,0,linpre)
cor(0)=pattern_cor(obs,linpre,1.0,flag)
rmse(0)=wgt_arearmse(obs,linpre,1.0,1.0,0)

print("aa")


wrff1=addfile("./MOR/wrfout/wrfout_d03_2014-05-22_04:00:00","r")
wrff2=addfile("./MOR/wrfout/wrfout_d03_2014-05-22_08:00:00","r")
lat2d=wrff1->XLAT(0,:,:)
lon2d=wrff1->XLONG(0,:,:)
rainnc1 = wrf_user_getvar(wrff1,"RAINNC",-1)
rainc1 = wrf_user_getvar(wrff1,"RAINC",-1)
tmp1=rainnc1+rainc1
rainnc2 = wrf_user_getvar(wrff2,"RAINNC",-1)
rainc2 = wrf_user_getvar(wrff2,"RAINC",-1)
tmp2=rainnc2+rainc2
total_rain=tmp2(0,:,:)-tmp1(0,:,:)

morpre=rcm2rgrid_Wrap(lat2d,lon2d,total_rain,lat,lon,1)
morpre=where(morpre.le.5,0,morpre)
cor(1)=pattern_cor(obs,morpre,1.0,flag)
rmse(1)=wgt_arearmse(obs,morpre,1.0,1.0,0)   

print("aa")    

wrff1=addfile("./MOR_H/wrfout/wrfout_d03_2014-05-22_04:00:00","r")
wrff2=addfile("./MOR_H/wrfout/wrfout_d03_2014-05-22_08:00:00","r")
lat2d=wrff1->XLAT(0,:,:)
lon2d=wrff1->XLONG(0,:,:)
rainnc1 = wrf_user_getvar(wrff1,"RAINNC",-1)
rainc1 = wrf_user_getvar(wrff1,"RAINC",-1)
tmp1=rainnc1+rainc1
rainnc2 = wrf_user_getvar(wrff2,"RAINNC",-1)
rainc2 = wrf_user_getvar(wrff2,"RAINC",-1)
tmp2=rainnc2+rainc2
total_rain=tmp2(0,:,:)-tmp1(0,:,:)

morhpre=rcm2rgrid_Wrap(lat2d,lon2d,total_rain,lat,lon,1)
morhpre=where(morhpre.le.5,0,morhpre)
cor(2)=pattern_cor(obs,morhpre,1.0,flag)
rmse(2)=wgt_arearmse(obs,morhpre,1.0,1.0,0)   

print("aa")    


wrff1=addfile("./THO/wrfout/wrfout_d03_2014-05-22_04:00:00","r")
wrff2=addfile("./THO/wrfout/wrfout_d03_2014-05-22_08:00:00","r")
lat2d=wrff1->XLAT(0,:,:)
lon2d=wrff1->XLONG(0,:,:)
rainnc1 = wrf_user_getvar(wrff1,"RAINNC",-1)
rainc1 = wrf_user_getvar(wrff1,"RAINC",-1)
tmp1=rainnc1+rainc1
rainnc2 = wrf_user_getvar(wrff2,"RAINNC",-1)
rainc2 = wrf_user_getvar(wrff2,"RAINC",-1)
tmp2=rainnc2+rainc2
total_rain=tmp2(0,:,:)-tmp1(0,:,:)

thopre=rcm2rgrid_Wrap(lat2d,lon2d,total_rain,lat,lon,1)
thopre=where(thopre.le.5,0,thopre)
cor(3)=pattern_cor(obs,thopre,1.0,flag)
rmse(3)=wgt_arearmse(obs,thopre,1.0,1.0,0)   

print("aa")    



wrff1=addfile("./WDM6/wrfout/wrfout_d03_2014-05-22_04:00:00","r")
wrff2=addfile("./WDM6/wrfout/wrfout_d03_2014-05-22_08:00:00","r")
lat2d=wrff1->XLAT(0,:,:)
lon2d=wrff1->XLONG(0,:,:)
rainnc1 = wrf_user_getvar(wrff1,"RAINNC",-1)
rainc1 = wrf_user_getvar(wrff1,"RAINC",-1)
tmp1=rainnc1+rainc1
rainnc2 = wrf_user_getvar(wrff2,"RAINNC",-1)
rainc2 = wrf_user_getvar(wrff2,"RAINC",-1)
tmp2=rainnc2+rainc2
total_rain=tmp2(0,:,:)-tmp1(0,:,:)

wdmpre=rcm2rgrid_Wrap(lat2d,lon2d,total_rain,lat,lon,1)
wdmpre=where(wdmpre.le.5,0,wdmpre)
cor(4)=pattern_cor(obs,wdmpre,1.0,flag)
rmse(4)=wgt_arearmse(obs,wdmpre,1.0,1.0,0)   

print("aa")    



wrff1=addfile("./WDM6_H/wrfout/wrfout_d03_2014-05-22_04:00:00","r")
wrff2=addfile("./WDM6_H/wrfout/wrfout_d03_2014-05-22_08:00:00","r")
lat2d=wrff1->XLAT(0,:,:)
lon2d=wrff1->XLONG(0,:,:)
rainnc1 = wrf_user_getvar(wrff1,"RAINNC",-1)
rainc1 = wrf_user_getvar(wrff1,"RAINC",-1)
tmp1=rainnc1+rainc1
rainnc2 = wrf_user_getvar(wrff2,"RAINNC",-1)
rainc2 = wrf_user_getvar(wrff2,"RAINC",-1)
tmp2=rainnc2+rainc2
total_rain=tmp2(0,:,:)-tmp1(0,:,:)

wdmhpre=rcm2rgrid_Wrap(lat2d,lon2d,total_rain,lat,lon,1)
wdmhpre=where(wdmhpre.le.5,0,wdmhpre)
cor(5)=pattern_cor(obs,wdmhpre,1.0,flag)
rmse(5)=wgt_arearmse(obs,wdmhpre,1.0,1.0,0)   

print("aa")    


wrff1=addfile("./WSM6/wrfout/wrfout_d03_2014-05-22_04:00:00","r")
wrff2=addfile("./WSM6/wrfout/wrfout_d03_2014-05-22_08:00:00","r")
lat2d=wrff1->XLAT(0,:,:)
lon2d=wrff1->XLONG(0,:,:)
rainnc1 = wrf_user_getvar(wrff1,"RAINNC",-1)
rainc1 = wrf_user_getvar(wrff1,"RAINC",-1)
tmp1=rainnc1+rainc1
rainnc2 = wrf_user_getvar(wrff2,"RAINNC",-1)
rainc2 = wrf_user_getvar(wrff2,"RAINC",-1)
tmp2=rainnc2+rainc2
total_rain=tmp2(0,:,:)-tmp1(0,:,:)

wsmpre=rcm2rgrid_Wrap(lat2d,lon2d,total_rain,lat,lon,1)
wsmpre=where(wsmpre.le.5,0,wsmpre)
cor(6)=pattern_cor(obs,wsmpre,1.0,flag)
rmse(6)=wgt_arearmse(obs,wsmpre,1.0,1.0,0)   

print(cor)
print(names)
print(rmse)



out=addfile("pre_cor.nc","c")
out->obs=obs
out->linpre=linpre
out->morpre=morpre
out->morhpre=morhpre
out->thopre=thopre
out->wdmpre=wdmpre
out->wdmhpre=wdmhpre
out->wsmpre=wsmpre
out->cor=cor
out->rmse=rmse
