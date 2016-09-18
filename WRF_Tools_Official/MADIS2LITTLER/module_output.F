MODULE module_output

REAL, PARAMETER :: max_default = 888888.00, min_default = -888888.00 
CONTAINS

! SUBROUTINE write_littler_onelvl
! SUBROUTINE write_littler_sfc
! SUBROUTINE write_littler_upa
! SUBROUTINE write_littler_satem
! SUBROUTINE write_littler_bogus
! SUBROUTINE write_littler_qscat
! SUBROUTINE write_littler_bogus_ty
! SUBROUTINE write_littler_gpspw

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
subroutine write_littler_onelvl(pu, zu, tu, tdu, spdu, diru,  xlat, xlon, &
     hdate, stid , iunit, instring3)
  implicit none

  integer :: iunit

  real :: xlat, xlon
  real :: PU,ZU,TU,TDU,SPDU,DIRU
  character (len=*) :: stid

  character(len=20) :: date_char
  character(len=40) :: string1, string2 , string3
  CHARACTER (LEN=40) :: string4 = ' '
  character(len=*) :: instring3
  CHARACTER(len=84), parameter ::  rpt_format =  ' ( 2f20.5 , 2a40 , '  &
       // ' 2a40 , 1f20.5 , 5i10 , 3L10 , ' &
       // ' 2i10 , a20 ,  13( f13.5 , i7 ) ) '
  CHARACTER(len=22), parameter :: meas_format =  ' ( 10( f13.5 , i7 ) ) '
  CHARACTER(len=14), parameter :: end_format = ' ( 3 ( i7 ) ) ' 
  logical :: is_sound = .FALSE.
  logical :: bogus = .FALSE.
  integer :: iseq_num
  integer :: kx = 1
  real :: elev = min_default
  real :: slp = min_default

  character(len=*) :: hdate

  date_char = '      '//hdate(1:4)//hdate(5:8)//hdate(10:13)//'00'
  string1 = stid
  string2 = 'MADIS'
  string3 = trim(instring3)

  WRITE ( UNIT = iunit , ERR = 19 , FMT = rpt_format ) &
       xlat,xlon, string1 , string2 ,  &
       string3 , string4 , elev, kx*6, 0,0,0,0, &
       is_sound,bogus,.false., &
       -888888, -888888, date_char , &
       slp,0,-888888.,0, -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0, &
       -888888.,0, -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0,  -888888.,0, -888888.,0 

  if (( pu  > min_default  .and. pu < max_default ) .or. &
         (zu  > min_default  .and. zu < max_default )) then

      WRITE ( UNIT = iunit , ERR = 20 , FMT = meas_format ) &
              pu, 0, zu,0, tu,0, tdu,0, &
              spdu,0, diru,0, &
              -888888.,0, -888888.,0,-888888.,0, -888888.,0
  endif

  WRITE ( UNIT = iunit , ERR = 21 , FMT = meas_format ) &
       -777777.,0, -777777.,0,float(kx),0, &
       -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0

  WRITE ( UNIT = iunit , ERR = 22 , FMT = end_format )  kx, 0, 0

  return
19 continue
  print *,'Troubles writing a report. RPT'
  print*, xlat,xlon, string1 , string2 ,  &
       string3 , string4 , elev, kx*6, iseq_num, &
       is_sound,bogus, &
       date_char , &
       slp
  stop 19
20 continue
  print *,'Troubles writing a report. MEAS'
  stop 20
21 continue
  print *,'Troubles writing a report. MEAS'
  stop 21
22 continue
  print *,'Troubles writing a report. END'
  stop 22
  
