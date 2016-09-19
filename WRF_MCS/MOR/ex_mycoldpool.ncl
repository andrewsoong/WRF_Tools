load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$GEODIAG_ROOT/geodiag.ncl"

filelist=systemfunc("ls ./wrfout/wrfout_d03_*")
wrffiles=addfiles(filelist, "r")
;ListSetType (wrffiles, "join")
nt=145
nz=30
ny=354
nx=435

opts=True
opts@extrapolate=False
opts@field_type="T"
opts@time        = nt

zlev=fspan(0.1,3,30)
zlev@units="km"

ethorigin=wrf_user_getvar(wrffiles,"eth",-1)
eth_intrp = wrf_user_vert_interp(wrffiles,ethorigin,"ght_agl",zlev,opts)


setfileoption("nc","Format","LargeFile")
outfile= addfile("eth.nc","c")
outfile->eth=eth_intrp

