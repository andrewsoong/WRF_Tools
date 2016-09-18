program CAM_netcdf_to_WRF_intermediate
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ! Fortran 90 program for reading CAM netcdf output and writing in
  ! the WPS intermediate format.
  !
  ! REQUIRED STEPS: (1) Run CAM and produce netcdf output files with
  ! the variables specified in the cam-header.txt and clm-header.txt
  ! files in the /Doc subdirectory here.  (2) Run the
  ! Input/create_read_file.sh to create an input file for this FORTRAN
  ! program.  (3) Run this FORTRAN program.  (4) Run metgrid.exe.  (5)
  ! Run real.exe.  You're done.
  !
  ! To compile and run this program on our harvard cluster, use the
  ! following shell command (use crest rather than swell): Note that
  ! this uses the ifort compiler.  If you use another one, make sure
  ! you write in big endian format using either compiler switches or
  ! open statement below:
  !
  ! cd ~/WRF_Mauricio/; ifort -c -CB -CU -ftrapuv -par_report0 -vec_report0 -I/opt/netcdf-3.6.0-p1/include/ CAM_netcdf_to_WRF_intermediate.f90; ifort CAM_netcdf_to_WRF_intermediate.o -L/opt/netcdf-3.6.0-p1/lib/ -lnetcdf; ./a.out
  !
  ! cd ~/WRF_Mauricio/Output/; ./metgrid.exe
  ! ln -s met_em*.nc real/
  ! cd ~/WRF_Mauricio/Output/real/; ./real.exe
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  implicit none

  ! Declarations:
  integer, parameter :: outfile_intermediate = 10
  integer, parameter :: outfile_intermediate_SST = 11
  integer, parameter :: outfile_diagnostics = 16
  integer, parameter :: infile_CAM_files_and_dates = 15
  character(len=24) :: HDATE

  ! dimensions:
  integer, parameter :: nx_CAM=144,ny_CAM=96,nz_CAM=66 &
       ,nfields=5,nfields2d=9,nfields2d_to_read=6 &
       ,nz_soil=4,nz_CLM=15,nfields_soil=3
  integer, parameter :: nz_WRF=27 ! (26 levels plus surface value)
  character*128 :: netcdf_cam_filename,netcdf_clm_filename
  integer :: iEOF
  logical :: EOF

  ! (1) Things read from the netcdf file need to be real*8 if declared
  ! there as DOUBLE and real if declared FLOAT; those written to
  ! intermediate format are real.  (2) Also, note that the order of
  ! dimension in the fortran program (nx_CAM,ny_CAM,nz_CAM,1)
  ! needs to be the reverse of that in the netcdf header
  ! (time,lev,lat,lon)!!
  real*8 :: lon(nx_CAM), lat(ny_CAM), PS(nx_CAM,ny_CAM)
  ! pressure variables:
  real*8 :: P_avg(nz_CAM), log_P_avg(nz_CAM) &
       ,P(nx_CAM,ny_CAM,nz_CAM), P0 &
       ,log_P(nx_CAM,ny_CAM,nz_CAM)
  ! interpolation variables:
  real*8 :: P_int(nz_WRF),log_P_int(nz_WRF) &
       ,field_data_int(nfields,nx_CAM,ny_CAM,nz_WRF,1)
  real*8, dimension(nfields,nx_CAM,ny_CAM,nz_CAM,1) :: field_data
  real*8, dimension(nfields2d,nx_CAM,ny_CAM,1) :: field2d_data
  real*8, dimension(nfields_soil,nx_CAM,ny_CAM,nz_soil,1) :: field_soil_data
  ! presure levels to which data are interpolated, these levels are
  ! taken from a standard case of WRF/WPS:
  data P_int /200100,100000,97500,95000,92500,90000,85000,80000 &
       ,75000,70000,65000,60000,55000,50000,45000,40000,35000 &
       ,30000,25000,20000,15000,10000,7000,5000,3000,2000,1000/
  character :: field_units(nfields,25),field2d_units(nfields2d,25) &
       ,field_soil_units(nfields_soil,25) &
       ,field_DESC(nfields,46),field2d_DESC(nfields2d,46) &
       ,field_soil_DESC(nfields_soil,46)
  character*9 :: field2d_name_to_output(nfields2d) &
       ,field_name_to_output(nfields),field_soil_name_to_output(nfields,nz_soil)

  ! specify the order of 2d and 3d variables in the data, units and title
  ! arrayes by specifying the integer pointers here:
  integer, parameter :: i2d_PSFC=1,i2d_PMSL=2,i2d_landsea=3,i2d_SKINTEMP=4 &
       ,i2d_TT=5,i2d_RH=7,i2d_UU=8,i2d_VV=9,i2d_SEAICE=6 ! XX ,i2d_SOILHGT=9
  integer, parameter :: i3d_TT=1,i3d_RH=2,i3d_UU=3,i3d_VV=4,i3d_GHT=5
  integer :: ifield,k

  ! 2d names expected by metgridl
  field2d_name_to_output(i2d_PSFC)    =   'PSFC     '  ! 
  field2d_name_to_output(i2d_PMSL)    =   'PMSL     '  ! 
  field2d_name_to_output(i2d_landsea) =   'LANDSEA  '  ! 
  field2d_name_to_output(i2d_SKINTEMP)=   'SKINTEMP '  ! 
  field2d_name_to_output(i2d_TT)      =   'TT       '  !  ! at 2m
  field2d_name_to_output(i2d_SEAICE)  =   'SEAICE   '  ! 
  field2d_name_to_output(i2d_RH)      =   'RH       '  !  ! at 2m
  field2d_name_to_output(i2d_UU)      =   'UU       '  !  ! at 10M
  field2d_name_to_output(i2d_VV)      =   'VV       '  !  ! at 10M
  !XX  field2d_name_to_output(i2d_SOILHGT) =   'SOILHGT  '  ! 

  ! names of 3d variables expected by metgrid
  ! (temp, relative humidity, u, v, geopotential height):
  field_name_to_output(i3d_TT) ='TT       '
  field_name_to_output(i3d_RH) ='RH       '
  field_name_to_output(i3d_UU) ='UU       '
  field_name_to_output(i3d_VV) ='VV       '
  field_name_to_output(i3d_GHT)='GHT      '

  ! names of soil variables required by Noah LSM (land surface model):
  ifield=1; k=1; field_soil_name_to_output(ifield,k)='SM000010'
  ifield=1; k=2; field_soil_name_to_output(ifield,k)='SM010040'
  ifield=1; k=3; field_soil_name_to_output(ifield,k)='SM040100'
  ifield=1; k=4; field_soil_name_to_output(ifield,k)='SM100200'
  ifield=2; k=1; field_soil_name_to_output(ifield,k)='ST000010'
  ifield=2; k=2; field_soil_name_to_output(ifield,k)='ST010040'
  ifield=2; k=3; field_soil_name_to_output(ifield,k)='ST040100'
  ifield=2; k=4; field_soil_name_to_output(ifield,k)='ST100200'

  ! the required variables by WRF are given at
  ! http://www.mmm.ucar.edu/wrf/OnLineTutorial/Basics/UNGRIB/ungrib_req_fields.htm

  ! open outpuf log file:
  open(outfile_diagnostics,form='formatted',file="Output/CAM2WRF2.log")

  ! read the first date and netcdf file name from the input file:
  open(infile_CAM_files_and_dates,form='formatted',file="Input/CAM2WRF.input")
  read(infile_CAM_files_and_dates,*,iostat=iEOF) netcdf_cam_filename,netcdf_clm_filename,hdate
  if (iEOF<0) then; 
     EOF=.true.; 
  else; 
     EOF=.false.; 
  end if

  ! Loop over all CAM netcdf files and dates 
  ! specified in unit infile_CAM_files_and_dates:
  ! =============================================
  do while (.not.EOF)

     write(*,*) "processing date=",hdate
     write(outfile_diagnostics,*) "processing CAM/CLM files=" &
          ,netcdf_cam_filename,netcdf_clm_filename,"; date=",hdate

     call read_netcdf_CAM_and_CLM_files(nz_WRF &
     ,P,log_P,P_int,log_P_int &
     ,hdate,outfile_diagnostics,outfile_intermediate,outfile_intermediate_SST &
     ,infile_CAM_files_and_dates,netcdf_cam_filename,netcdf_clm_filename &
     ,i3d_TT,i3d_RH,i3d_UU,i3d_VV,i3d_GHT &
     ,i2d_PSFC,i2d_PMSL,i2d_landsea,i2d_SKINTEMP,i2d_SEAICE &
     ,i2d_TT,i2d_RH,i2d_UU,i2d_VV &
     ,field_units,field2d_units,field_soil_units,field_DESC,field2d_DESC,field_soil_DESC &
     ,nx_CAM,ny_CAM,nz_CAM,nfields,nfields2d,nfields2d_to_read &
     ,nz_soil,nz_CLM,nfields_soil &
     ,lon,lat,PS &
     ,field_data,field_data_int,field2d_data,field_soil_data &
     ,field2d_name_to_output,field_name_to_output,field_soil_name_to_output)
     call interpolate_to_pressure_levels(outfile_diagnostics,nz_WRF,nfields &
     ,nx_CAM,ny_CAM,nz_CAM &
     ,P_int,log_P_int,P,log_P &
     ,field_data,field_data_int,PS,field_name_to_output)
     call write_intermediate_format_file(outfile_diagnostics,outfile_intermediate,outfile_intermediate_SST &
     ,nz_WRF,nz_soil,nfields,nfields2d,nfields_soil,nx_CAM,ny_CAM,nz_CAM,P_int &
     ,i2d_SKINTEMP,hdate,lat,lon &
     ,field_data_int,field2d_data,field_soil_data &
     ,field_name_to_output,field2d_name_to_output,field_soil_name_to_output &
     ,field_units,field2d_units,field_soil_units &
     ,field_DESC,field2d_DESC,field_soil_DESC)

     ! read next CAM netcdf filename and date:
     read(infile_CAM_files_and_dates,*,iostat=iEOF) netcdf_cam_filename,netcdf_clm_filename,hdate
     if (iEOF<0) then; 
        EOF=.true.; 
        write(outfile_diagnostics,*) "reached EOF for unit infile_CAM_files_and_dates."
     else 
        EOF=.false.; 
     end if

  end do ! while loop over reading of CAM filenames and dates
  write(outfile_diagnostics,'(/,"End of read loop.  Program finished.")')

  stop