end subroutine write_littler_onelvl

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
subroutine write_littler_sfc(psfc, pmsl, elev, &
     tu, tdu, spdu, diru,  xlat, xlon, &
     hdate, stid , iunit, instring3)
  implicit none

  integer :: iunit

  real :: xlat, xlon
  real :: psfc ! Surface pressure (Pa)
  real :: pmsl ! Sea-level pressure (Pa)
  real :: elev ! Station elevation (m)
  real :: TU,TDU,SPDU,DIRU
  character (len=*) :: stid

  character(len=20) :: date_char
  character(len=40) :: string1, string2 , string3
  CHARACTER (LEN=40) :: string4 = ' '
  character(len=*) :: instring3
  CHARACTER(len=84), parameter ::  rpt_format =  ' ( 2f20.5 , 2a40 , '  &
       // ' 2a40 , 1f20.5 , 5i10 , 3L10 , ' &
       // ' 2i10 , a20 ,  13( f13.5 , i7 ) ) '
  CHARACTER(len=22), parameter :: meas_format =  ' ( 10( f13.5 , i7 ) ) '
  CHARACTER(len=14), parameter :: end_format = ' ( 3 ( i7 ) ) ' 
  logical :: is_sound = .FALSE.
  logical :: bogus = .FALSE.
  integer :: iseq_num
  integer :: kx = 1

  character(len=*) :: hdate

  date_char = '      '//hdate(1:4)//hdate(5:8)//hdate(10:13)//'00'

  string1 = TRIM(stid)
  string2 = 'MADIS'
  string3 = trim(instring3)

  WRITE ( UNIT = iunit , ERR = 19 , FMT = rpt_format ) &
       xlat,xlon, string1 , string2 ,  &
       string3 , string4 , elev, kx*6, 0,0,0,0, &
       is_sound,bogus,.false., &
       -888888, -888888, date_char , &
       pmsl,0,-888888.,0, -888888.,0, -888888.,0, psfc,0, &
       -888888.,0, &
       -888888.,0, -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0,  -888888.,0, -888888.,0 

  if (( psfc  > min_default  .and. psfc < max_default ) .or. &
         (elev  > min_default  .and. elev < max_default )) then
 
       WRITE ( UNIT = iunit , ERR = 20 , FMT = meas_format ) &
               psfc,0, elev,0, tu,0, tdu,0, &
               spdu,0, diru,0, &
               -888888.,0, -888888.,0,-888888.,0, -888888.,0
  endif
  
  WRITE ( UNIT = iunit , ERR = 21 , FMT = meas_format ) &
       -777777.,0, -777777.,0,float(kx),0, &
       -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0

  WRITE ( UNIT = iunit , ERR = 22 , FMT = end_format )  kx, 0, 0

  return
19 continue
  print *,'Troubles writing a report RPT.'
  stop 19
20 continue
  print *,'Troubles writing a report MEAS.'
  print*, psfc, elev, tu, tdu, spdu, diru
  stop 20
21 continue
  print *,'Troubles writing a report MEAS.'
  stop 21
22 continue
  print *,'Troubles writing a report END.'
  stop 22
  
