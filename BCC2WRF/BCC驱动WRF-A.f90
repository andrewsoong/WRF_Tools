program main
implicit none

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!                    Variables below are need when we want to write into intermediate format                        !
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

integer :: version=5                                                        ! Format version (must =5 for WPS format)
integer,parameter :: nx=128, ny=64, nt=1460, nz=26                                    ! x- and y-dimensions of 2-d array
integer :: iproj=4                                                          ! Code for projection of data in array:
                                                                            ! 4 = Gaussian (global only!)
real :: nlats=32                                                            ! Number of latitudes north of equator
                                                                            ! (for Gaussian grids)
real :: xfcst=0                                                             ! Forecast hour of data
real :: xlvl=26                                                             ! Vertical level      
real :: startlat=-87.8638, startlon=0                                       ! Lat/lon of point in array indicated by
real :: deltalat=2.7673, deltalon=2.8125                                    ! Grid spacing, degrees
real :: dx=1.181168, dy=1.125966                                            ! Grid spacing, km
real :: xlonc=0                                                             ! Standard longitude of projection
real :: earth_radius=6367.470                                               ! Earth radius, km
logical :: is_wind_grid_rel=.false.                                         ! Flag indicating whether winds are
                                                                            ! relative to source grid (TRUE) or
                                                                            ! relative to earth (FALSE)
character (len=8) :: startloc="SWCORNER"                                    ! Which point in array is given by
                                                                            ! startlat/startlon; set either
                                                                            ! to 'SWCORNER' or 'CENTER '
character (len=9) :: field(6)                                               ! Name of the field in the netcdf file
character (len=24) :: hdate                                                 ! Valid date for data YYYY:MM:DD_HH:00:00
character (len=25) :: units(6)                                              ! Units of data
character (len=32) :: map_source="BCC"                                      ! Source model / originating center
character (len=46) :: desc(6)                                               ! Short description of data

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!                Variables below are used when we do coordiante transformation and use wps                          !
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

real,allocatable :: T_sigma(:,:,:,:),P_surface(:,:,:),RH_sigma(:,:,:,:),U_sigma(:,:,:,:),V_sigma(:,:,:,:)
real,allocatable :: SEA_PRESSURE(:,:,:),PSL(:,:,:)
character*100 :: filepath
integer :: year,mon,day,hour,mon_day(12),lev,time,xx,yy
character*4 :: iyear
character*2 :: imon(12),iday(31),ihour(4)
integer,parameter::nvar=6,ntsea=1956
character (len=9) :: fieldname(6)
character*100 :: filetimename
integer :: ounit=1
real::a(nz),b(nz)
real::p0


allocate(T_sigma(nx,ny,nz,nt))
allocate(P_surface(nx,ny,nt))
allocate(RH_sigma(nx,ny,nz,nt))
allocate(U_sigma(nx,ny,nz,nt))
allocate(V_sigma(nx,ny,nz,nt))
allocate(SEA_PRESSURE(nx,ny,ntsea))
allocate(PSL(nx,ny,12))

field(1)="ta" ; units(1)="K"   ; desc(1)="Air Temperature"      ; fieldname(1)="TT"
field(2)="ps" ; units(2)="Pa"  ; desc(2)="Surface Air Pressure" ; fieldname(2)="PSFC"
field(3)="hus"; units(3)="kg/kg"   ; desc(3)="Specific Humidity"    ; fieldname(3)="SPECHUMD"
field(4)="ua" ; units(4)="ms-1"; desc(4)="Eastward Wind"        ; fieldname(4)="UU"
field(5)="va" ; units(5)="ms-1"; desc(5)="Northward Wind"       ; fieldname(5)="VV"
field(6)="psl"; units(6)="Pa"  ; desc(6)="Sea Level Pressure"   ; fieldname(6)="PMSL"


imon=(/"01","02","03","04","05","06","07","08","09","10","11","12"/)
iday=(/"01","02","03","04","05","06","07","08","09","10","11","12","13","14","15",  &
       "16","17","18","19","20","21","22","23","24","25","26","27","28","29","30","31"/)
