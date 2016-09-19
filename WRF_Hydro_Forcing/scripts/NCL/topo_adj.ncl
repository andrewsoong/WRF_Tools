;-------------------------
; topo_adj.ncl
;
; Project : NWC IOC
;
; Usage : ncl 'inputGeo="geo_sta.nc"' 
;             'outFile="temp_corr.nc"' topo_adj.ncl
; email: lpan@ucar.edu
;
; The outFile is actually the file containing the
; Short wave radiation data which is to be downscaled.  
; The file is overwritten with the downscaled SWDOWN
; values.
;
;------------------------
;!!!!!WARNING!!!!!
;Cannot hard-code the location of the executable when used 
;in an operational environment. 
; In the wrf_hydro_forcing.parm file, indicate where all
; shared objects should reside. 
;external TOPO_ADJF90 "$HOME/HYDRO/REGRID/DOWN/topo_adjf90.so"

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRF_contributed.ncl"
;==============================================================================;
; 0. Define function
;==============================================================================;
  ;-------------------------------------------------------------
  ; 0.0 Load useful ncl scripts
  ;-------------------------------------------------------------
  load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
  load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
 ; load "/opt/ncl_ncarg-5.1.1-pgi/lib/ncarg/nclscripts/csm/contributed.ncl"
;  load "$CSH_ARCHIVE/ncl/WRFUserARW.ncl"
  load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"

  function sub_string_double(s:string,i:integer,j:integer)
  begin
     s_char = stringtochar(s)

     sub_str = s_char(i:j)
     return (stringtodouble(chartostring(sub_str)))
  end
function sub_string_float(s:string,i:integer,j:integer)
begin
  s_char = stringtochar(s)

  sub_str = s_char(i:j)

  return (stringtofloat(chartostring(sub_str)))
end

 
begin
;
; Calculate three values of a quadratic equation
;
; input files
        ; The inputGeo and outFile values will be 
        ; defined in the forcing engine parm/config 
        ; file.  Setting an environment variable 
        ; will not be an accepted practice in 
        ; an operational environment.
	;inputGeo = getenv("inputGeo")
	;outFile = getenv("outFile")
        f1 = addfile(inputGeo,"r")
; out files
        fout = addfile(outFile,"w")
	hgt = f1->HGT_M(0,:,:)
	xlat = f1->XLAT_M(0,:,:)
	xlong = f1->XLONG_M(0,:,:)
	swdown_in=fout->SWDOWN(:,:)
	dx = f1@DX
	dy = f1@DY
	nsizes=dimsizes(hgt)
	print(nsizes)
	printVarSummary(hgt)
	nx=nsizes(1)
	ny=nsizes(0)
	cosa = f1->COSALPHA(0,:,:)
	sina = f1->SINALPHA(0,:,:)
	swdown_out=swdown_in*0.

       ss=outFile
       yyyy=floattointeger(sub_string_float(ss,0,3))
       mon=floattointeger(sub_string_float(ss,4,5))
       dd=floattointeger(sub_string_float(ss,6,7))
       hh=floattointeger(sub_string_float(ss,8,9))
       xtime = hh*60.

       yyyy@calendar = "julian"
       julian = day_of_year(yyyy,mon,dd)
       print(julian)
	print(xtime)
   ; Do NOT use the TOPO_ADJF90:: topo_adj syntax, now that we are defining
   ; a single directory where ALL shared objects should reside.
   ;TOPO_ADJF90:: topo_adj(hgt,xlat,xlong,dx,dy,nx,ny,cosa, sina, xtime, julian,swdown_in, swdown_out)
   topo_adj(hgt,xlat,xlong,dx,dy,nx,ny,cosa, sina, xtime, julian,swdown_in, swdown_out)

	fout->SWDOWN=swdown_out

;   EX01::cquad(-1., 2., 3., nump, x, qval) ; Call the NCL version of
                                           ; your Fortran subroutine.
end