end subroutine write_littler_sfc

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
subroutine write_littler_upa (pu , zu , tu , tdu , spdu , diru , &
     elev, xlat, xlon , &
     hdate, stidu , lman , &
     iunit, instring3)

  integer :: iunit

  real :: xlat, xlon, elev
  real, DIMENSION(405) :: PU,ZU,TU,TDU,SPDU,DIRU
  character (len=5) :: stidu
  integer :: lman

  character *20 date_char
  character *40 string1, string2 , string3 
  CHARACTER (LEN=40) :: string4 = ' '
  CHARACTER (LEN=*) :: instring3
  CHARACTER(len=84), parameter ::  rpt_format =  ' ( 2f20.5 , 2a40 , '  &
       // ' 2a40 , 1f20.5 , 5i10 , 3L10 , ' &
       // ' 2i10 , a20 ,  13( f13.5 , i7 ) ) '
  CHARACTER *22  meas_format 
  CHARACTER *14  end_format
  logical :: is_sound = .TRUE.
  logical :: bogus = .FALSE.
  integer :: ls, lm
  integer :: iseq_num
  real :: slp
  integer :: i, kx

  character(len=*) :: hdate

  meas_format =  ' ( 10( f13.5 , i7 ) ) '
  end_format = ' ( 3 ( i7 ) ) ' 
  
  date_char = '      '//hdate(1:4)//hdate(5:8)//hdate(10:13)//'00'
  kx = lman 

  string1 = stidu
  string2 = 'MADIS'
  string3 = trim(instring3)

  slp = min_default
  WRITE ( UNIT = iunit , ERR = 19 , FMT = rpt_format ) &
       xlat,xlon, string1 , string2 ,  &
       string3 , string4 , elev, kx*6, 0,0,0,0, &
       is_sound,bogus,.false., &
       -888888, -888888, date_char , &
       slp,0,-888888.,0, -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0, &
       -888888.,0, -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0,  -888888.,0, -888888.,0 
   
  lm = 1

  do lm = 1, lman
    if (( pu(lm) > min_default  .and. pu(lm) < max_default ) .or. &
         ( zu(lm) > min_default  .and. zu(lm) < max_default )) then 
        if ( (tu(lm) /= -888888.00) .or.&
             (tdu(lm) /= -888888.00 ) .or.&
             (spdu(lm) /= -888888.00 ) .or.&
             (diru(lm) /= -888888.00 ) ) then
             
           WRITE ( UNIT = iunit , ERR = 19 , FMT = meas_format ) &
                pu(lm), 0, zu(lm),0, tu(lm),0, tdu(lm),0, &
                spdu(lm),0, diru(lm),0, &
                -888888.,0, -888888.,0,-888888.,0, -888888.,0
        endif
    endif
  enddo
  WRITE ( UNIT = iunit , ERR = 19 , FMT = meas_format ) &
       -777777.,0, -777777.,0,float(kx),0, &
       -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0
  WRITE ( UNIT = iunit , ERR = 19 , FMT = end_format )  kx, 0, 0

  return
19 continue
  print *,'troubles writing a sounding'
  print*, 'Integrated stuff:',lman
  do i = 1, lman
     write(*,*) pu(i), zu(i), tu(i),tdu(i), spdu(i), diru(i)
  enddo

  stop 19
  
end subroutine write_littler_upa

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
SUBROUTINE write_littler_satem ( p , thick, qctk, kx, ref, xlat , xlon , &
           string1 , string2 , string3 , string4 , sndg, bogus , iseq_num ,&
           iunit , ccyymmddhhmmss, ccper)

   implicit none

   integer                   :: k
   integer                   :: kx, iunit
   real, dimension (kx)      :: p, thick
   integer, dimension (kx)   :: qctk
   real                      :: ref, xlat, xlon
   integer                   :: ccper
   character (len=40)  :: string1, string2 , string3 , string4
   character (len=84)  :: rpt_format
   character (len=22)  :: meas_format
   character (len=14)  :: end_format

   character (len=14)  :: ccyymmddhhmmss
   integer :: yymmddhh, iseq_num
   logical :: bogus, sndg

   rpt_format='(2f20.5,2a40,2a40,1f20.5,5i10,3L10,2i10,a20,13(f13.5,i7))'
   meas_format =  ' ( 10( f13.5 , i7 ) ) '
   end_format = ' ( 3 ( i7 ) ) '

   WRITE ( UNIT = iunit , FMT = rpt_format ) &
           xlat,xlon, string1 (1:40), string2 (1:40),   &
           string3 (1:40), string4 (1:40), -888888.,    &
           kx*3, -888888,-888888,iseq_num,-888888, sndg,bogus,.false., &
           -888888, -888888, ccyymmddhhmmss , &
           -888888.,0, ref, 0, -888888.,0, -888888.,0, -888888.,0, &
           -888888.,0, -888888.,0, -888888.,0, -888888.,0, -888888.,0, &
           -888888.,0, real(ccper),0, -888888.,0

!     STOP

   do k=1,kx
     WRITE ( UNIT = iunit , FMT = meas_format ) &
             p(k), 0, -888888.,0, -888888.,0, -888888.,0, -888888.,0,   &
             -888888.,0, -888888.,0,-888888.,0, -888888.,0, thick(k), qctk(k)
   enddo

   WRITE ( UNIT = iunit , FMT = meas_format ) &
           -777777.,0, -777777.,0,float(kx),0,&
           -888888.,0, -888888.,0, -888888.,0,&
           -888888.,0, -888888.,0, -888888.,0,&
           -888888.,0

   WRITE ( UNIT = iunit , FMT = end_format )  kx, 0, 0

   return

