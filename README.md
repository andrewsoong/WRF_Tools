# WRF_Tools

Some tools for WPS, WRF and WRFDA

WRF_SCM: These scripts is used to create the WRF single column model forcing files from the met_em* files, ensemble experiments is also supported.

WRF_GEOGRID: These programs are used to change the land surface data of WRF. Details please see the README.

WRFDA_STAGE_IV: This converter utility is to reformat the NCEP Stage IV observations into the ASCII format that WRFDA can ingest. 

CAM2WRF: This utility is to drive WRF by CAM output.

BCC2WRF: This Fortran program is used to convert BCC output to WRF intermediate file, after that these files could be used to create met_em* files.

WRF_Tools_Official: Some utilities from the WRF download website.

WRFDA-4DVAR: Shell scripts to run WRFDA 4DVAR system, I seperate each process just the convenience of tuning.