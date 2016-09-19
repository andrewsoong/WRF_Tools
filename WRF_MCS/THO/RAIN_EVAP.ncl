load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$GEODIAG_ROOT/geodiag.ncl"
load "./cal.ncl"

opts=True
opts@extrapolate=False
opts@field_type="ght"

wrffile=addfile("./wrfout/wrfout_d03_2014-05-22_06:00:00","r")

eps = 1.E-15 
R1 = 1.E-12 
R2 = 1.E-6 
lvap0 = 2.5E6
Rv = 461.5
oRv = 1./Rv
mu_r = 0.0 
bv_r = 1.0 
fv_r = 195.0
R = 287.04  
Cp = 1004.0 
bm_r = 3.0  
obmr = 1./bm_r
PI = 3.1415926536  
av_r = 4854.0 
rho_w = 1000.0   
am_r = PI*rho_w/6.0   
D0r = 50.E-6

RHO_NOT = 101325.0/(287.05*298.0)

cre2 = mu_r + 1.
cre3 = bm_r + mu_r + 1.
cre10 = mu_r + 2.
cre11 = 0.5*(bv_r + 5. + 2.*mu_r)


crg3=wgamma(cre3)
crg10=wgamma(cre10)
crg11=wgamma(cre11)
crg2=wgamma(cre2)
org2 = 1./crg2 

Sc = 0.632
Sc3 = Sc^(1./3.) 

temp=wrf_user_getvar(wrffile,"tk",-1)
tempc=temp - 273.15 
pres=wrf_user_getvar(wrffile,"pressure",-1)*100.0
qv=wrf_user_getvar(wrffile,"QVAPOR",-1)
qr=wrf_user_getvar(wrffile,"QRAIN",-1)
qc=wrf_user_getvar(wrffile,"QCLOUD",-1)
nr=wrf_user_getvar(wrffile,"QNRAIN",-1)

nlev=2  ;dimsizes(qv(0,:,0,0))
nlat=2  ;dimsizes(qv(0,0,:,0))
nlon=2  ;dimsizes(qv(0,0,0,:))





do k = kts, kte
   if ( (ssatw(k).lt. -eps) .and. L_qr(k) .and. (.not.(prw_vcd(k).gt. 0.)) ) then 
    tempc = temp(k) - 273.15
    otemp = 1./temp(k)
    orho = 1./rho(k)
    rhof(k) = SQRT(RHO_NOT*orho)
    rhof2(k) = SQRT(rhof(k))
    diffu(k) = 2.11E-5*(temp(k)/273.15)^1.94 * (101325./pres(k))
    if (tempc .ge. 0.0) then 
       visco(k) = (1.718+0.0049*tempc)*1.0E-5
    else 
       visco(k) = (1.718+0.0049*tempc-1.2E-5*tempc*tempc)*1.0E-5
    end if
    vsc2(k) = SQRT(rho(k)/visco(k))
    lvap(k) = lvap0 + (2106.0 - 4218.0)*tempc
    tcond(k) = (5.69 + 0.0168*tempc)*1.0E-5 * 418.936
    ocp(k) = 1./(Cp*(1.+0.887*qv(k)))

    rvs = rho(k)*qvs(k)
    rvs_p = rvs*otemp*(lvap(k)*otemp*oRv - 1.)
    rvs_pp = rvs * ( otemp*(lvap(k)*otemp*oRv - 1.) \
                    *otemp*(lvap(k)*otemp*oRv - 1.) \
                    + (-2.*lvap(k)*otemp*otemp*otemp*oRv) \
                    + otemp*otemp)
    gamsc = lvap(k)*diffu(k)/tcond(k) * rvs_p
    alphsc = 0.5*(gamsc/(1.+gamsc))*(gamsc/(1.+gamsc)) \
               * rvs_pp/rvs_p * rvs/rvs_p
    alphsc = MAX(1.E-9, alphsc)
    xsat   = MIN(-1.E-9, ssatw(k))
    t1_evap = 2.*PI*( 1.0 - alphsc*xsat  \
           + 2.*alphsc*alphsc*xsat*xsat  \
           - 5.*alphsc*alphsc*alphsc*xsat*xsat*xsat ) \
           / (1.+gamsc)

    lamr = 1./ilamr(k)
    if (qv(k)/qvs(k) .lt. 0.95 .AND. rr(k)*orho.le.1.E-8) then
    prv_rev(k) = rr(k)*orho*odts
    else
    prv_rev(k) = t1_evap*diffu(k)*(-ssatw(k))*N0_r(k)*rvs \
        * (t1_qr_ev*ilamr(k)^cre(10) \
        + t2_qr_ev*vsc2(k)*rhof2(k)*((lamr+0.5*fv_r)^(-cre(11))))
    rate_max = MIN((rr(k)*orho*odts), (qvs(k)-qv(k))*odts)
    prv_rev(k) = MIN(DBLE(rate_max), prv_rev(k)*orho)
 end do