END SUBROUTINE write_littler_satem

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
subroutine write_littler_bogus (pu , zu , tu , tdu , spdu , diru , &
     elev, xlat, xlon, uerr, verr, slperr, hdate, stidu , lman , &
     iunit, instring3)

  integer :: iunit

  real :: uerr, verr, slperr
  real :: xlat, xlon, elev
  real, DIMENSION(200) :: PU,ZU,TU,TDU,SPDU,DIRU
  character (len=5) :: stidu
  integer :: lman

  character *20 date_char
  character *40 string1, string2 , string3 
  CHARACTER (LEN=40) :: string4 = ' '
  CHARACTER (LEN=*) :: instring3
  CHARACTER(len=84), parameter ::  rpt_format =  ' ( 2f20.5 , 2a40 , '  &
       // ' 2a40 , 1f20.5 , 5i10 , 3L10 , ' &
       // ' 2i10 , a20 ,  13( f13.5 , i7 ) ) '
  CHARACTER *22  meas_format 
  CHARACTER *14  end_format
  logical :: is_sound = .TRUE.
  logical :: bogus = .TRUE.
  integer :: lm
  integer :: iseq_num
  real :: slp
  integer :: i, kx

  character(len=*) :: hdate

  meas_format =  ' ( 10( f13.5 , i7 ) ) '
  end_format = ' ( 3 ( i7 ) ) ' 

  date_char(7:16) = hdate(1:4)//hdate(6:7)//hdate(9:10)//hdate(12:13)
  date_char(17:20)='0000'
  date_char(1:6)='      '

  kx = lman

  string1 = stidu
  string2 = 'MADIS'
  string3 = trim(instring3)

  slp = -999999.

  WRITE ( UNIT = iunit , ERR = 19 , FMT = rpt_format ) &
       xlat,xlon, string1 , string2 ,  &
       string3 , string4 , elev, kx*6, 0,0,0,0, &
       is_sound,bogus,.false., &
       -888888, -888888, date_char , &
       slp,0,-888888.,0, -888888.,0, -888888.,0, slperr,0, &
       -888888.,0, &
       -888888.,0, -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0,  -888888.,0, -888888.,0 
   
  lm = 1

  DO WHILE ( lm <= lman )
     IF ( (tu(lm).gt.-80000) .or. (tdu(lm).gt.-80000) .or.  &
          (spdu(lm).gt.-80000) .or. (diru(lm).gt.-80000)  ) THEN
            
         WRITE ( UNIT = iunit , ERR = 19 , FMT = meas_format ) &
              pu(lm), 0, zu(lm),0, tu(lm),0, tdu(lm),0, &
              spdu(lm),0, diru(lm),0, &
              uerr,0, verr,0,-888888.,0, -888888.,0
      ENDIF
      lm = lm + 1
  ENDDO

  WRITE ( UNIT = iunit , ERR = 19 , FMT = meas_format ) &
       -777777.,0, -777777.,0,float(kx),0, &
       -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0
  WRITE ( UNIT = iunit , ERR = 19 , FMT = end_format )  kx, 0, 0

  return
19 continue
  print *,'troubles writing a sounding'
  print*, 'Mandatory stuff:',lman
  do i = 1, lman
     write(*,*) pu(i), zu(i), tu(i), spdu(i), diru(i)
  enddo

  stop 19
  
