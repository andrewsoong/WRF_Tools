load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/time_axis_labels.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRF_contributed.ncl"
load "$GEODIAG_ROOT/geodiag.ncl"

MORfile=addfile("./MOR/energy.nc","r")
MORHfile=addfile("./MOR_H/energy.nc","r")
WSMfile=addfile("./WSM6/energy.nc","r")
WDMfile=addfile("./WDM6/energy.nc","r")
WDMHfile=addfile("./WDM6_H/energy.nc","r")

MOR_cloud_evap         =  MORfile->cloud_evap_total
MOR_rain_evap          =  MORfile->rain_evap_total
MOR_snow_melt          =  MORfile->snow_melt_total
MOR_graup_melt         =  MORfile->graup_melt_total
MOR_snow_melt_evap     =  MORfile->snow_melt_evap_total
MOR_graup_melt_evap    =  MORfile->graup_melt_evap_total

MORH_cloud_evap        =  MORHfile->cloud_evap_total
MORH_rain_evap         =  MORHfile->rain_evap_total
MORH_snow_melt         =  MORHfile->snow_melt_total
MORH_graup_melt        =  MORHfile->graup_melt_total
MORH_snow_melt_evap    =  MORHfile->snow_melt_evap_total
MORH_graup_melt_evap   =  MORHfile->graup_melt_evap_total

WSM_cloud_evap         =   WSMfile->cloud_evap_total
WSM_rain_evap          =   WSMfile->rain_evap_total
WSM_snow_melt          =   WSMfile->snow_melt_total
WSM_graup_melt         =   WSMfile->graup_melt_total
WSM_praut              =   WSMfile->praut
WSM_pracw              =   WSMfile->pracw

WDM_cloud_evap         =   WDMfile->cloud_evap_total
WDM_rain_evap          =   WDMfile->rain_evap_total
WDM_snow_melt          =   WDMfile->snow_melt_total
WDM_graup_melt         =   WDMfile->graup_melt_total
WDM_praut              =   WDMfile->praut
WDM_pracw              =   WDMfile->pracw

WDMH_cloud_evap        =  WDMHfile->cloud_evap_total
WDMH_rain_evap         =  WDMHfile->rain_evap_total
WDMH_snow_melt         =  WDMHfile->snow_melt_total
WDMH_graup_melt        =  WDMHfile->graup_melt_total
WDMH_praut             =  WDMHfile->praut
WDMH_pracw             =  WDMHfile->pracw

MOR_cloud_evap         =  where(MOR_cloud_evap.le.0,MOR_cloud_evap,0)
MOR_rain_evap          =  where(MOR_rain_evap.le.0,MOR_rain_evap,0)
MOR_snow_melt          =  where(MOR_snow_melt.gt.0,0,MOR_snow_melt)
MOR_snow_melt          =  where(MOR_snow_melt.lt.-20,0,MOR_snow_melt)
MOR_graup_melt         =  where(MOR_graup_melt.gt.0,0,MOR_graup_melt)
MOR_graup_melt         =  where(MOR_graup_melt.lt.-20,0,MOR_graup_melt)
MOR_snow_melt_evap     =  where(MOR_snow_melt_evap.gt.0,0,MOR_snow_melt_evap)
MOR_snow_melt_evap     =  where(MOR_snow_melt_evap.lt.-20,0,MOR_snow_melt_evap)
MOR_graup_melt_evap    =  where(MOR_graup_melt_evap.gt.0,0,MOR_graup_melt_evap)
MOR_graup_melt_evap    =  where(MOR_graup_melt_evap.lt.-20,0,MOR_graup_melt_evap)

MORH_cloud_evap         =  where(MORH_cloud_evap.le.0,MORH_cloud_evap,0)
MORH_cloud_evap         =  where(MORH_cloud_evap.lt.-20,0,MORH_cloud_evap)
MORH_rain_evap          =  where(MORH_rain_evap.le.0,MORH_rain_evap,0)
MORH_snow_melt          =  where(MORH_snow_melt.gt.0,0,MORH_snow_melt)
MORH_snow_melt          =  where(MORH_snow_melt.lt.-20,0,MORH_snow_melt)
MORH_graup_melt         =  where(MORH_graup_melt.gt.0,0,MORH_graup_melt)
MORH_graup_melt         =  where(MORH_graup_melt.lt.-20,0,MORH_graup_melt)
MORH_snow_melt_evap     =  where(MORH_snow_melt_evap.gt.0,0,MORH_snow_melt_evap)
MORH_snow_melt_evap     =  where(MORH_snow_melt_evap.lt.-20,0,MORH_snow_melt_evap)
MORH_graup_melt_evap    =  where(MORH_graup_melt_evap.gt.0,0,MORH_graup_melt_evap)
MORH_graup_melt_evap    =  where(MORH_graup_melt_evap.lt.-10,0,MORH_graup_melt_evap)