end program CAM_netcdf_to_WRF_intermediate


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
SUBROUTINE spline(x,y,n,yp1,ypn,y2) 
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  implicit none
  INTEGER :: n
  INTEGER, parameter :: NMAX=500
  REAL*8 :: yp1,ypn,x(n),y(n),y2(n) 
  INTEGER :: i,k
  REAL*8 :: p,qn,sig,un,u(NMAX)
  if (yp1.gt..99e30) then
     y2(1)=0.
     u(1)=0.
  else
     y2(1)=-0.5
     u(1)=(3./(x(2)-x(1)))*((y(2)-y(1))/(x(2)-x(1))-yp1)
  end if
  do i=2,n-1
     sig=(x(i)-x(i-1))/(x(i+1)-x(i-1))
     p=sig*y2(i-1)+2.
     y2(i)=(sig-1.)/p
     u(i)=(6.*((y(i+1)-y(i))/(x(i+1)-x(i))-(y(i)-y(i-1)) &
          /(x(i)-x(i-1)))/(x(i+1)-x(i-1))-sig*u(i-1))/p
  end do

  if (ypn.gt..99e30) then
     qn=0.
     un=0.
  else
     qn=0.5 
     un=(3./(x(n)-x(n-1)))*(ypn-(y(n)-y(n-1))/(x(n)-x(n-1)))
  end if
  y2(n)=(un-qn*u(n-1))/(qn*y2(n-1)+1.)
  do k=n-1,1,-1
     y2(k)=y2(k)*y2(k+1)+u(k)
  end do
  return
end SUBROUTINE spline


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
SUBROUTINE splint(xa,ya,y2a,n,x,y) 
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  implicit none
  INTEGER :: n 
  REAL*8 :: x,y,xa(n),y2a(n),ya(n)
  INTEGER :: k,khi,klo
  REAL*8 :: a,b,h

  ! Eli: avoid actual extrapolation by using the end values:
  if (x<xa(1)) then
     y=ya(1);
  elseif (x>xa(n)) then
     y=ya(n);
  else
     ! Eli: end of my addition here.
     klo=1
     khi=n
1    if (khi-klo.gt.1) then
        k=(khi+klo)/2
        if(xa(k).gt.x)then
           khi=k
        else
           klo=k
        end if
        goto 1
     end if
     h=xa(khi)-xa(klo)
     if (h.eq.0.) pause 'bad xa input in splint'
     a=(xa(khi)-x)/h
     b=(x-xa(klo))/h
     y=a*ya(klo)+b*ya(khi)+ &
          ((a**3-a)*y2a(klo)+(b**3-b)*y2a(khi))*(h**2)/6.
  end if

  return 
end SUBROUTINE splint



!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
SUBROUTINE HANDLE_ERR(STATUS) 
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  implicit none
  INTEGER STATUS 
  INCLUDE 'netcdf.inc'
  IF (STATUS .NE. NF_NOERR) THEN 
     PRINT *, NF_STRERROR(STATUS) 
     STOP 'Stopped' 
  ENDIF