end subroutine write_littler_bogus

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
subroutine write_littler_qscat(psfc, pmsl, elev, &
     tu, tdu, spdu, diru,  xlat, xlon, direrr, spderr, &
     hdate, stid , iunit, instring3)
  implicit none

  integer :: iunit

  real :: direrr, spderr
  real :: xlat, xlon
  real :: psfc ! Surface pressure (Pa)
  real :: pmsl ! Sea-level pressure (Pa)
  real :: elev ! Station elevation (m)
  real :: TU,TDU,SPDU,DIRU
  character (len=*) :: stid

  character(len=20) :: date_char
  character(len=40) :: string1, string2 , string3
  CHARACTER (LEN=40) :: string4 = ' '
  character(len=*) :: instring3
  CHARACTER(len=84), parameter ::  rpt_format =  ' ( 2f20.5 , 2a40 , '  &
       // ' 2a40 , 1f20.5 , 5i10 , 3L10 , ' &
       // ' 2i10 , a20 ,  13( f13.5 , i7 ) ) '
  CHARACTER(len=22), parameter :: meas_format =  ' ( 10( f13.5 , i7 ) ) '
  CHARACTER(len=14), parameter :: end_format = ' ( 3 ( i7 ) ) ' 
  logical :: is_sound = .FALSE.
  logical :: bogus = .FALSE.
  integer :: iseq_num
  integer :: kx = 1

  character(len=*) :: hdate

  date_char = '      '//hdate(1:4)//hdate(6:7)//hdate(9:10)//hdate(12:13)&
       //hdate(15:16)//'00'

  string1 = TRIM(stid)
  string2 = 'MADIS'
  string3 = trim(instring3)

  WRITE ( UNIT = iunit , ERR = 19 , FMT = rpt_format ) &
       xlat,xlon, string1 , string2 ,  &
       string3 , string4 , elev, kx*6, 0,0,0,0, &
       is_sound,bogus,.false., &
       -888888, -888888, date_char , &
       pmsl,0,-888888.,0, -888888.,0, -888888.,0, psfc,0, &
       -888888.,0, &
       -888888.,0, -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0,  -888888.,0, -888888.,0 
   
  WRITE ( UNIT = iunit , ERR = 20 , FMT = meas_format ) &
       psfc,0, elev,0, tu,0, tdu,0, &
       spdu,0, diru,0, &
       spderr, 0, direrr, 0,-888888.,0, -888888.,0
!       -888888.,0, -888888.,0,-888888.,0, -888888.,0

  WRITE ( UNIT = iunit , ERR = 21 , FMT = meas_format ) &
       -777777.,0, -777777.,0,float(kx),0, &
       -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0

  WRITE ( UNIT = iunit , ERR = 22 , FMT = end_format )  kx, 0, 0

  return
19 continue
  print *,'Troubles writing a report RPT.'
  stop 19
20 continue
  print *,'Troubles writing a report MEAS.'
  print*, psfc, elev, tu, tdu, spdu, diru
  stop 20
21 continue
  print *,'Troubles writing a report MEAS.'
  stop 21
22 continue
  print *,'Troubles writing a report END.'
  stop 22
  
end subroutine write_littler_qscat

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
subroutine write_littler_bogus_ty (pu , zu , tu , tdu , spdu , diru , &
     elev, xlat, xlon, slp, uerr, verr, slperr, hdate, stidu , lman,       &
     iunit, instring3)

  integer :: iunit

  real :: slperr, slp
  real :: xlat, xlon, elev
  real, DIMENSION(200) :: PU,ZU,TU,TDU,SPDU,DIRU, uerr, verr
  character (len=5) :: stidu
  integer :: lman

  character *20 date_char
  character *40 string1, string2 , string3 
  CHARACTER (LEN=40) :: string4 = ' '
  CHARACTER (LEN=*) :: instring3
  CHARACTER(len=84), parameter ::  rpt_format =  ' ( 2f20.5 , 2a40 , '  &
       // ' 2a40 , 1f20.5 , 5i10 , 3L10 , ' &
       // ' 2i10 , a20 ,  13( f13.5 , i7 ) ) '
  CHARACTER *22  meas_format 
  CHARACTER *14  end_format
  logical :: is_sound = .TRUE.
  logical :: bogus = .TRUE.
  integer :: lm
  integer :: iseq_num
  integer :: i, kx

  character(len=*) :: hdate

  meas_format =  ' ( 10( f13.5 , i7 ) ) '
  end_format = ' ( 3 ( i7 ) ) ' 

  date_char(7:16) = hdate(1:4)//hdate(6:7)//hdate(9:10)//hdate(12:13)
  date_char(17:20)='0000'
  date_char(1:6)='      '

  kx = lman

  string1 = stidu
  string2 = 'MADIS'
  string3 = trim(instring3)

