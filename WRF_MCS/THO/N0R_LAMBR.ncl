load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "./wgamma.ncl"

rho_w = 1000.0
PI = 3.1415926536
am_r = PI*rho_w/6.0
bm_r = 3.0
obmr = 1./bm_r
mu_r = 0.0
cre2 = mu_r + 1.
cre3 = bm_r + mu_r + 1.
crg2 = wgamma(cre2)
crg3 = wgamma(cre3)
org2 = 1./crg2
org3=1./crg3
R1 = 1.E-12
R2 = 1.E-6   
r_d = 287.04
D0r = 50.E-6

wrffile=addfile("./wrfout/wrfout_d03_2014-05-22_06:00:00","r")
qr=wrf_user_getvar(wrffile,"QRAIN",-1)
nr=wrf_user_getvar(wrffile,"QNRAIN",-1)
P=wrf_user_getvar(wrffile,"pressure",-1)
T=wrf_user_getvar(wrffile,"tk",-1)
qv=wrf_user_getvar(wrffile,"QVAPOR",-1)
rho = 0.622*P/(r_d*T*(qv+0.622))
;rho=P/(r_d*T*(1+0.608*qv/(1+qv)))
;rho=P/(r_d*T)
;print(rho)

rr=qv
rr=0
lamr=qv
lamr=0

nlev=dimsizes(qv(0,:,0,0))
nlat=dimsizes(qv(0,0,:,0))
nlon=dimsizes(qv(0,0,0,:))

do jj=0,nlat-1
  do ii=0,nlon-1
    do zz=0,nlev-1
        if (qr(0,zz,jj,ii) .gt. R1) then 
           rr(0,zz,jj,ii) = qr(0,zz,jj,ii)*rho(0,zz,jj,ii)
           nr(0,zz,jj,ii) = max((/R2, nr(0,zz,jj,ii)*rho(0,zz,jj,ii)/))
           lamr(0,zz,jj,ii) = (am_r*crg3*org2*nr(0,zz,jj,ii)/rr(0,zz,jj,ii))^obmr
           mvd_r = (3.0 + mu_r + 0.672) / lamr(0,zz,jj,ii) 
           if (mvd_r .gt. 2.5E-3) then 
              mvd_r = 2.5E-3
              lamr(0,zz,jj,ii) = (3.0 + mu_r + 0.672) / mvd_r
              nr(0,zz,jj,ii) = crg2*org3*rr(0,zz,jj,ii)*lamr(0,zz,jj,ii)^bm_r / am_r 
           else
              if (mvd_r .lt. D0r*0.75) then 
                mvd_r = D0r*0.75
                lamr(0,zz,jj,ii) = (3.0 + mu_r + 0.672) / mvd_r
                nr(0,zz,jj,ii) = crg2*org3*rr(0,zz,jj,ii)*lamr(0,zz,jj,ii)^bm_r / am_r 
              end if
           end if
        else 
           qr(0,zz,jj,ii) = 0.0
           nr(0,zz,jj,ii) = 0.0
           rr(0,zz,jj,ii) = R1 
           nr(0,zz,jj,ii) = R2 
        end if
    end do
  end do
end do

N0_r = nr*org2*lamr^cre2

outfile=addfile("rainDSD.nc","c")
outfile->lamr=lamr
outfile->N0r=N0_r