WSM_cloud_evap         =  where(WSM_cloud_evap.le.0,WSM_cloud_evap,0)
WSM_cloud_evap         =  where(WSM_cloud_evap.lt.-10,0,WSM_cloud_evap)
WSM_rain_evap          =  where(WSM_rain_evap.le.0,WSM_rain_evap,0)
WSM_snow_melt          =  where(WSM_snow_melt.gt.0,0,WSM_snow_melt)
WSM_snow_melt          =  where(WSM_snow_melt.lt.-10,0,WSM_snow_melt)
WSM_graup_melt         =  where(WSM_graup_melt.gt.0,0,WSM_graup_melt)
WSM_graup_melt         =  where(WSM_graup_melt.lt.-10,0,WSM_graup_melt)

WDM_cloud_evap         =  where(WDM_cloud_evap.le.0,WDM_cloud_evap,0)
WDM_cloud_evap         =  where(WDM_cloud_evap.lt.-10,0,WDM_cloud_evap)
WDM_rain_evap          =  where(WDM_rain_evap.le.0,WDM_rain_evap,0)
WDM_rain_evap          =  where(WDM_rain_evap.lt.-10,0,WDM_rain_evap)
WDM_snow_melt          =  where(WDM_snow_melt.gt.0,0,WDM_snow_melt)
WDM_snow_melt          =  where(WDM_snow_melt.lt.-10,0,WDM_snow_melt)
WDM_graup_melt         =  where(WDM_graup_melt.gt.0,0,WDM_graup_melt)
WDM_graup_melt         =  where(WDM_graup_melt.lt.-10,0,WDM_graup_melt)

WDMH_cloud_evap         =  where(WDMH_cloud_evap.le.0,WDMH_cloud_evap,0)
WDMH_cloud_evap         =  where(WDMH_cloud_evap.lt.-10,0,WDMH_cloud_evap)
WDMH_rain_evap          =  where(WDMH_rain_evap.le.0,WDMH_rain_evap,0)
WDMH_rain_evap          =  where(WDMH_rain_evap.lt.-20,0,WDMH_rain_evap)
WDMH_snow_melt          =  where(WDMH_snow_melt.gt.0,0,WDMH_snow_melt)
WDMH_snow_melt          =  where(WDMH_snow_melt.lt.-20,0,WDMH_snow_melt)
WDMH_graup_melt         =  where(WDMH_graup_melt.gt.0,0,WDMH_graup_melt)
WDMH_graup_melt         =  where(WDMH_graup_melt.lt.-20,0,WDMH_graup_melt)

setfileoption("nc","Format","LargeFile")
outfile=addfile("energy_all.nc","c")
outfile->MOR_cloud_evap=MOR_cloud_evap
outfile->MOR_rain_evap=MOR_rain_evap
outfile->MOR_snow_melt=MOR_snow_melt
outfile->MOR_graup_melt=MOR_graup_melt
outfile->MOR_snow_melt_evap=MOR_snow_melt_evap
outfile->MOR_graup_melt_evap=MOR_graup_melt_evap
outfile->MORH_cloud_evap=MORH_cloud_evap
outfile->MORH_rain_evap=MORH_rain_evap
outfile->MORH_snow_melt=MORH_snow_melt
outfile->MORH_graup_melt=MORH_graup_melt
outfile->MORH_snow_melt_evap=MORH_snow_melt_evap
outfile->MORH_graup_melt_evap=MORH_graup_melt_evap
outfile->WSM_cloud_evap=WSM_cloud_evap
outfile->WSM_rain_evap=WSM_rain_evap
outfile->WSM_snow_melt=WSM_snow_melt
outfile->WSM_graup_melt=WSM_graup_melt
outfile->WDM_cloud_evap=WDM_cloud_evap
outfile->WDM_rain_evap=WDM_rain_evap
outfile->WDM_snow_melt=WDM_snow_melt
outfile->WDM_graup_melt=WDM_graup_melt
outfile->WDMH_cloud_evap=WDMH_cloud_evap
outfile->WDMH_rain_evap=WDMH_rain_evap
outfile->WDMH_snow_melt=WDMH_snow_melt
outfile->WDMH_graup_melt=WDMH_graup_melt
outfile->WSM_praut=WSM_praut
outfile->WSM_pracw=WSM_pracw
outfile->WDM_praut=WDM_praut
outfile->WDM_pracw=WDM_pracw
outfile->WDMH_praut=WDMH_praut
outfile->WDMH_pracw=WDMH_pracw