ihour=(/"00","06","12","18"/)
mon_day=(/31,28,31,30,31,30,31,31,30,31,30,31/)


filepath="/home/qianqf/psl_Amon_bcc-csm1-1_historical_r1i1p1_185001-201212.nc"
call read_bcc_data_2D(filepath,SEA_PRESSURE,field(6),nx,ny,ntsea)

do time=1,12
  do xx=1,nx
    do yy=1,ny
      PSL(xx,yy,time)=sum(SEA_PRESSURE(xx,yy,time::12))/163.0
    end do
  end do
end do
time=0


do year=1950,2007
  
  write(iyear,'(I4)')year
  time=0
  
  filepath="/home3_hn/climateftp/research/climate_data/global_data/BCC/historical/"//iyear//"/bcc.air."//iyear//".nc"
  call read_bcc_data_3D(filepath,T_sigma,field(1),nx,ny,nz,nt)
  filepath="/home3_hn/climateftp/research/climate_data/global_data/BCC/historical/"//iyear//"/bcc.pres."//iyear//".nc"
  call read_bcc_data_2D(filepath,P_surface,field(2),nx,ny,nt)
  filepath="/home3_hn/climateftp/research/climate_data/global_data/BCC/historical/"//iyear//"/bcc.shum."//iyear//".nc"
  call read_bcc_data_3D(filepath,RH_sigma,field(3),nx,ny,nz,nt)
  filepath="/home3_hn/climateftp/research/climate_data/global_data/BCC/historical/"//iyear//"/bcc.uwnd."//iyear//".nc"
  call read_bcc_data_3D(filepath,U_sigma,field(4),nx,ny,nz,nt)
  filepath="/home3_hn/climateftp/research/climate_data/global_data/BCC/historical/"//iyear//"/bcc.vwnd."//iyear//".nc"
  call read_bcc_data_3D(filepath,V_sigma,field(5),nx,ny,nz,nt)
  
  do mon=1,12
    do day=1,mon_day(mon)
      do hour=1,4
        
        hdate=iyear//"-"//imon(mon)//"-"//iday(day)//"_"//ihour(hour)//":00:00"
        filetimename=iyear//"-"//imon(mon)//"-"//iday(day)//"_"//ihour(hour)
        filepath="/home3_hn/qianqf/historical/"//"FILE:"//filetimename
        open(unit=ounit,file=filepath,form='unformatted',access="sequential",status="unknown")
      
        time=time+1    ; print*,time
        
        
        write(unit=ounit) version
        write(unit=ounit) hdate, xfcst, map_source, fieldname(2), units(2), desc(2), 200100.000000, nx, ny, iproj
        write(unit=ounit) startloc, startlat, startlon, nlats, deltalon, earth_radius
        write(unit=ounit) is_wind_grid_rel
        write(unit=ounit) P_surface(:,:,time)
        
        
        write(unit=ounit) version
        write(unit=ounit) hdate, xfcst, map_source, fieldname(6), units(6), desc(6), 201300.000000, nx, ny, iproj
        write(unit=ounit) startloc, startlat, startlon, nlats, deltalon, earth_radius
        write(unit=ounit) is_wind_grid_rel
        write(unit=ounit) PSL(:,:,mon)
        

        write(unit=ounit) version
        write(unit=ounit) hdate, xfcst, map_source, fieldname(1), units(1),desc(1), 200100.0, nx, ny, iproj
        write(unit=ounit) startloc, startlat, startlon, nlats, deltalon,earth_radius
        write(unit=ounit) is_wind_grid_rel
        write(unit=ounit) T_sigma(:,:,1,time)
        
        write(unit=ounit) version
        write(unit=ounit) hdate, xfcst, map_source, fieldname(3), units(3),desc(3), 200100.0, nx, ny, iproj
        write(unit=ounit) startloc, startlat, startlon, nlats, deltalon,earth_radius
        write(unit=ounit) is_wind_grid_rel
        write(unit=ounit) RH_sigma(:,:,1,time) 
     
        write(unit=ounit) version
        write(unit=ounit) hdate, xfcst, map_source, fieldname(4), units(4),desc(4), 200100.0, nx, ny, iproj
        write(unit=ounit) startloc, startlat, startlon, nlats, deltalon,earth_radius
        write(unit=ounit) is_wind_grid_rel
        write(unit=ounit) U_sigma(:,:,1,time)
        
        write(unit=ounit) version
        write(unit=ounit) hdate, xfcst, map_source, fieldname(5), units(5),desc(5), 200100.0, nx, ny, iproj
        write(unit=ounit) startloc, startlat, startlon, nlats, deltalon,earth_radius
        write(unit=ounit) is_wind_grid_rel
        write(unit=ounit) V_sigma(:,:,1,time)
        
        
        do lev=nz,2,-1
      
          write(unit=ounit) version
          write(unit=ounit) hdate, xfcst, map_source, fieldname(1), units(1), desc(1), real(nz-lev+1), nx, ny, iproj
          write(unit=ounit) startloc, startlat, startlon, nlats, deltalon, earth_radius
          write(unit=ounit) is_wind_grid_rel
          write(unit=ounit) T_sigma(:,:,lev,time)
    
          write(unit=ounit) version
          write(unit=ounit) hdate, xfcst, map_source, fieldname(3), units(3), desc(3), real(nz-lev+1), nx, ny, iproj
          write(unit=ounit) startloc, startlat, startlon, nlats, deltalon, earth_radius
          write(unit=ounit) is_wind_grid_rel
          write(unit=ounit) RH_sigma(:,:,lev,time)
          
          write(unit=ounit) version
          write(unit=ounit) hdate, xfcst, map_source, fieldname(4), units(4), desc(4), real(nz-lev+1), nx, ny, iproj
          write(unit=ounit) startloc, startlat, startlon, nlats, deltalon, earth_radius
          write(unit=ounit) is_wind_grid_rel
          write(unit=ounit) U_sigma(:,:,lev,time)
          
          write(unit=ounit) version
          write(unit=ounit) hdate, xfcst, map_source, fieldname(5), units(5), desc(5), real(nz-lev+1), nx, ny, iproj
          write(unit=ounit) startloc, startlat, startlon, nlats, deltalon, earth_radius
          write(unit=ounit) is_wind_grid_rel
          write(unit=ounit) V_sigma(:,:,lev,time)
        
        end do
        
        close(unit=ounit)
    
      end do
    end do
  end do
