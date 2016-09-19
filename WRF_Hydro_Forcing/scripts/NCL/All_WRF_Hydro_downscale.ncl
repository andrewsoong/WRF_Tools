;----------------------------------------------------------------------
; WRF_Hydro_downscale.ncl 
;
; Project : NWC IOC
;
; Purpose : This is a ncl program to perform height correction
;
;
; Usage   : ncl 'input1="hgt.nc"' 'input2="geo_file.nc"' \
;               'input3="file_to_downscale.nc"' 'output="downscaled_data_output.nc"' \
;                HRRR-2-WRF_Hydro_downscale.ncl
;
;
; lpan@ucar.edu 24 June 2015
;
;----------------------------------------------------------------------

begin
           ; For Operational use, these are defined in 
           ; a parm/config file of the forcing engine.
           ;inputFile1 = getenv("inputFile1") ; hgt
           ;inputFile2 = getenv("inputFile2") ; geo data
           ;inputFile3 = getenv("inputFile3") ; data to downscale
           ;outFile = getenv("outFile") ; outFile data
           
; input files 
           f1 = addfile(inputFile1,"r") 
           f2 = addfile(inputFile2,"r") 
           f3 = addfile(inputFile3,"r") 
; out files
           fout = addfile(outFile,"c")
;
	  ;if( isfilepresent("lapse.nc") )then
          ; The lapseFile is obtained from the 
          ; parm/config file of the forcing engine. 
	  if( isfilepresent(lapseFile) )then
	    ;ff = addfile("lapse.nc","r")
	    ff = addfile(lapseFile,"r")
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
           U2D  = f3->U2D
           V2D  = f3->V2D
           RAINRATE = f3->RAINRATE
           SWDOWN = f3->SWDOWN
           LWDOWN = f3->LWDOWN
; calculation 
	   W2D  = Q2D/(1-Q2D)
	   RH = relhum(T2D,W2D,PSFC)
	   RH = RH < 100
	   DHGT  = HGT1-HGT2
	   T2D=T2D+DHGT*lapse/1000.
	   PSFC = PSFC+DHGT*PSFC/287.05/T2D*9.8
	   Q2D = mixhum_ptrh (PSFC/100., T2D, RH, 2) 
; output
; include the other variables: SWDOWN, LWDOWN, RAINRATE,
; U2D, and V2D
           fout->T2D  = T2D
           fout->Q2D  = Q2D
           fout->U2D  = U2D
           fout->V2D  = V2D
           fout->PSFC = PSFC 
           fout->RAINRATE = RAINRATE
           fout->SWDOWN = SWDOWN
           fout->LWDOWN = LWDOWN
	   delete(T2D)
;

end
