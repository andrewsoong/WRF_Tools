PROGRAM MAIN

!-----------------------------------------------------------------
!  Purpose:
!    To convert NCEP Stage IV data into the WRFDA-readable ASCII format.
!
!  Library: 
!    - G2LIB 
!    - W3LIB     (BAOPENR, GETGBH, GETGB, BACLOSE)
!      Download from: http://www.nco.ncep.noaa.gov/pmb/codes/GRIB2/ 
!
!  Subroutine called:
!    - W3FB07
!    - WRITERAINOBS
!
!  Input: 
!    - FILE_SUFFIX   
!      It will be used in the output file name. Example: 2008020518.06h  
!    - DATA_TIME
!      Observation time.  Example: 2008-02-05_17:59:59     
!    - DAT_DIR
!      NCEP ST4 data directory.
!   
!  Output: 
!    - ob.rain.yyyymmddhh.xxh
!      Example: ob.rain.2008020518.06h
!
!  Usage: 
!    - ./write_rainobs.exe  FILE_SUFFIX  DATA_TIME  DAT_DIR 
!       Example: ./write_rainobs.exe  2008020518.06h 2008-02-05_17:59:59 ./ 
!    - Or, assign ${FILE_SUFFIX}, ${DATA_TIME} and ${DAT_DIR} in 'run.ksh',
!      then run the .ksh like this "run.ksh". 
!
!  History:
!    Mar. 2012   Junmei Ban
!-----------------------------------------------------------------

   IMPLICIT NONE

   INTEGER, PARAMETER           :: MAX=1000000, &
                                   UNIT=19
   REAL, PARAMETER              :: MISSING_R=-888888. 
   INTEGER                      :: IRET,       &  ! INTEGER RETURN CODE  
                                   LUGI,       &  ! INTEGER UNIT OF THE UNBLOCKED GRIB INDEX FILE
                                   J,          &  ! INTEGER NUMBER OF MESSAGES TO SKIP
                                   KG,         &  ! INTEGER NUMBER OF BYTES IN THE GRIB MESSAGE 
                                   KF,         &  ! INTEGER NUMBER OF DATA POINTS IN THE MESSAGE
                                   KR,         &  ! INTEGER MESSAGE NUMBER UNPACKED 
                                   I,          &  !
                                   IM,         &  !
                                   JM,         &  !
                                   N              !
   INTEGER                      :: JPDS(200),  &  ! INTEGER (200) PDS(PRODUCT DEFINITION SECTION) PARAMETERS FOR WHICH TO SEARCH 
                                   JGDS(200),  &  ! INTEGER (200) GDS(GRID DESCRIPTION SECTION) PARAMETERS FOR WHICH TO SEARCH
                                   KPDS(200),  &  ! ARRAY CONTAINING PDS ELEMENTS
                                   KGDS(200)      ! ARRAY CONTAINING GDS ELEMENTS
   
   REAL                         :: XI,         &  ! I COORDINATE OF THE POINT
                                   XJ,         &  ! J COORDINATE OF THE POINT
                                   ALAT1,      &  ! LATITUDE  OF LOWER LEFT POINT OF GRID
                                   ALON1,      &  ! LONGITUDE OF LOWER LEFT POINT OF GRID 
                                   DX,         &  ! MESH LENGTH OF GRID IN METERS
                                   ALONV,      &  ! THE ORIENTATION OF THE GRID
                                   ALATL,      &  ! LATITUDE IN DEGREES
                                   ALONL          ! LONGITUDE IN DEGREES         
   REAL, ALLOCATABLE            :: LAT(:),     &  !
                                   LON(:),     &  !
                                   PCP(:)         !
   LOGICAL(KIND=1), ALLOCATABLE :: LB(:)          ! UNPACKED BITMAP
   CHARACTER(len=14)            :: SUFFIX 
   CHARACTER(len=19)            :: DATE 
   CHARACTER(len=80)            :: DAT_DIR 

   ALLOCATE(LAT(MAX))
   ALLOCATE(LON(MAX))
   ALLOCATE(PCP(MAX)) 
   ALLOCATE(LB(MAX))
   CALL GETARG(1, SUFFIX)
   CALL GETARG(2, DATE)
   CALL GETARG(3, DAT_DIR)

