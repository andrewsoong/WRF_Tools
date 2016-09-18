program convertgeog
implicit none
! for 'wmcat.53x36.wrf.dat'
!integer, parameter :: nx=53,ny=36
! for 'wrf4.cat.mat.dat'
integer, parameter :: nx=100,ny=100
real, dimension(nx, ny) :: wmcat
integer :: i,j

!open(7,file='wmcat.53x36.wrf.dat')
open(7,file='wrf4.cat.mat.dat')
read(7,*)((wmcat(i,j),i=1,nx),j=1,ny)

call write_geogrid(wmcat,nx,ny, 1,       0,      0,   1.0,    1)

!                              nz,   isign, endian, scale, byte)
!                                  0=unsgn, 0=big ,      ,
!                                  1=  sgn, 1=little ,   ,
close(7)

end program convertgeog