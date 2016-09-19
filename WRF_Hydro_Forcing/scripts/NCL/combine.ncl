;
; Performs the combining/layering of two data products (HRRR and RAP) 
; for WRF-Hydro Analysis and Assimilation Forcing Configuration.
;
; Input: 
;      hrrrFile    The first data source, currently HRRR model data
;      rapFile    The second data source, currently RAP model data
;      outFile     The full path to the output file, containing the
;                          mixed HRRR and RAP data.
;      indexFlag           Set to "false" for the initial run, to 
;                          create an index.nc file. Run this script
;                          for second time with indexFlag set to
;                          "true", to do the actual layering/
;                          combining.  
;
; Output:
;     Creates an output file indicated by the outFile variable by combining/ 
;     layering HRRR and RAP data.     


begin
           ; These values are defined in the wrf_hydro_forcing.parm parameter/config file, 
           ; they are no longer set as environment variables.
           ;setenv hrrrFile /d4/hydro-dm/IOC/test/HRRR/20150813/i000/20150812_i00_f001_HRRR.nc
           ;setenv rapFile /d4/hydro-dm/IOC/test/RAP/20150813/i17/20150813_i17_f000_RAP.nc
           ;setenv INDEX true
           ;setenv outFile /d4/hydro-dm/IOC/layering/analysis_assimilation/20150812_HRRR_RAP.nc
           ;setenv outDir /d4/hydro-dm/IOC/layering/analysis_assimilation
           ;hrrrFile = getenv("hrrrFile") ; HRRR data
           ;rapFile = getenv("rapFile") ; RAP data
           ;outFile = getenv("outFile") ; outFile data
           ;indexFlag = getenv("INDEX")

          
           print( "hrrFile: " + hrrrFile)
           print( "rapFile: " + rapFile)
           print( "indexFlag: " + indexFlag)
           print( "outfile: " + outFile)
           
           if(indexFlag .eq. "true") then
              indexf = addfile( "index.nc","r") 
              index = indexf->index
           end if
     
           f1 = addfile(hrrrFile,"r") 
           f2 = addfile(rapFile,"r") 
           system("rm -rf "+outFile)

           fout = addfile(outFile,"c")

           dd = dimsizes(f1->T2D)
            print("dd="+dd)
           dimlat = dd(0)
           dimlon = dd(1)



           v1d = ndtooned(f1->T2D)
           if(indexFlag .eq. "false") then
               findexOut = addfile("index_out.nc","c")
               index = ind(ismissing(v1d) )
               findexOut->index = index
               system("mv index_out.nc index.nc")
               exit 
           end if
           v1dgfs = ndtooned(f2->T2D)
           v1d(index) = v1dgfs(index)
           T2D = onedtond(v1d,(/dimlat,dimlon/))
           fout->T2D = T2D

; Downward long wave radiation using GFS.
           v1d = ndtooned(f2->LWDOWN)
           LWDOWN = onedtond(v1d,(/dimlat,dimlon/))
           fout->LWDOWN = LWDOWN

           v1d = ndtooned(f1->Q2D)
           v1dgfs = ndtooned(f2->Q2D)
           v1d(index) = v1dgfs(index)
           Q2D = onedtond(v1d,(/dimlat,dimlon/))
           fout->Q2D = Q2D

           v1d = ndtooned(f1->U2D)
           v1dgfs = ndtooned(f2->U2D)
           v1d(index) = v1dgfs(index)
           U2D = onedtond(v1d,(/dimlat,dimlon/))
           fout->U2D = U2D

           v1d = ndtooned(f1->V2D)
           v1dgfs = ndtooned(f2->V2D)
           v1d(index) = v1dgfs(index)
           V2D = onedtond(v1d,(/dimlat,dimlon/))
           fout->V2D = V2D

           v1d = ndtooned(f1->PSFC)
           v1dgfs = ndtooned(f2->PSFC)
           v1d(index) = v1dgfs(index)
           PSFC = onedtond(v1d,(/dimlat,dimlon/))
           fout->PSFC = PSFC

           v1d = ndtooned(f1->RAINRATE)
           v1dgfs = ndtooned(f2->RAINRATE)
           v1d(index) = v1dgfs(index)
           RAINRATE = onedtond(v1d,(/dimlat,dimlon/))
           fout->RAINRATE = RAINRATE

           v1d = ndtooned(f1->SWDOWN)
           v1dgfs = ndtooned(f2->SWDOWN)
           v1d(index) = v1dgfs(index)
           SWDOWN = onedtond(v1d,(/dimlat,dimlon/))
           fout->SWDOWN = SWDOWN

;           v1d = ndtooned(f1->WEASD)
;           v1dgfs = ndtooned(f2->WEASD)
;           v1d(index) = v1dgfs(index)
;           WEASD = onedtond(v1d,(/dimlat,dimlon/))
;           fout->WEASD = WEASD
           

end