!
!  1.1 OPEN A GRIB FILE  
!  --------------------

   CALL BAOPENR(UNIT, TRIM(DAT_DIR)//"/"//"ST4."//TRIM(SUFFIX), IRET)
   IF (IRET .NE. 0) STOP 'Problem opening a grib file --- baopen'

!
!  1.2 READ GRIB HEADER TO GET DIMENSIONS
!  --------------------------------------
   LUGI = 0       ! =0 TO SEARCH FROM BEGINNING
      J = 0       ! INTEGER NUMBER OF MESSAGES TO SKIP
                  !   (=0 TO SEARCH FROM BEGINNING)
                  !   (<0 TO READ INDEX BUFFER AND SKIP -1-J MESSAGES)
   JPDS = -1      ! INTEGER (200) PDS PARAMETERS FOR WHICH TO SEARCH  (=-1 FOR WILDCARD)
   JGDS = -1      ! INTEGER (200) GDS PARAMETERS FOR WHICH TO SEARCH  (=-1 FOR WILDCARD)

  CALL GETGBH(UNIT, LUGI, J, JPDS, JGDS, KG, KF, KR, KPDS, KGDS, IRET)
  IF (IRET .NE. 0) STOP 'Problem finding a grib message --- getgbh'

!
!  1.3 GET LB AND UNPACK DATA(PCP) 
!  -------------------------------
  CALL GETGB(UNIT, LUGI, KF, J, JPDS, JGDS, KF, KR, KPDS, KGDS, LB, PCP, IRET)
  IF (IRET .NE. 0) STOP 'Problem finding or unpacking a grib message --- getgb'

!
!  1.4 CLOSE GRIB FILE
!  -------------------
  CALL BACLOSE(UNIT, IRET) 


!  2. FIND THE LAT/LON LOCATION OF A GRID POINT
!     http://www.emc.ncep.noaa.gov/mmb/ylin/pcpanl/QandA/#GRIDLOLA
!  ---------------------------------------------------------------

   IM = KGDS(2)             
   JM = KGDS(3)              
   ALAT1 = KGDS(4)*0.001    
   ALON1 = KGDS(5)*0.001    
   ALONV = KGDS(7)*0.001   
   DX = KGDS(8)             
   N = 0 
   do J = 1, JM 
      do I = 1, IM 
         XI = I * 1.0
         XJ = J * 1.0
         CALL W3FB07(XI, XJ, ALAT1, ALON1, DX, ALONV, ALATL, ALONL)
         N = N + 1
         LAT(N) = ALATL
         LON(N) = ALONL
      END DO
   END DO 

!
!  3. ASSIGN MISSING VALUE
!  -----------------------

   DO I = 1, N
      IF (.NOT. LB(I)) PCP(I) = -888888.
   END DO

!
!  4. WRITE PRECIPTATION OBS 
!  -------------------------
   CALL WRITERAINOBS(N, LAT, LON, DATE, MISSING_R, SUFFIX, PCP)
   
   DEALLOCATE (LAT) 
   DEALLOCATE (LON)
   DEALLOCATE (PCP)
   DEALLOCATE (LB)
END PROGRAM

!
! SUBROUTINE  W3FB07
! http://www.emc.ncep.noaa.gov/mmb/ylin/pcpanl/QandA/sorc/w3fb07.f
! ----------------------------------------------------------------

SUBROUTINE W3FB07(XI, XJ, ALAT1, ALON1, DX, ALONV, ALAT, ALON)
   DATA  RERTH /6.3712E+6/,PI/3.1416/
   DATA  SS60  /1.86603/
   IF (DX .LT. 0) THEN
      H      = -1.0
      DXL    = -DX
      REFLON = ALONV - 90.0
   ELSE
      H      = 1.0
      DXL    = DX
      REFLON = ALONV - 270.0
   ENDIF
      RADPD  = PI    / 180.0
      DEGPRD = 180.0 / PI
      REBYDX = RERTH / DXL
      ALA1 =  ALAT1 * RADPD
      RMLL = REBYDX * COS(ALA1) * SS60/(1. + H * SIN(ALA1))
      ALO1 = (ALON1 - REFLON) * RADPD
      POLEI = 1. - RMLL * COS(ALO1)
      POLEJ = 1. - H * RMLL * SIN(ALO1)
      XX =  XI - POLEI
      YY = (XJ - POLEJ) * H
      R2 =  XX**2 + YY**2
      IF (R2.EQ.0) THEN
         ALAT = H * 90.
         ALON = REFLON
      ELSE
         GI2    = (REBYDX * SS60)**2
         ALAT   = DEGPRD * H * ASIN((GI2 - R2)/(GI2 + R2))
         ARCCOS = ACOS(XX/SQRT(R2))
         IF (YY.GT.0) THEN
            ALON = REFLON + DEGPRD * ARCCOS
         ELSE
            ALON = REFLON - DEGPRD * ARCCOS
         ENDIF
      ENDIF
         IF (ALON.LT.0) ALON = ALON + 360.
   RETURN
   END

!
!  SUBROUTINE WRITERAINOBS
! -------------------------------------------------

SUBROUTINE WRITERAINOBS (N, LAT, LON, DATE, MISSING_R, SUFFIX, RAIN)

   IMPLICIT NONE

   INTEGER, INTENT(IN)       :: N
   REAL, INTENT(IN)          :: LAT(N)
   REAL, INTENT(IN)          :: LON(N) 
   REAL, INTENT(IN)          :: MISSING_R
   CHARACTER*(*), INTENT(IN) :: DATE
   CHARACTER*(*), INTENT(IN) :: SUFFIX   
   REAL, INTENT(INOUT)       :: RAIN(N)
   INTEGER                   :: I    
   CHARACTER(LEN=80)         :: FILENAME  
   CHARACTER(LEN=120)        :: FMT_INFO,    &
                                FMT_SRFC,    &
                                FMT_EACH
   LOGICAL                   :: CONNECTED

! 1. FORMAT
! --------- 

   !INFO  = PLATFORM, DATE, LEVELS, LATITUDE, LONGITUDE, ELEVATION, ID.
   !EACH  = HEIGHT, RAINFALL DATA, QC, ERROR
   FMT_INFO = '(A12, 1X, A19, 1X, I6, 2(F12.3,2X), F8.1, 1X, A5)'
   FMT_EACH = '(F12.3, F12.3, I4, F12.3)'


! 2. OPEN A FILE FOR OBSERVATIONS OUTPUT
! --------------------------------------

! 2.1 OUTPUT FILE 
! ---------------

   WRITE(FILENAME, FMT = '(A, A)') 'ob.rain.', SUFFIX   
   WRITE(0, '(A)') 'Write precipitation data ' 

   INQUIRE (UNIT = 999, OPENED = CONNECTED)
   IF (.NOT. CONNECTED) THEN
      OPEN (UNIT= 999,            &
           FILE = FILENAME,       &
           FORM = 'FORMATTED',    & 
           ACCESS = 'SEQUENTIAL', &
           STATUS = 'REPLACE')
   END IF
   REWIND (UNIT = 999) 

! 3. FILE HEADER AND DATA
! -----------------------

! 3.1 TOTAL NUMBER OF OBSERVATIONS CONTAINED IN FILE
! ---------------------------------------------------
   WRITE(UNIT = 999, FMT = '((A,I7),A)', ADVANCE = 'no')  &      
   "TOTAL =", N,","

! 3.2 MISSING VALUE FLAG 
! ------------------------

   WRITE(UNIT = 999, FMT = '((A, F8.0), A)') "MISS. =", MISSING_R,","

! 3.3 FORMAT 
! ------------

   WRITE(UNIT = 999, FMT = '(A)')  & 
      "INFO  = PLATFORM, DATE, LEVELS, LATITUDE, LONGITUDE, ELEVATION, ID."
   WRITE(UNIT = 999, FMT = '(A)' ) &
      "EACH  = HEIGHT, RAINFALL DATA, QC, ERROR"

! 3.4 DATA 
! --------

   WRITE (UNIT = 999, FMT = '(A)') &
   "#------------------------------------------------------------------------------#"
   DO I=1,N
         WRITE(UNIT = 999, FMT = TRIM(FMT_INFO))   & 
             "FM-129 RAIN ", DATE, 1, LAT(I), LON(I),99.9, "12345"
         WRITE(UNIT = 999, FMT = TRIM(FMT_EACH))   &
             99.9, RAIN(I), 88, 2.000
   END DO   

   CLOSE(999)

END SUBROUTINE WRITERAINOBS