END SUBROUTINE HANDLE_ERR


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
Subroutine read_netcdf_CAM_and_CLM_files &
     (nz_WRF &
     ,P,log_P,P_int,log_P_int &
     ,hdate,outfile_diagnostics,outfile_intermediate,outfile_intermediate_SST &
     ,infile_CAM_files_and_dates,netcdf_cam_filename,netcdf_clm_filename &
     ,i3d_TT,i3d_RH,i3d_UU,i3d_VV,i3d_GHT &
     ,i2d_PSFC,i2d_PMSL,i2d_landsea,i2d_SKINTEMP,i2d_SEAICE &
     ,i2d_TT,i2d_RH,i2d_UU,i2d_VV &
     ,field_units,field2d_units,field_soil_units,field_DESC,field2d_DESC,field_soil_DESC &
     ,nx_CAM,ny_CAM,nz_CAM,nfields,nfields2d,nfields2d_to_read &
     ,nz_soil,nz_CLM,nfields_soil &
     ,lon,lat,PS &
     ,field_data,field_data_int,field2d_data,field_soil_data &
     ,field2d_name_to_output,field_name_to_output,field_soil_name_to_output)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  implicit none
  character*128 :: filename
  character*128 :: netcdf_cam_filename,netcdf_clm_filename
  character(len=24) :: HDATE
  character, allocatable, dimension(:) :: netcdf_units,netcdf_title &
       ,netcdf2d_units,netcdf2d_title &
       ,lon_netcdf_units,lon_netcdf_title&
       ,lat_netcdf_units,lat_netcdf_title
  character :: field_units(nfields,25),field2d_units(nfields2d,25) &
       ,field_soil_units(nfields_soil,25) &
       ,field_DESC(nfields,46),field2d_DESC(nfields2d,46) &
       ,field_soil_DESC(nfields_soil,46)
  character*9 :: field2d_name_to_output(nfields2d) &
       ,field_name_to_output(nfields),field_soil_name_to_output(nfields,nz_soil)
  integer :: nz_WRF
  INTEGER :: STATUS, NCID, NCID_clm, LATID, LATLEN, RECID, NRECS 
  INTEGER ::  LAT_var_id,lon_var_id,lev_var_id,time_var_id,nlon_var_id,nlat_var_id &
                                ! 3d fields:
       ,T_var_id,RH_var_id,U_var_id,V_var_id,GEOP_var_id &
                                ! 2d fields:
       ,PS_var_id,PSL_var_id,LANDFRAC_var_id,TS_var_id,T2m_var_id,SEAICE_var_id &
                                ! pressure variables:
       ,P0_var_id,hyam_var_id,hybm_var_id &
                                ! soil variables:
       ,SM_var_id,ST_var_id,STI_var_id
  integer :: outfile_intermediate, outfile_intermediate_SST &
       ,outfile_diagnostics, infile_CAM_files_and_dates
  INTEGER :: netcdf_units_length(nfields),netcdf_title_length(nfields) &
       ,netcdf2d_units_length(nfields2d),netcdf2d_title_length(nfields2d) &
       ,field_var_id(nfields), field2d_var_id(nfields2d) &
       ,lon_lat_netcdf_units_length,lon_lat_netcdf_title_length &
       ,ifield,i,j,k
  integer :: i3d_TT,i3d_RH,i3d_UU,i3d_VV,i3d_GHT
  integer :: i2d_PSFC,i2d_PMSL,i2d_landsea,i2d_SKINTEMP,i2d_SEAICE &
       ,i2d_TT,i2d_RH,i2d_UU,i2d_VV ! XX ,i2d_SOILHGT
  integer :: nx_CAM,ny_CAM,nz_CAM &
       ,nfields,nfields2d,nfields2d_to_read &
       ,nz_soil,nz_CLM,nfields_soil
  real*8 :: lon(nx_CAM), lat(ny_CAM), PS(nx_CAM,ny_CAM)
  real, dimension(nx_CAM,ny_CAM,nz_CAM,1) :: field3d ! in netcdf: T(time, lev, lat, lon) ;
  real, dimension(nx_CAM,ny_CAM,1) :: field2d ! in netcdf: (time, lat, lon) ;
  real, dimension(nx_CAM,ny_CAM,nz_CLM,1) :: field_soil ! in netcdf: (time, levsoi, lat, lon) ;
  real*8, dimension(nfields,nx_CAM,ny_CAM,nz_CAM,1) :: field_data
  real*8, dimension(nfields2d,nx_CAM,ny_CAM,1) :: field2d_data
  real*8, dimension(nfields_soil,nx_CAM,ny_CAM,nz_soil,1) :: field_soil_data
  real*8 :: field_max,field_min
  real*8 :: P_avg(nz_CAM), log_P_avg(nz_CAM) &
       ,P(nx_CAM,ny_CAM,nz_CAM), P0 &
       ,log_P(nx_CAM,ny_CAM,nz_CAM) &
       ,hyam(nz_CAM), hybm(nz_CAM)
  ! interpolation variables:
  real*8 :: P_int(nz_WRF),log_P_int(nz_WRF) &
       ,field_data_int(nfields,nx_CAM,ny_CAM,nz_WRF,1)
  INCLUDE 'netcdf.inc' 

  ! open output files for metgrid in WRF/WPS intermediate format:
  write(filename,'("Output/FILE:",A13)') hdate(1:13)
  write(outfile_diagnostics,*) "output intermediate file filename=",filename
  open(outfile_intermediate,form='unformatted',convert='big_endian',file=filename)

  write(filename,'("Output/SST:",A13)') hdate(1:13)
  write(outfile_diagnostics,*) "output intermediate SST file filename=",filename
