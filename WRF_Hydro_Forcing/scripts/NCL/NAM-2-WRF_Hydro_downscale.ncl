;----------------------------------------------------------------------
; NAM-2-WRF_Hydro_downscale.ncl 
;
; Project : NWC IOC
;
; Purpose : This is a ncl program to perform height correction
;
;
; Usage   : ncl 'input1="file_to_be_downscaled.nc"' 'input2="hgt2.nc"' \
;               'input3="geo_file.nc"' 'output="temp_corr.nc"' \
;                NAM-2-WRF_Hydro_downscale.ncl
;
;
; lpan@ucar.edu 24 June 2015
;
;----------------------------------------------------------------------

begin
           ; For Operational use, we no longer set these 
           ; environment variables, these are obtained from 
           ; a parm/config file.
           ;inputFile1 = getenv("inputFile1") ; input NAM data
           ;inputFile2 = getenv("inputFile2") ; input GEO data
           ;inputFile3 = getenv("inputFile3") ; input NAM data
           ;outFile = getenv("outFile") ; outFile data
           
; input files 
           f1 = addfile(inputFile1,"r") 
           f2 = addfile(inputFile2,"r") 
           f3 = addfile(inputFile3,"r") 
; out files
           fout = addfile(outFile,"c")
;
	  if( isfilepresent("lapse.nc") )then
	    ff = addfile("lapse.nc","r")
	     lapse = ff->lapse
	    print("Using narr lapse rate")
	  else
	     lapse = 6.49
	    print("Using constant lapse rate")
	  end if
; input variables
           HGT1 = f1->HGT
           HGT2 = f2->HGT_M(0,:,:)
           T2D  = f3->T2D
           Q2D  = f3->Q2D
	   PSFC = f3->PSFC
; calculation 
	   W2D  = Q2D/(1-Q2D)
	   RH = relhum(T2D,W2D,PSFC)
	   RH = RH < 100
	   DHGT  = HGT1-HGT2
	   T2D=T2D+DHGT*lapse/1000.
	   PSFC = PSFC+DHGT*PSFC/287.05/T2D*9.8
	   Q2D = mixhum_ptrh (PSFC/100., T2D, RH, 2) 
; output
           fout->T2D  = T2D
           fout->Q2D  = Q2D
           fout->PSFC = PSFC 
	   delete(T2D)
;

end