!  slp = -999999.

  WRITE ( UNIT = iunit , ERR = 19 , FMT = rpt_format ) &
       xlat,xlon, string1 , string2 ,  &
       string3 , string4 , elev, kx*6, 0,0,0,0, &
       is_sound,bogus,.false., &
       -888888, -888888, date_char , &
       slp,0,-888888.,0, -888888.,0, -888888.,0, slperr,0, &
       -888888.,0, &
       -888888.,0, -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0,  -888888.,0, -888888.,0 
   
  lm = 1

  DO WHILE ( lm <= lman )
     IF ( (tu(lm).gt.-80000) .or. (tdu(lm).gt.-80000) .or.  &
          (spdu(lm).gt.-80000) .or. (diru(lm).gt.-80000)  ) THEN
            
         WRITE ( UNIT = iunit , ERR = 19 , FMT = meas_format ) &
              pu(lm), 0, zu(lm),0, tu(lm),0, tdu(lm),0, &
              spdu(lm),0, diru(lm),0, &
              uerr(lm), 0, verr(lm), 0,-888888.,0, -888888.,0
      ENDIF
      lm = lm + 1
  ENDDO

  WRITE ( UNIT = iunit , ERR = 19 , FMT = meas_format ) &
       -777777.,0, -777777.,0,float(kx),0, &
       -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0
  WRITE ( UNIT = iunit , ERR = 19 , FMT = end_format )  kx, 0, 0

  return
19 continue
  print *,'troubles writing a sounding'
  print*, 'Mandatory stuff:',lman
  do i = 1, lman
     write(*,*) pu(i), zu(i), tu(i), spdu(i), diru(i)
  enddo

  stop 19
  
end subroutine write_littler_bogus_ty


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
subroutine write_littler_gpspw(pmsl, pwv, elev, xlat, xlon, &
     hdate, stid , iunit, instring3)
  implicit none

  integer :: iunit

  real :: xlat, xlon
  real :: pmsl ! Sea-level pressure (Pa)
  real :: elev ! Station elevation (m)
  real :: pwv  ! Precipitable water vapor (m)
  character (len=*) :: stid

  character(len=20) :: date_char
  character(len=40) :: string1, string2 , string3
  CHARACTER (LEN=40) :: string4 = ' '
  character(len=*) :: instring3
  CHARACTER(len=84), parameter ::  rpt_format =  ' ( 2f20.5 , 2a40 , '  &
       // ' 2a40 , 1f20.5 , 5i10 , 3L10 , ' &
       // ' 2i10 , a20 ,  14( f13.5 , i7 ) ) '
  CHARACTER(len=22), parameter :: meas_format =  ' ( 10( f13.5 , i7 ) ) '
  CHARACTER(len=14), parameter :: end_format = ' ( 3 ( i7 ) ) '
  logical :: is_sound = .FALSE.
  logical :: bogus = .FALSE.
  integer :: iseq_num
  integer :: kx = 1

  character(len=*) :: hdate

  date_char = '      '//hdate(1:4)//hdate(5:8)//hdate(10:13)//'00'

  string1 = TRIM(stid)
  string2 = 'MADIS'
  string3 = trim(instring3)

 if (( pwv  > min_default  .and. pwv < max_default )) then 
    WRITE ( UNIT = iunit , ERR = 19 , FMT = rpt_format ) &
       xlat,xlon, string1 , string2 ,  &
       string3 , string4 , elev, kx*6, 0,0,0,0, &
       is_sound,bogus,.false., &
       -888888, -888888, date_char , &
       pmsl,0,-888888.,0, -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0, &
       -888888.,0, -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0,  -888888.,0, -888888.,0,pwv,0

 WRITE ( UNIT = iunit , ERR = 19 , FMT = meas_format ) &
       -777777.,0, -777777.,0,float(kx),0, &
       -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0, -888888.,0, -888888.,0, &
       -888888.,0
 WRITE ( UNIT = iunit , ERR = 19 , FMT = end_format )  kx, 0, 0

 end if

  return
19 continue
  print *,'troubles writing a gpspw'

  stop 19

end subroutine write_littler_gpspw


END MODULE module_output