!  open(outfile_intermediate_SST,form='unformatted',convert='big_endian',file=filename)

  ! open input CAM netCDF file:
  ! [to find out which variables are in a netcdf file, use:
  ! $ ncdump -h file.nc
  ! to look at the header of the ascii output.]

  ! CAM:
  STATUS = NF_OPEN(netcdf_cam_filename, 0, NCID) 
  IF (STATUS .NE. NF_NOERR) CALL HANDLE_ERR(STATUS)
  ! CLM:
  STATUS = NF_OPEN(netcdf_clm_filename, 0, NCID_clm) 

  IF (STATUS .NE. NF_NOERR) CALL HANDLE_ERR(STATUS)
  write(outfile_diagnostics,*) "done nf_open"

  ! read netcdf data for all levels:
  ! ================================

  ! get dimension IDs: (only needed if we don't know the dimension and
  ! want to read them from the netcdf file)
  ! STATUS = NF_INQ_DIMID(NCID, 'T', dim_id) 
  ! IF (STATUS .NE. NF_NOERR) CALL HANDLE_ERR(STATUS)

  ! get variable IDs 
  ! 3d:
  STATUS = NF_INQ_VARID(NCID, 'lat', LAT_var_id) 
  STATUS = NF_INQ_VARID(NCID, 'lon', lon_var_id) 
  STATUS = NF_INQ_VARID(NCID, 'lev', lev_var_id) 
  STATUS = NF_INQ_VARID(NCID, 'time', time_var_id) 
  STATUS = NF_INQ_VARID(NCID, 'nlon', nlon_var_id) 
  STATUS = NF_INQ_VARID(NCID, 'nlat', nlat_var_id) 
  STATUS = NF_INQ_VARID(NCID, 'T', T_var_id) 
  STATUS = NF_INQ_VARID(NCID, 'RELHUM', RH_var_id) 
  STATUS = NF_INQ_VARID(NCID, 'U', U_var_id) 
  STATUS = NF_INQ_VARID(NCID, 'V', V_var_id) 
  STATUS = NF_INQ_VARID(NCID, 'Z3', GEOP_var_id) 

  ! 2d:
  STATUS = NF_INQ_VARID(NCID, 'PS', PS_var_id) 
  STATUS = NF_INQ_VARID(NCID, 'PSL', PSL_var_id) 
  STATUS = NF_INQ_VARID(NCID, 'LANDFRAC', LANDFRAC_var_id)
  IF (STATUS .NE. NF_NOERR) CALL HANDLE_ERR(STATUS)
  STATUS = NF_INQ_VARID(NCID, 'TS', TS_var_id) 
  STATUS = NF_INQ_VARID(NCID, 'TREFHT', T2m_var_id)
  STATUS = NF_INQ_VARID(NCID, 'ICEFRAC', SEAICE_var_id)

  ! pressure variables:
  STATUS = NF_INQ_VARID(NCID, 'P0', P0_var_id) 
  STATUS = NF_INQ_VARID(NCID, 'hyam', hyam_var_id) 
  STATUS = NF_INQ_VARID(NCID, 'hybm', hybm_var_id) 

  ! soil temp and moisture:
  STATUS = NF_INQ_VARID(NCID_clm, 'H2OSOI', SM_var_id) 
  STATUS = NF_INQ_VARID(NCID_clm, 'TSOI', ST_var_id) 
  STATUS = NF_INQ_VARID(NCID_clm, 'TSOI_ICE', STI_var_id) 

  ! 3d:
  field_var_id(i3d_TT) =T_var_id
  field_var_id(i3d_RH) =RH_var_id
  field_var_id(i3d_UU) =U_var_id
  field_var_id(i3d_VV) =V_var_id
  field_var_id(i3d_GHT)=GEOP_var_id

  ! 2d:
  field2d_var_id(i2d_PSFC)    =PS_var_id
  field2d_var_id(i2d_PMSL)    =PSL_var_id
  field2d_var_id(i2d_landsea) =LANDFRAC_var_id
  field2d_var_id(i2d_SKINTEMP)=TS_var_id
  field2d_var_id(i2d_TT)      =T2m_var_id
  field2d_var_id(i2d_SEAICE)  =SEAICE_var_id

  write(outfile_diagnostics,*) "done NF_INQ_VARID, field_var_id=",field_var_id
  write(outfile_diagnostics,*) "field2d_var_id=",field2d_var_id

  ! get attribute values: title and units
  ! =====================================

  ! get units and titles for lon:
  STATUS = NF_INQ_ATTLEN (NCID, lon_var_ID, 'units', lon_lat_netcdf_units_length) 
  STATUS = NF_INQ_ATTLEN (NCID, lon_var_ID, 'long_name', lon_lat_netcdf_title_length) 
  write(outfile_diagnostics,*) " lon: netcdf units length=",lon_lat_netcdf_units_length &
       ,"; netcdf title length=",lon_lat_netcdf_title_length
  allocate(lon_netcdf_units(lon_lat_netcdf_units_length))
  allocate(lon_netcdf_title(lon_lat_netcdf_title_length))
  STATUS = NF_GET_ATT_TEXT (NCID, lon_var_ID, 'units', lon_netcdf_units) 
  STATUS = NF_GET_ATT_TEXT (NCID, lon_var_ID, 'long_name', lon_netcdf_title) 
  write(outfile_diagnostics,*) "netcdf title=",lon_netcdf_title,"; units=",lon_netcdf_units
  ! get units and titles for lat:
  STATUS = NF_INQ_ATTLEN (NCID, lat_var_ID, 'units', lon_lat_netcdf_units_length) 
  STATUS = NF_INQ_ATTLEN (NCID, lat_var_ID, 'long_name', lon_lat_netcdf_title_length) 
  write(outfile_diagnostics,*) " lat: netcdf units length=",lon_lat_netcdf_units_length &
       ,"; netcdf title length=",lon_lat_netcdf_title_length
  allocate(lat_netcdf_units(lon_lat_netcdf_units_length))
  allocate(lat_netcdf_title(lon_lat_netcdf_title_length))
  STATUS = NF_GET_ATT_TEXT (NCID, lat_var_ID, 'units', lat_netcdf_units) 
  STATUS = NF_GET_ATT_TEXT (NCID, lat_var_ID, 'long_name', lat_netcdf_title) 
  write(outfile_diagnostics,*) "netcdf title=",lat_netcdf_title,"; units=",lat_netcdf_units
  deallocate(lon_netcdf_units,lon_netcdf_title,lat_netcdf_units,lat_netcdf_title)

  ! get units and titles for 3d fields: T,RH,U,V:
  do ifield=1,nfields
     write(outfile_diagnostics,*) " getting units and title for 3d fields: ifield=",ifield
     STATUS = NF_INQ_ATTLEN (NCID, field_var_ID(ifield), 'units', netcdf_units_length(ifield)) 
     STATUS = NF_INQ_ATTLEN (NCID, field_var_ID(ifield), 'long_name', netcdf_title_length(ifield)) 
     allocate(netcdf_units(netcdf_units_length(ifield)))
     allocate(netcdf_title(netcdf_title_length(ifield)))
     STATUS = NF_GET_ATT_TEXT (NCID, field_var_ID(ifield), 'units', netcdf_units) 
     STATUS = NF_GET_ATT_TEXT (NCID, field_var_ID(ifield), 'long_name', netcdf_title)
     ! pad units to 25 chars as required for WRF:
     field_units(ifield,:)="                         "
     field_units(ifield,1:min(25,netcdf_units_length(ifield)))=netcdf_units
     field_DESC(ifield,:)="                                              "
     field_DESC(ifield,1:netcdf_title_length(ifield))=netcdf_title
     write(outfile_diagnostics,*) "netcdf title=",netcdf_title,"; units=",netcdf_units
     deallocate(netcdf_units, netcdf_title)
  end do

  ! get units and titles for 2d fields: needs to read some from
  ! netcdf, and set others from 3d fields.  start with reading those
  ! that exist in the netcdf file:
  do ifield=1,nfields2d_to_read
     write(outfile_diagnostics,*) " getting units and title for 2d fields: ifield=",ifield
     STATUS = NF_INQ_ATTLEN (NCID, field2d_var_ID(ifield), 'units', netcdf2d_units_length(ifield)) 
     STATUS = NF_INQ_ATTLEN (NCID, field2d_var_ID(ifield), 'long_name', netcdf2d_title_length(ifield)) 
     allocate(netcdf2d_units(netcdf2d_units_length(ifield)))
     allocate(netcdf2d_title(netcdf2d_title_length(ifield)))
     STATUS = NF_GET_ATT_TEXT (NCID, field2d_var_ID(ifield), 'units', netcdf2d_units) 
     STATUS = NF_GET_ATT_TEXT (NCID, field2d_var_ID(ifield), 'long_name', netcdf2d_title)
     write(outfile_diagnostics,*) "netcdf title=",netcdf2d_title,"; units=",netcdf2d_units
     ! pad units to 25 chars as required for WRF:
     field2d_units(ifield,:)="                         "
     field2d_units(ifield,1:min(25,netcdf2d_units_length(ifield)))=netcdf2d_units
     field2d_DESC(ifield,:)="                                              "
     field2d_DESC(ifield,1:netcdf2d_title_length(ifield))=netcdf2d_title
     deallocate(netcdf2d_units, netcdf2d_title)
  end do

  ! next, set units for some of the 2d fields that are not in the
  ! netcdf file from the appropriate 3d fields:
  field2d_units(i2d_RH,:)="percent                  "  ! RH
  field2d_units(i2d_UU,:)="m/s                      "  ! UU
  field2d_units(i2d_VV,:)="m/s                      "  ! VV
  !XX     field2d_units(i2d_SOILHGT,:)="cm                       "  ! soil height

  ! set units and titles for soil variables:
  write(outfile_diagnostics,*) " getting units and title for soil fields"
  ifield=1
  field_soil_units(ifield,:)="mm3/mm3                  "  ! moisture
  field_soil_DESC(ifield,:)="volumetric soil water                         "
  ifield=2
  field_soil_units(ifield,:)="K                        "  ! temperature
  field_soil_DESC(ifield,:)="soil temperature                              "


  ! get values of the needed variables from netcdf file:
  ! ====================================================

  ! first, get lon/ lat:
  STATUS = NF_GET_VAR_DOUBLE(NCID, lon_var_ID, lon)
  write(outfile_diagnostics,*) "lon=",lon
  STATUS = NF_GET_VAR_DOUBLE(NCID, lat_var_ID, lat)
  write(outfile_diagnostics,*) "lat=",lat

  ! get 3d T,RH,U,V:
  do ifield=1,nfields
     STATUS = NF_GET_VAR_REAL(NCID, field_var_ID(ifield), field3d)
     IF (STATUS .NE. NF_NOERR) CALL HANDLE_ERR(STATUS)
     field_data(ifield,:,:,:,1)=field3d(:,:,:,1)
     write(outfile_diagnostics,*) ,"ifield=",ifield,"; name=",field_name_to_output(ifield) &
          ,"; field3d(64,32,:,1)=",field3d(64,32,:,1) &
          ,"; field3d(64,:,nz_CAM,1)=",field3d(64,:,nz_CAM,1)
  end do
  write(outfile_diagnostics,*) "done getting T,RH,U,V from netcdf"

  ! get 2d fields:
  ! first those that are in the netcdf file as 2d fields:
  do ifield=1,nfields2d_to_read
     STATUS = NF_GET_VAR_REAL(NCID, field2d_var_ID(ifield), field2d)
     IF (STATUS .NE. NF_NOERR) CALL HANDLE_ERR(STATUS)
     field2d_data(ifield,:,:,1)=field2d(:,:,1)
  end do
  PS=field2d_data(i2d_PSFC,:,:,1)

  ! fix land mask: WRF cannot deal with mask values that are not 0 or 1:
  write(outfile_diagnostics,*) "land mask before fixing: field2d_data(ifield=i2d_landsea,64,:,1)=" &
       ,field2d_data(i2d_landsea,64,:,1)
  do i=1,nx_CAM; do j=1,ny_CAM; 
     if (field2d_data(i2d_landsea,i,j,1)<0.5) then
        field2d_data(i2d_landsea,i,j,1)=0; else; field2d_data(i2d_landsea,i,j,1)=1; 
     end if
  end do; end do
  write(outfile_diagnostics,*) "land mask after  fixing: field2d_data(ifield=i2d_landsea,64,:,1)=" &
       ,field2d_data(i2d_landsea,64,:,1)
  write(outfile_diagnostics,*) "done fixing land mask to be only 0 or 1."

  ! next, those 2d fields that need to be obtained by extrapolating
  ! some 3d Field to the surface:
  field2d_data(i2d_RH,:,:,1)=    field_data(i3d_RH,:,:,nz_CAM,1) ! RH
  field2d_data(i2d_UU,:,:,1)=    field_data(i3d_UU,:,:,nz_CAM,1) ! UU
  field2d_data(i2d_VV,:,:,1)=    field_data(i3d_VV,:,:,nz_CAM,1) ! VV
  !XX     field2d_data(i2d_SOILHGT,:,:,1)=100+0*field_data(1,:,:,nz_CAM,1) ! SOILHGT in cm XX fix this?

  ! print some diagnostics about 2d fields:
  do ifield=1,nfields2d
     field_max=-1.e10
     do i=1,nx_CAM;do j=1,ny_CAM;
        field_max=dmax1(field_max,field2d_data(ifield,i,j,1))
     end do; end do;
     field_min=1.e10
     do i=1,nx_CAM;do j=1,ny_CAM;
        field_min=dmin1(field_min,field2d_data(ifield,i,j,1))
     end do; end do;
     write(outfile_diagnostics,*) "2d fields: ifield=",ifield &
          ,"; field name=",field2d_name_to_output(ifield) &
          ,"; max=",field_max,"; min=",field_min
     write(outfile_diagnostics,*) "ifield=",ifield,"; 2d field name to output=" &
          ,field2d_name_to_output(ifield) &
          ,"; field2d_data(ifield,1, 1,1)=",field2d_data(ifield,1,1, 1) &
          ,"; field2d_data(ifield,64,:,1)=",field2d_data(ifield,64,:,1)
  end do

  write(outfile_diagnostics,*) "done getting 2d fields from netcdf"

  ! get fields needed to calculate 3d pressure:
  STATUS = NF_GET_VAR_DOUBLE(NCID, hyam_var_id, hyam)
  STATUS = NF_GET_VAR_DOUBLE(NCID, hybm_var_id, hybm)
  STATUS = NF_GET_VAR_DOUBLE(NCID, P0_var_id, P0)
  write(outfile_diagnostics,*) "P0=",P0
  ! write(outfile_diagnostics,*) "PS=",PS
  write(outfile_diagnostics,*) "hyam=",hyam
  write(outfile_diagnostics,*) "hybm=",hybm
  write(outfile_diagnostics,*) "done getting pressure fields from netcdf"

  ! calculate 3d pressure field from sigma coordinates:
  ! P(k,j,i)=hyam(k)*P0+hybm(k)*PS(j,i)
  do k=1,nz_CAM; do i=1,nx_CAM; do j=1,ny_CAM; 
     P(i,j,k)=hyam(k)*P0+hybm(k)*PS(i,j)
  end do; end do; end do
  write(outfile_diagnostics,*) "P(64,32,:)=",P(64,32,:)

  ! calculate average pressure profile:
  do k=1,nz_CAM; 
     P_avg(k)=0
     do i=1,nx_CAM; do j=1,ny_CAM; 
        P_avg(k)=P_avg(k)+P(i,j,k)
     end do; end do; 
     P_avg(k)=P_avg(k)/(nx_CAM*ny_CAM)
  end do


  ! Calculate log pressure and log average pressure, in preparation
  ! for interpolation from sigma to pressure coordinates:
  log_P=log10(P);
  log_P_avg=log10(P_avg);
  log_P_int=log10(P_int);
  write(outfile_diagnostics,*) "P_avg=",P_avg
  write(outfile_diagnostics,*) "log_P_avg=",log_P_avg
  write(outfile_diagnostics,*) "P_int=",P_int
  write(outfile_diagnostics,*) "log_P_int=",log_P_int
  write(outfile_diagnostics,*) "done calculating pressure."

  ! get soil variables from CLM file:
  ! first, set soil moisture:
  STATUS = NF_GET_VAR_REAL(NCID_clm, SM_var_id, field_soil)
  IF (STATUS .NE. NF_NOERR) CALL HANDLE_ERR(STATUS)
  ifield=1
  do k=1,nz_soil;
     ! XX set WRF soil moisture values at all levels to be equal to
     ! the first CAM soil moisture level, note 1000 conversion factor
     ! from CLM's H2OSOI(mm3/mm3) field to WRF's SMXXXXXX (kg/m3):
     field_soil_data(ifield,:,:,k,1)=1000*field_soil(:,:,1,1) 
  end do;

  ! second, set soil temperature:
  STATUS = NF_GET_VAR_REAL(NCID_clm, ST_var_id, field_soil)
  IF (STATUS .NE. NF_NOERR) CALL HANDLE_ERR(STATUS)
  ifield=2
  do k=1,nz_soil
     ! XX set WRF soil values at all levels to be equal to the first CAM soil level:
     field_soil_data(ifield,:,:,k,1)=field_soil(:,:,1,1) 
  end do

  ! third, set soil temperature in ice:
  STATUS = NF_GET_VAR_REAL(NCID_clm, STI_var_id, field_soil)
  IF (STATUS .NE. NF_NOERR) CALL HANDLE_ERR(STATUS)
  ifield=3
  do k=1,nz_soil
     ! XX set WRF soil values at all levels to be equal to the first CAM soil level:
     field_soil_data(ifield,:,:,k,1)=field_soil(:,:,1,1) 
  end do

  ! deal with missing soil values (1.e36):
  ! for moisture, set missing values to 0:
  ifield=1
  do i=1,nx_CAM; do j=1,ny_CAM; do k=1,nz_soil
     if (field_soil_data(ifield,i,j,k,1)>1.0e30) then
        field_soil_data(ifield,i,j,k,1)= 0.0; 
     elseif (field_soil_data(ifield,i,j,k,1)>1.0) then
        field_soil_data(ifield,i,j,k,1)= 1.0; 
     endif
  end do; end do; end do; 
  ! temperature: set missing vaues to surface temperature:
  ifield=2
  do i=1,nx_CAM; do j=1,ny_CAM; do k=1,nz_soil
     if (field_soil_data(ifield,i,j,k,1)>1.0e30) then
        if (field_soil_data(3,i,j,k,1)<1.e30) then
           field_soil_data(ifield,i,j,k,1)=field_soil_data(3,i,j,k,1)
        else
           field_soil_data(ifield,i,j,k,1)=field2d_data(i2d_SKINTEMP,i,j,1)
        endif
     endif
  end do; end do; end do; 

  ! print some diagnostics about soil fields:
  do ifield=1,nfields_soil
     do k=1,nz_soil
        write(outfile_diagnostics,*) " soil diagnostics for ifield=",ifield,"; k=",k &
             ,"; variable=",field_soil_name_to_output(ifield,k)
        field_max=-1.e10
        do i=1,nx_CAM;do j=1,ny_CAM;
           field_max=dmax1(field_max,field_soil_data(ifield,i,j,k,1))
        end do; end do;
        field_min=1.e10
        do i=1,nx_CAM;do j=1,ny_CAM;
           field_min=dmin1(field_min,field_soil_data(ifield,i,j,k,1))
        end do; end do;
        write(outfile_diagnostics,*) "max=",field_max,"; min=",field_min
        write(outfile_diagnostics,*) "; field_soil_data(ifield,64,32,:,1)=" &
             ,field_soil_data(ifield,64,32,:,1) &
             ,"; field_soil_data(ifield,64,:,nz_soil,1)=" &
             ,field_soil_data(ifield,64,:,nz_soil,1)
     end do
  end do

  ! close netCDF dataset
  status=NF_CLOSE(ncid)              
  status=NF_CLOSE(ncid_clm)              

  return
