# wrf_hydro_forcing
This repository contains all scripts (NCL, Python, bash) and Fortran source used in the WRF-Hydro forcing engine.  The following forcing configurations will be supported for IOC (Initial Operating Capability):
    Analysis & assimilation, Short Range Forcing, Medium Range Forcing, and Long Range Forcing

    
**Note: The weightings files should be available for every model type.  These will usually reside on the test host.  Currently, they are found in hydro-c1:/d8/hydro-dm/IOC/forcing_engine/weighting_files. The weighting files are too large to check into GitHub, so please remember to include these when you are deploying to another environment. In addition, there is a lapse rate file (another .nc) which is also too large to check into GitHub.  Please make sure you have the "correct" version when deploying to another environment.  Finally, for Analysis and Assimilation, there are qpe bias correction and weighting files that are found at: /d8/hydro-dm/IOC_TESTING/params/anal_assim/combine_params.
    

    