end do

end program main




subroutine read_bcc_data_3D(filepath,Variable,Var_name,nx,ny,nz,nt)
use netcdf
implicit none
integer :: nx,ny,nz,nt
character*9 :: Var_name
real :: Variable(nx,ny,nz,nt)
character*100 :: filepath
integer::ncid,ncfile
integer::varidvar

ncfile=NF90_OPEN(filepath,nf90_nowrite,ncid)
ncfile=NF90_INQ_VARID(ncid,Var_name,varidvar)
ncfile=NF90_GET_VAR(ncid,varidvar,Variable)
ncfile=NF90_CLOSE(ncid)

end subroutine read_bcc_data_3D




subroutine read_bcc_data_2D(filepath,Variable,Var_name,nx,ny,nt)
use netcdf
implicit none
integer :: nx,ny,nt
character*9 :: Var_name
real :: Variable(nx,ny,nt)
character*100 :: filepath
integer::ncid,ncfile
integer::varidvar

ncfile=NF90_OPEN(filepath,nf90_nowrite,ncid)
ncfile=NF90_INQ_VARID(ncid,Var_name,varidvar)
ncfile=NF90_GET_VAR(ncid,varidvar,Variable)
ncfile=NF90_CLOSE(ncid)

end subroutine read_bcc_data_2D