end Subroutine read_netcdf_CAM_and_CLM_files


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
Subroutine interpolate_to_pressure_levels(outfile_diagnostics,nz_WRF,nfields &
     ,nx_CAM,ny_CAM,nz_CAM &
     ,P_int,log_P_int,P,log_P &
     ,field_data,field_data_int,PS,field_name_to_output)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  implicit none
  integer :: nz_WRF,outfile_diagnostics
  integer :: ifield,i,j,k,nfields,nx_CAM,ny_CAM,nz_CAM
  character*9 :: field_name_to_output(nfields)
  real*8 :: X(nz_CAM),Y(nz_CAM),Y2(nz_CAM),XINT,YINT,yp1,ypn
  real*8, dimension(nfields,nx_CAM,ny_CAM,nz_CAM,1) :: field_data
  real*8 :: P(nx_CAM,ny_CAM,nz_CAM),log_P(nx_CAM,ny_CAM,nz_CAM)
  real*8 :: P_int(nz_WRF),log_P_int(nz_WRF) &
       ,field_data_int(nfields,nx_CAM,ny_CAM,nz_WRF,1)
  real*8 :: PS(nx_CAM,ny_CAM)
  real*8 :: field_max,field_min
  
  ! interpolate from sigma to pressure coordinates:
  ! "natural" b.c.:
  yp1=2.d30; ypn=2.d30
  do ifield=1,nfields
     do j=1,ny_CAM; do i=1,nx_CAM; 
        X=log_P(i,j,:)
        Y=field_data(ifield,i,j,:,1)
        call spline(X,Y,nz_CAM,yp1,ypn,Y2)
        do k=1,nz_WRF
           if (abs(P_int(k)-200100).le.0.01) then
              ! surface level:
              XINT=log(PS(i,j))
           else
              XINT=log_P_int(k)
           end if
           call splint(X,Y,Y2,nz_CAM,XINT,YINT)
           ! make sure RH is not negative:
           if (ifield==2 .and. YINT<0) then
              write(outfile_diagnostics,*) "*** RH<0: RH=",YINT,"; i,j,k=",i,j,k
              YINT=0;
           end if
           field_data_int(ifield,i,j,k,1)=YINT
        end do
     end do; end do;

     ! print some diagnostics about interpolated 3d fields:
     field_max=-1.e10
     do i=1,nx_CAM;do j=1,ny_CAM;do k=1,nz_WRF;
        field_max=dmax1(field_max,field_data_int(ifield,i,j,k,1))
     end do; end do; end do;
     field_min=1.e10
     do i=1,nx_CAM;do j=1,ny_CAM;do k=1,nz_WRF;
        field_min=dmin1(field_min,field_data_int(ifield,i,j,k,1))
     end do; end do; end do;
     write(outfile_diagnostics,*) "interpolated fields: ifield=",ifield &
          ,"; field name=",field_name_to_output(ifield) &
          ,"; max=",field_max,"; min=",field_min
     write(outfile_diagnostics,*) "; field_data_int(ifield,64,32,:,1)=" &
          ,field_data_int(ifield,64,32,:,1) &
          ,"; field_data_int(ifield,64,:,nz_WRF,1)=" &
          ,field_data_int(ifield,64,:,nz_WRF,1)
  end do

  write(outfile_diagnostics,*) "done interpolating to pressure coordinates"

  return
end subroutine interpolate_to_pressure_levels


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
Subroutine write_intermediate_format_file(outfile_diagnostics,outfile_intermediate,outfile_intermediate_SST &
     ,nz_WRF,nz_soil,nfields,nfields2d,nfields_soil,nx_CAM,ny_CAM,nz_CAM,P_int &
     ,i2d_SKINTEMP,hdate,lat,lon &
     ,field_data_int,field2d_data,field_soil_data &
     ,field_name_to_output,field2d_name_to_output,field_soil_name_to_output &
     ,field_units,field2d_units,field_soil_units &
     ,field_DESC,field2d_DESC,field_soil_DESC)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  ! the intermediate format is described in:
  ! http://www.mmm.ucar.edu/wrf/OnLineTutorial/Basics/IM_files/IM_wps.htm

  !====================================================================================!
  ! READ in your data from the original source - you need to add the reading code here !
  !                                                                                    !
  ! You need to allocate SLAB (this is a 2D array) and place each 2D slab here before  !
  ! you can write it out to into the intermadiate file format                          !
  !                                                                                    !
  ! Other information you need to know about your data:                                !
  !    Time at which data is valid                                                     !
  !    Forecast time of the data                                                       !
  !    Source of data - you can make something up, it is never used                    !
  !    Field name - NOTE THEY NEED TO MATCH THOSE EXPECTED BY METGRID                   !
  !    Units of field                                                                  !
  !    Description of data                                                             !
  !    Level of data - Pa, 200100 Pa is used for surface, and 201300 Pa is used        !
  !          for sea-level pressure                                                    !
  !    X dimension                                                                     !
  !    Y dimension                                                                     !
  !    Data projection - only recognize                                                !
  !         0:  Cylindrical Equidistant (Lat/lon) projection.                          !
  !         1:  Mercator projection.                                                   !
  !         3:  Lambert-conformal projection.                                          !
  !         4:  Gaussian projection.                                                   !
  !         5:  Polar-stereographic projection.                                        !
  !    Start location of data - "CENTER", "SWCORNER". "SWCORNER" is typical            !
  !    Start lat & long of data                                                        !
  !    Lat/Lon increment                                                               !
  !    Number of latitudes north of equator (for Gaussian grids)                       !
  !    Grid-spacing in x/y                                                             !
  !    Center long                                                                     !
  !    truelat1/2                                                                      !
  !    Has the winds been rotated                                                      !
  !====================================================================================!

  implicit none
  integer outfile_diagnostics,outfile_intermediate,outfile_intermediate_SST &
       ,i,j,k,nz_WRF,nz_soil &
       ,nfields,nfields2d,nfields_soil,ifield &
       ,nx_CAM,ny_CAM,nz_CAM,IERR,i2d_SKINTEMP
  integer :: IFV=5
  character*9 :: field2d_name_to_output(nfields2d) &
       ,field_name_to_output(nfields),field_soil_name_to_output(nfields,nz_soil)
  character(len=32) :: MAP_SOURCE
  character(len=9) :: FIELD
  character :: field_units(nfields,25),field2d_units(nfields2d,25) &
       ,field_soil_units(nfields_soil,25) &
       ,field_DESC(nfields,46),field2d_DESC(nfields2d,46) &
       ,field_soil_DESC(nfields_soil,46)
  real*8 :: lon(nx_CAM), lat(ny_CAM)
  real, dimension(nx_CAM,ny_CAM) :: SLAB
  real*8 :: P_int(nz_WRF)

  real*8 :: field_data_int(nfields,nx_CAM,ny_CAM,nz_WRF,1)
  real*8, dimension(nfields2d,nx_CAM,ny_CAM,1) :: field2d_data
  real*8, dimension(nfields_soil,nx_CAM,ny_CAM,nz_soil,1) :: field_soil_data


  character(len=24) :: HDATE
  real :: XFCST
  character(len=8) :: STARTLOC
  character :: UNITS(25)
  character :: DESC(46)
  real :: XLVL
  integer :: NX
  integer :: NY
  integer :: IPROJ
  real :: STARTLAT
  real :: STARTLON
  real :: DELTALAT
  real :: DELTALON
  real :: DX
  real :: DY
  real :: XLONC
  real :: TRUELAT1
  real :: TRUELAT2
  real :: NLATS
  real :: EARTH_RADIUS = 6367470. * .001
  logical :: IS_WIND_EARTH_REL = .FALSE.
  INCLUDE 'netcdf.inc' 

  ! loop over all levels and output 3d fields to the intermediate format
  ! ====================================================================

  do k=1,nz_WRF

     write(outfile_diagnostics,*) " outputing 3d fields for k=",k

     ! go over all 3d fields and output them to the intermediate format
     ! =================================================================
     do ifield=1,nfields

        write(outfile_diagnostics,*) "writing 3d fields in intermediate format: ifield=" &
             ,ifield, "; field=",field_name_to_output(ifield)

        write (outfile_intermediate, IOSTAT=IERR) IFV
        write(outfile_diagnostics,*) "done writing IFV"

        ! WRITE the second record, common to all projections:
        ! HDATE=  this is read from input file.
        XFCST=0.0
        MAP_SOURCE="##CAM run from dorian###########"
        FIELD=field_name_to_output(ifield)
        UNITS=field_units(ifield,:)
        DESC=field_DESC(ifield,:)
        XLVL=P_int(k)
        NX=nx_CAM
        NY=ny_CAM
        IPROJ=0 ! CAM data are on a gaussian grid  XX right?
        write (outfile_intermediate) HDATE,XFCST,MAP_SOURCE,FIELD,UNITS,DESC,XLVL,NX,NY,IPROJ
        write(outfile_diagnostics,*) "done writing second record, date:" &
             , HDATE//"  ", FIELD,"; xlvl=",xlvl

        ! WRITE the third record, which depends on the projection:

        if (IPROJ == 0) then 
           ! Gaussian projection
           STARTLOC="SWCORNER"
           STARTLAT=lat(1)
           STARTLON=lon(1)
           NLATS=ny_CAM/2 ! number of latitudes north of equator
           DELTALON=lon(2)-lon(1)
           DELTALAT=lat(2)-lat(1)
           WRITE (outfile_intermediate) STARTLOC,STARTLAT,STARTLON,DELTALAT,DELTALON,EARTH_RADIUS
        else
           write(outfile_diagnostics,*) " *** error: wrong projection"
           stop
        endif
        write(outfile_diagnostics,*) "done writing third record"

        WRITE (outfile_intermediate) IS_WIND_EARTH_REL
        write(outfile_diagnostics,*) "done writing IS_WIND_EARTH_REL=",IS_WIND_EARTH_REL

        do i=1,nx_CAM; do j=1,ny_CAM
           SLAB(i,j)=field_data_int(ifield,i,j,k,1)
        end do; end do
        WRITE (outfile_intermediate) SLAB
        write(outfile_diagnostics,*) "done writing slab; slab(1,1)=",slab(1,1)

     enddo ! do loop over 3d fields

  enddo ! do loop over levels

  ! go over all 2d fields and output them to the intermediate format
  ! =================================================================
  do ifield=1,nfields2d

     write(outfile_diagnostics,*) "writing 2d fields in intermediate format: ifield=" &
          ,ifield, "; field=",field2d_name_to_output(ifield)

     write (outfile_intermediate, IOSTAT=IERR) IFV
     write(outfile_diagnostics,*) "done writing IFV"

     ! WRITE the second record, common to all projections:
     ! HDATE=  this is read from input file.
     XFCST=0.0
     MAP_SOURCE="##CAM run from dorian###########"
     FIELD=field2d_name_to_output(ifield)
     UNITS=field2d_units(ifield,:)
     DESC=field2d_DESC(ifield,:)
     if (ifield==1) then
        XLVL=200100.0
     elseif (ifield==2) then
        XLVL=201300.0
     elseif (ifield==3) then
        XLVL=200100.0
     elseif (ifield==4) then
        XLVL=200100.00
     elseif (ifield==5) then
        XLVL=200100.0
     elseif (ifield==6) then
        XLVL=200100.0
     elseif (ifield==7) then
        XLVL=200100.0
     elseif (ifield==8) then
        XLVL=200100.0
     elseif (ifield==9) then
        XLVL=200100.0
     end if
     NX=nx_CAM
     NY=ny_CAM
     IPROJ=0 ! CAM data are on a gaussian grid  XX right?
     write (outfile_intermediate) HDATE,XFCST,MAP_SOURCE,FIELD,UNITS,DESC,XLVL,NX,NY,IPROJ
     write(outfile_diagnostics,*) "done writing second record, date:" &
          , HDATE//"  ", FIELD,"; xlvl=",xlvl

     ! WRITE the third record, which depends on the projection:

     if (IPROJ == 0) then 

        ! Gaussian projection
        STARTLOC="SWCORNER"
        STARTLAT=lat(1)
        STARTLON=lon(1)
        NLATS=ny_CAM/2 ! number of latitudes north of equator
        DELTALON=lon(2)-lon(1)
        DELTALAT=lat(2)-lat(1)
        WRITE (outfile_intermediate) STARTLOC,STARTLAT,STARTLON,DELTALAT,DELTALON,EARTH_RADIUS
     else
        write(outfile_diagnostics,*) " *** error: wrong projection"
        stop
     endif
     write(outfile_diagnostics,*) "done writing third record"

     WRITE (outfile_intermediate) IS_WIND_EARTH_REL
     write(outfile_diagnostics,*) "done writing IS_WIND_EARTH_REL=",IS_WIND_EARTH_REL

     do i=1,nx_CAM; do j=1,ny_CAM
        SLAB(i,j)=field2d_data(ifield,i,j,1)
     end do; end do
     WRITE(outfile_intermediate) SLAB
     write(outfile_diagnostics,*) "done writing slab"

  enddo ! do loop over 2d fields

  ! loop over all soil levels and output 3d soil fields to the intermediate format
  ! ==============================================================================
  do k=1,nz_soil

     write(outfile_diagnostics,*) " outputing soil variables for k=",k

     ! go over all soil fields and output them to the intermediate format
     ! =================================================================
     do ifield=1,nfields_soil-1

        write(outfile_diagnostics,*) "writing soil fields in intermediate format: ifield=" &
             ,ifield, "; field=",field_soil_name_to_output(ifield,k)

        write (outfile_intermediate, IOSTAT=IERR) IFV
        write(outfile_diagnostics,*) "done writing IFV"

        ! WRITE the second record, common to all projections:
        ! HDATE=  this is read from input file.
        XFCST=0.0
        MAP_SOURCE="##CAM run from dorian###########"
        FIELD=field_soil_name_to_output(ifield,k)
        UNITS=field_soil_units(ifield,:)
        DESC=field_soil_DESC(ifield,:)
        XLVL=200100
        NX=nx_CAM
        NY=ny_CAM
        IPROJ=0 ! CAM data are on a gaussian grid  XX right?
        write (outfile_intermediate) HDATE,XFCST,MAP_SOURCE,FIELD,UNITS,DESC,XLVL,NX,NY,IPROJ
        write(outfile_diagnostics,*) "done writing second record, date:" &
             , HDATE//"  ", FIELD,"; xlvl=",xlvl

        ! WRITE the third record, which depends on the projection:

        if (IPROJ == 0) then 

           ! Gaussian projection
           STARTLOC="SWCORNER"
           STARTLAT=lat(1)
           STARTLON=lon(1)
           NLATS=ny_CAM/2 ! number of latitudes north of equator
           DELTALON=lon(2)-lon(1)
           DELTALAT=lat(2)-lat(1)
           WRITE (outfile_intermediate) STARTLOC,STARTLAT,STARTLON,DELTALAT,DELTALON,EARTH_RADIUS
        else
           write(outfile_diagnostics,*) " *** error: wrong projection"
           stop
        endif
        write(outfile_diagnostics,*) "done writing third record"

        WRITE (outfile_intermediate) IS_WIND_EARTH_REL
        write(outfile_diagnostics,*) "done writing IS_WIND_EARTH_REL=",IS_WIND_EARTH_REL

        do i=1,nx_CAM; do j=1,ny_CAM
           SLAB(i,j)=field_soil_data(ifield,i,j,k,1)
        end do; end do
        WRITE (outfile_intermediate) SLAB
        write(outfile_diagnostics,*) "done writing slab"

     enddo ! do loop over soil fields

  enddo ! do loop over soil levels


  ! Write SST to the intermediate format:
  ! =====================================
  if (.false.) then
     write(outfile_diagnostics,*) "writing SST in intermediate format, date=" &
          ,HDATE
     write (outfile_intermediate_SST, IOSTAT=IERR) IFV
     write(outfile_diagnostics,*) "done writing IFV"

     ! WRITE the second record, common to all projections:
     ! HDATE=  this is read from input file.
     XFCST=0.0
     MAP_SOURCE="##CAM run from dorian###########"
     FIELD=field_name_to_output(ifield)
     UNITS=field2d_units(i2d_SKINTEMP,:)
     DESC=field2d_DESC(i2d_SKINTEMP,:)
     XLVL=P_int(k)
     NX=nx_CAM
     NY=ny_CAM
     IPROJ=0 ! CAM data are on a gaussian grid  XX right?
     write (outfile_intermediate_SST) HDATE,XFCST,MAP_SOURCE,FIELD,UNITS,DESC,XLVL,NX,NY,IPROJ
     write(outfile_diagnostics,*) "done writing second record, date:" &
          , HDATE//"  ", FIELD,"; xlvl=",xlvl

     ! WRITE the third record, which depends on the projection:

     if (IPROJ == 0) then 
        ! Gaussian projection
        STARTLOC="SWCORNER"
        STARTLAT=lat(1)
        STARTLON=lon(1)
        NLATS=ny_CAM/2 ! number of latitudes north of equator
        DELTALON=lon(2)-lon(1)
        DELTALAT=lat(2)-lat(1)
        WRITE (outfile_intermediate_SST) STARTLOC,STARTLAT,STARTLON,DELTALAT,DELTALON,EARTH_RADIUS
     else
        write(outfile_diagnostics,*) " *** error: wrong projection"
        stop
     endif
     write(outfile_diagnostics,*) "done writing third record"

     WRITE (outfile_intermediate_SST) IS_WIND_EARTH_REL
     write(outfile_diagnostics,*) "done writing IS_WIND_EARTH_REL=",IS_WIND_EARTH_REL

     SLAB=field2d_data(i2d_SKINTEMP,:,:,1)
     WRITE (outfile_intermediate_SST) SLAB
     write(outfile_diagnostics,*) "done writing slab; slab(1,1)=",slab(1,1)
  end if
  ! ----------- end of writing SST 

  ! close output intermediate format files:
  close(outfile_intermediate)
  ! close(outfile_intermediate_SST)

  return 
end Subroutine write_intermediate_format_file


