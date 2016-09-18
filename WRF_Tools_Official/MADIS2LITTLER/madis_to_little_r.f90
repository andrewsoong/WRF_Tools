program madis_to_little_r

!--------------------------------------------------------------------------------------------- 
!  Purpose : To convert MADIS to "little_r" format.
!  
!  History:
!  2003-2008 Used Mike Barth's da_setup_obs_structures_madis codes to read MADIS data
!  May  2009  Ruifang Li, Yong-Run Guo     Extended the code for OBSPROC usage
!  Jul. 2009  Meral Demirta    Introduced some changes to make it flexible
!  	                       for unattended/extensive runs.	  		
!  May  2011  Ruifang Li       Added namelist file, metar datatype provider file, README file.
!                              Added GPSPW, NPN, MAP, SATWND data type in the converter.  
!  Jun  2014  Brian Reen       Updated for MADIS API version 4.2
!---------------------------------------------------------------------------------------------

   use module_output, only : write_littler_sfc, write_littler_upa, write_littler_onelvl,&
                             write_littler_gpspw 

   IMPLICIT NONE

! Primarily used by MADIS ingest:
! Constants:
   INTEGER*4, PARAMETER         :: max_sfc   = 200000, & !  Surface
                                   max_raob  =   1000, & !  Radiosonde
                                   max_npn   =    160, & !  NOAA Profiler Network (NPN) winds
                                   max_acars =  60000, & !  ACARS
                                   max_map   =   2000, & !  Multi-Agency profilers (MAP)
                                   max_satw  =  60000, & !  Satellite winds

                                   max_sta   = max(max_sfc,max_raob,max_npn, &
                                                   max_acars,max_map,max_satw), &

                                                         ! Max number of input levels:
                                   max_raoblev = 405, &  !  Radiosonde
                                   max_npnlev_madis = 64, & ! NPN MADIS database
                                   max_npnlev_awips = 43, &!NPN AWIPS database
                                   max_maplev  = 202, &  !  MAP

                                   success_p =      0, & ! Successful status return
                                   qcall =         0, &  ! Only return data passing specified QC; default (0)
                                                         !   returns ALL data
                                   max_provider = 100    ! Maximum number of data providers
   REAL*4, PARAMETER            :: littler_miss    = -888888.00, &  ! Missing data flag
                                   madis_miss = 999999.00
! Input arrays:

   CHARACTER*10, ALLOCATABLE    :: stanam(:),provdr(:)
   CHARACTER*9, ALLOCATABLE     :: timeob(:)
   CHARACTER*13, ALLOCATABLE    :: obtime(:),tmp_obtime(:)
   CHARACTER*1, ALLOCATABLE     :: qcd(:)
   INTEGER*4, ALLOCATABLE       :: wmoid(:),qca(:),qcr(:),nlevels(:),keep(:)
   INTEGER*4, ALLOCATABLE       :: source_n(:)
   REAL*4, ALLOCATABLE          :: lat(:),lon(:),elev(:),p(:),q(:),t(:),z(:), &
                                   dd(:),ff(:),pw(:),slp(:),td(:),levtype(:), &
                                   tmp_lat(:),tmp_lon(:),tmp_p(:)

! Miscellaneous:

   INTEGER*4                    :: nsta,nobs,istatus,i,j,k,ntmp,nlev,ntmp_r, &
                                   ntmp_n,ntmp_m,keep_r(max_raob), recwin, &
                                   keep_n(max_npn),keep_m(max_map),minbck,minfwd, &
                                   nsatw_vartype,satw_var_len(5),pvdriostat,n,iost, &
                                   nl_raob,nt_raob,nl_npn,nt_npn,nl_map,nt_map, &
                                   nlocal_out,ntotal_out
   CHARACTER*9                  :: atime
   CHARACTER*13                 :: tstr
   CHARACTER*10                 :: dpname
   CHARACTER*255                :: pvdrfile
   INTEGER*4, PARAMETER         :: lun = 19       ! LUN for namelist and data provider files
   INTEGER*4, PARAMETER         :: unit_out = 20  ! unit_out for output little_r files
   CHARACTER*5                  :: satw_var(2,5)
   CHARACTER*4                  :: pvdriotype
   LOGICAL                      :: map_init,npn_init,print_detail_obs
   CHARACTER*20                 :: namelist_file      
   CHARACTER*31                 :: errmsg(0:8)
   INTEGER*4                    :: mfbdebug
   INTEGER*4                    :: sfclev(max_map)
   CHARACTER*10                 :: use_metarobs,use_shipsobs,use_gpspwobs,use_soundobs, &
                                   use_airepobs,use_geoamvobs,use_npnobs,use_mapobs
   CHARACTER*24                 :: analysis_date    ! obs data date
   CHARACTER*100                :: madis2little_r   ! output data directory path name
   INTEGER*4                    :: numarg            ! Number of input arguments provided by the user

!------------------------------------------------------------------------------
! Namelist options for converting MADIS/AWIPS datasets to LITTLE_R format
!------------------------------------------------------------------------------
! The user can select either the MADIS or AWIPS database for each dataset that is 
! to be converted.  Each dataset's time window can be independently set as 
! well, which allows the user to select the number of minutes before and after 
! the nominal time to be used for the window, and how duplicates should be 
! handled.  For the METAR, PROFILER and GEOAMV datasets, the user can also 
! choose to ingest data from all providers of the METAR and PROFILER datasets 
! (e.g., ASOS) as well as mesonets for METAR, and from operational GOES 
! products from both satellites for GEOAMV, or the user can specify which 
! providers should be used.  For more details on how and why to select 
! different settings, see the README file.
!
! The meaning of each variable is the same for all of the datasets, so full
! comments are only included for the METAR dataset below, and where the variables
! are specific to only one or two datasets.
!------------------------------------------------------------------------------

! General

   INTEGER*4     :: madis_debug               ! 0 - no debug; for now this is the only option
   CHARACTER*10  :: madis_version             ! MADIS API version; default 4.2

! METAR dataset

   CHARACTER*6   :: madis_metar_db            ! Database:  'FSL' or 'AWIPS'
   INTEGER*4     :: madis_metar_minbck        ! Number of minutes relative to nominal
                                              ! time at which to start time window
   INTEGER*4     :: madis_metar_minfwd        ! Number of minutes relative to nominal
                                              ! time at which to end time window
                                              ! (max(minfwd-minbck) is 180)
   INTEGER*4     :: madis_metar_recwin        ! 1 - return one record per fixed station, 
                                              !     closest to nominal time
                                              ! 2 - return one record per fixed station, 
                                              !     closest to start of window
                                              ! 3 - return one record per fixed station, 
                                              !     closest to end of window
                                              ! 4 - return all records within *window*
   LOGICAL       :: madis_metar_all_providers ! .TRUE./.FALSE. - use all providers 
   CHARACTER*255 :: madis_metar_provider_list ! Full path to file with list of providers,
                                              ! one per line; must be specified if 
                                              ! all_providers is false

! SHIPS dataset

   CHARACTER*6   :: madis_ships_db            ! Database:  'FSL' or 'AWIPS'
   INTEGER*4     :: madis_ships_minbck        ! Time window start
   INTEGER*4     :: madis_ships_minfwd        ! Time window end
   INTEGER*4     :: madis_ships_recwin        ! How to handle duplicate records

! GPSPW dataset

   CHARACTER*6   :: madis_gpspw_db            ! Database:  'FSL' or 'AWIPS'
   INTEGER*4     :: madis_gpspw_minbck        ! Time window start
   INTEGER*4     :: madis_gpspw_minfwd        ! Time window end
   INTEGER*4     :: madis_gpspw_recwin        ! How to handle duplicate records

! SOUND dataset

   CHARACTER*6   :: madis_sound_db            ! Database:  'FSL' or 'AWIPS'
   INTEGER*4     :: madis_sound_minbck        ! Time window start
   INTEGER*4     :: madis_sound_minfwd        ! Time window end
   INTEGER*4     :: madis_sound_recwin        ! How to handle duplicate records

! PROFILER dataset

   CHARACTER*6   :: madis_profiler_db            ! Database:  'FSL' or 'AWIPS'
   INTEGER*4     :: madis_profiler_minbck        ! Time window start
   INTEGER*4     :: madis_profiler_minfwd        ! Time window end
   INTEGER*4     :: madis_profiler_recwin        ! How to handle duplicate records
   LOGICAL       :: madis_profiler_all_providers ! .TRUE./.FALSE. - use all providers 
   CHARACTER*255 :: madis_profiler_provider_list ! Full path to file with list of providers

! AIREP dataset

   CHARACTER*6   :: madis_airep_db            ! Database:  'FSL' or 'AWIPS'
   INTEGER*4     :: madis_airep_minbck        ! Time window start
   INTEGER*4     :: madis_airep_minfwd        ! Time window end
   INTEGER*4     :: madis_airep_recwin        ! How to handle duplicate records

! GEOAMV dataset

   CHARACTER*6   :: madis_geoamv_db            ! Database:  'FSL' or 'AWIPS'
   INTEGER*4     :: madis_geoamv_minbck        ! Time window start
   INTEGER*4     :: madis_geoamv_minfwd        ! Time window end
   INTEGER*4     :: madis_geoamv_recwin        ! How to handle duplicate records
   LOGICAL       :: madis_geoamv_all_providers ! .TRUE./.FALSE. - use default providers 
   CHARACTER*255 :: madis_geoamv_provider_list ! Full path to file with list of providers
   LOGICAL       :: madis_geoamv_wv            ! .TRUE./.FALSE. - use water vapor winds
   LOGICAL       :: madis_geoamv_ir            ! .TRUE./.FALSE. - use infrared winds
   LOGICAL       :: madis_geoamv_vis           ! .TRUE./.FALSE. - use visible winds
   LOGICAL       :: madis_geoamv_s10           ! .TRUE./.FALSE. - use sounder channel 10 winds
   LOGICAL       :: madis_geoamv_s11           ! .TRUE./.FALSE. - use sounder channel 11 winds

 
! Note that the meaning of "madis_geoamv_all_providers" is different for GEOAMV than 
! for the other datasets.  If the variable is .TRUE., the *default* providers will be
! selected, i.e., operational products from both GOES satellites.
!------------------------------------------------------------------------------
! End of MADIS/AWIPS options
!------------------------------------------------------------------------------
! Namelist contents :

   NAMELIST/MADIS_GENERAL/madis_debug,madis_version
   NAMELIST/MADIS_METAR/madis_metar_db,madis_metar_minbck,madis_metar_minfwd,madis_metar_recwin, &
                        madis_metar_all_providers,madis_metar_provider_list
   NAMELIST/MADIS_SHIPS/madis_ships_db,madis_ships_minbck,madis_ships_minfwd,madis_ships_recwin
   NAMELIST/MADIS_GPSPW/madis_gpspw_db,madis_gpspw_minbck,madis_gpspw_minfwd,madis_gpspw_recwin
   NAMELIST/MADIS_SOUND/madis_sound_db,madis_sound_minbck,madis_sound_minfwd,madis_sound_recwin
   NAMELIST/MADIS_PROFILER/madis_profiler_db,madis_profiler_minbck,madis_profiler_minfwd,&
                           madis_profiler_recwin,madis_profiler_all_providers,&
                           madis_profiler_provider_list
   NAMELIST/MADIS_AIREP/madis_airep_db,madis_airep_minbck,madis_airep_minfwd,madis_airep_recwin
   NAMELIST/MADIS_GEOAMV/madis_geoamv_db,madis_geoamv_minbck,madis_geoamv_minfwd,&
                         madis_geoamv_recwin,madis_geoamv_all_providers,&
                         madis_geoamv_provider_list,madis_geoamv_wv,madis_geoamv_ir,&
                         madis_geoamv_vis,madis_geoamv_s10,madis_geoamv_s11

   DATA ERRMSG/'Opening namelist.madis',&
               'Reading madis_general namelist',&
               'Reading madis_metar namelist',&
               'Reading madis_ships namelist',&
               'Reading madis_gpspw namelist',&
               'Reading madis_sound namelist',&
               'Reading madis_profiler namelist',&
               'Reading madis_airep namelist',&
               'Reading madis_geoamv namelist'/



!------------------------------------------------------------------------------
! MADIS-related initialization
!------------------------------------------------------------------------------

! Note that any variables prefixed with "madis_" are namelist variables read in
! from namelist.madis.  These are used to give the user the ability to
! set all relevant MADIS options for the various datasets.

   write(6,*)' -----------------------------------------------------'
   write(6,*)'       Read namelist options for MADIS datasets'
   write(6,*)' -----------------------------------------------------'
   write(6,*)

!----------------------------------------------------------------------------
! Set default values.  These represent reasonable choices for an hourly data 
! assimilation cycle, using all datasets, for MADIS database, without 
! debugging info.
!----------------------------------------------------------------------------
   madis_debug = 0
   madis_version = '4.2' 

   madis_metar_db = 'FSL'
   madis_metar_minbck = -90
   madis_metar_minfwd = 90
   madis_metar_recwin = 4
   madis_metar_all_providers = .TRUE.

   madis_ships_db = 'FSL'
   madis_ships_minbck = -90
   madis_ships_minfwd = 90
   madis_ships_recwin = 4

   madis_gpspw_db = 'FSL'
   madis_gpspw_minbck = -90
   madis_gpspw_minfwd = 90
   madis_gpspw_recwin = 4

   madis_sound_db = 'FSL'
   madis_sound_minbck = -90
   madis_sound_minfwd = 90
   madis_sound_recwin = 3

   madis_profiler_db = 'FSL'
   madis_profiler_minbck = -90
   madis_profiler_minfwd = 90
   madis_profiler_recwin = 4
   madis_profiler_all_providers = .TRUE.

   madis_airep_db = 'FSL'
   madis_airep_minbck = -90
   madis_airep_minfwd = 90
   madis_airep_recwin = 4

   madis_geoamv_db = 'FSL'
   madis_geoamv_minbck = -90
   madis_geoamv_minfwd = 90
   madis_geoamv_recwin = 4
   madis_geoamv_all_providers = .TRUE.
   madis_geoamv_wv = .TRUE.
   madis_geoamv_ir = .TRUE.
   madis_geoamv_vis = .FALSE.
   madis_geoamv_s10 = .FALSE.
   madis_geoamv_s11 = .FALSE.

!----------------------------------------------------------------------------
!  Open namelist file.
!----------------------------------------------------------------------------
   namelist_file = 'namelist.madis'
   write(6,*)' MADIS datasets namelist options used are in: ', &
             namelist_file
   iost = 0
   i = 0

   write(6,*) ' Opening MADIS namelist input file...'

   open(file=namelist_file,unit=lun,status='old', &
        access='sequential',form='formatted',action='read', &
        iostat=iost)
   if (iost /= 0) then
      write(0,*)' ERROR:  ', errmsg(i), ' IOSTAT = ', iost, &
                ' while reading MADIS namelist'
      stop
   endif

!----------------------------------------------------------------------------
!  Read namelist and close.
!----------------------------------------------------------------------------
   iost = 0
   i = i + 1
   read(unit=lun,nml=madis_general,iostat=iost)
   if (iost /= 0) then
      write(0,*)' ERROR:  ', errmsg(i), ' IOSTAT = ', iost, &
                ' while reading MADIS namelist'
      stop
   endif
   i = i + 1
   read(unit=lun,nml=madis_metar,iostat=iost)
   if (iost /= 0) then
      write(0,*)' ERROR:  ', errmsg(i), ' IOSTAT = ', iost, &
                ' while reading MADIS namelist'
      stop
   endif
   i = i + 1
   read(unit=lun,nml=madis_ships,iostat=iost)
   if (iost /= 0) then
      write(0,*)' ERROR:  ', errmsg(i), ' IOSTAT = ', iost, &
                ' while reading MADIS namelist'
      stop
   endif
   i = i + 1
   read(unit=lun,nml=madis_gpspw,iostat=iost)
   if (iost /= 0) then
      write(0,*)' ERROR:  ', errmsg(i), ' IOSTAT = ', iost, &
                ' while reading MADIS namelist'
      stop
   endif
   i = i + 1
   read(unit=lun,nml=madis_sound,iostat=iost)
   if (iost /= 0) then
      write(0,*)' ERROR:  ', errmsg(i), ' IOSTAT = ', iost, &
                ' while reading MADIS namelist'
      stop
   endif
   i = i + 1
   read(unit=lun,nml=madis_profiler,iostat=iost)
   if (iost /= 0) then
      write(0,*)' ERROR:  ', errmsg(i), ' IOSTAT = ', iost, &
                ' while reading MADIS namelist'
      stop
   endif
   i = i + 1
   read(unit=lun,nml=madis_airep,iostat=iost)
   if (iost /= 0) then
      write(0,*)' ERROR:  ', errmsg(i), ' IOSTAT = ', iost, &
                ' while reading MADIS namelist'
      stop
   endif
   i = i + 1
   read(unit=lun,nml=madis_geoamv,iostat=iost)
   if (iost /= 0) then
      write(0,*)' ERROR:  ', errmsg(i), ' IOSTAT = ', iost, &
                ' while reading MADIS namelist'
      stop
   endif
   close(lun)

   write(6,*) ' MADIS namelist input file successfully read.'


!----------------------------------------------------------------------------
!  Print namelist.
!----------------------------------------------------------------------------
   
  print_detail_obs = .TRUE.
  if (print_detail_obs) then

      write(6,*) ' Printing contents of MADIS namelist input file...'

      write(6,*)
      write(6,*)'madis_debug                  = ',madis_debug
      write(6,*)'madis_version                = ',madis_version
      write(6,*)
      write(6,*)'madis_metar_db               = ',madis_metar_db 
      write(6,*)'madis_metar_minbck           = ',madis_metar_minbck 
      write(6,*)'madis_metar_minfwd           = ',madis_metar_minfwd 
      write(6,*)'madis_metar_recwin           = ',madis_metar_recwin 
      write(6,*)'madis_metar_all_providers    = ',madis_metar_all_providers 
      write(6,*)'madis_metar_provider_list    = ',trim(madis_metar_provider_list)
      write(6,*)
      write(6,*)'madis_sound_db               = ',madis_sound_db 
      write(6,*)'madis_sound_minbck           = ',madis_sound_minbck 
      write(6,*)'madis_sound_minfwd           = ',madis_sound_minfwd 
      write(6,*)'madis_sound_recwin           = ',madis_sound_recwin 
      write(6,*)
      write(6,*)'madis_profiler_db            = ',madis_profiler_db 
      write(6,*)'madis_profiler_minbck        = ',madis_profiler_minbck 
      write(6,*)'madis_profiler_minfwd        = ',madis_profiler_minfwd 
      write(6,*)'madis_profiler_recwin        = ',madis_profiler_recwin 
      write(6,*)'madis_profiler_all_providers = ',madis_profiler_all_providers 
      write(6,*)'madis_profiler_provider_list = ',trim(madis_profiler_provider_list)
      write(6,*)
      write(6,*)'madis_airep_db               = ',madis_airep_db 
      write(6,*)'madis_airep_minbck           = ',madis_airep_minbck 
      write(6,*)'madis_airep_minfwd           = ',madis_airep_minfwd 
      write(6,*)'madis_airep_recwin           = ',madis_airep_recwin 
      write(6,*)
      write(6,*)'madis_geoamv_db              = ',madis_geoamv_db 
      write(6,*)'madis_geoamv_minbck          = ',madis_geoamv_minbck 
      write(6,*)'madis_geoamv_minfwd          = ',madis_geoamv_minfwd 
      write(6,*)'madis_geoamv_recwin          = ',madis_geoamv_recwin 
      write(6,*)'madis_geoamv_all_providers   = ',madis_geoamv_all_providers 
      write(6,*)'madis_geoamv_provider_list   = ',trim(madis_geoamv_provider_list)
      write(6,*)'madis_geoamv_wv              = ',madis_geoamv_wv 
      write(6,*)'madis_geoamv_ir              = ',madis_geoamv_ir 
      write(6,*)'madis_geoamv_vis             = ',madis_geoamv_vis 
      write(6,*)'madis_geoamv_s10             = ',madis_geoamv_s10 
      write(6,*)'madis_geoamv_s11             = ',madis_geoamv_s11 
      write(6,*)
 
  endif

! Meral: The following part is added to get required input externally from the user.
   numarg = COMMAND_ARGUMENT_COUNT()
   if ( numarg /= 2 )then
      write(UNIT=6,FMT='(a)') &
        "Usage: madis_to_little_r.exe  analysis_date little_r_dir_path_name "
      stop
   end if

! Meral: Initialise to stop any compiler complaining
   analysis_date=""
   madis2little_r=""

   call GET_COMMAND_ARGUMENT( 1, analysis_date )
   call GET_COMMAND_ARGUMENT( 2, madis2little_r )

! Convert the user's desired time to the format used by MADIS
! (YYYYMMDD_HHMM).

  tstr = analysis_date(1:4)//analysis_date(6:7)//analysis_date(9:10)// &
          '_'//analysis_date(12:13)//analysis_date(15:16)
! Now convert 'YYYYMMDD_HH00' to 'YYJJJHH00' (JJJ = Julian date).

  CALL MTRNTIM(tstr,1,atime,istatus)
  if(istatus /= success_p)stop

  CALL GETENV('METAR', use_metarobs)
  CALL GETENV('MARINE',use_shipsobs)
  CALL GETENV('GPSPW',use_gpspwobs)
  CALL GETENV('RAOB',  use_soundobs)
  CALL GETENV('ACARS', use_airepobs)
  CALL GETENV('SATWND',use_geoamvobs)
  CALL GETENV('NPN', use_npnobs)
  CALL GETENV('MAP', use_mapobs)

!------------------------------------------------------------------------------
! MADIS surface datasets (METAR, SAO, ALL-MESO, COOP)
!------------------------------------------------------------------------------

  pvdriostat = 0                  ! Indicates I/O errors on provider files.
  
  if (trim(use_metarobs) .eq. 'TRUE' )then

! Allocate the local memory for the MADIS arrays that have a level dimension
     write(6,*) ' Allocating memory for MADIS arrays SFC (METAR, SAO, ALL-MESO, COOP) obs...'

     allocate (stanam(max_sfc))
     allocate (provdr(max_sfc))
     allocate (timeob(max_sfc))
     allocate (obtime(max_sfc))
     allocate (wmoid(max_sfc))
     allocate (lat(max_sfc))
     allocate (lon(max_sfc))
     allocate (elev(max_sfc))
     if (trim(madis_version) == '4.2') then
        allocate (source_n(max_sfc))
     endif

     allocate (p(max_sfc))
     allocate (td(max_sfc))
     allocate (t(max_sfc))
     allocate (dd(max_sfc))
     allocate (ff(max_sfc))
     allocate (slp(max_sfc))
     allocate (qca(max_sfc))
     allocate (qcr(max_sfc))
     allocate (qcd(max_sfc))

     CALL MINIT('SFC',madis_metar_db,.true.,istatus)
     if(istatus /= success_p) then
        write(6,*) ' ERROR IN STEP "MINIT" FOR SFC OBS:',istatus
        stop
     endif
     CALL MSETSFCPVDR('ALL-SFC',.false.,istatus)
     if(istatus /= success_p)stop

     if(.not. madis_metar_all_providers)then

        if(print_detail_obs)then
           write(6,*)
           write(6,*)'Selecting individual METAR providers from ',&
                      trim(madis_metar_provider_list)
        endif
        if(istatus /= success_p)stop

        pvdriotype = 'Open'
        pvdrfile = madis_metar_provider_list
        open(unit=lun,file=trim(pvdrfile),status='OLD', &
             iostat=pvdriostat,err=8000)

        pvdriotype = 'Read'

        do i = 1, max_provider
           read(lun,1,err=8000,iostat=pvdriostat,end=2)dpname
 1         format(a)
           if(.not. (dpname(1:1) == '#' .or. len(trim(dpname)) == 0 .or. &
                     dpname(1:8) == 'MARITIME'))then
              if(print_detail_obs)write(6,*)'  Selecting:  ',trim(dpname)
              CALL MSETSFCPVDR(trim(dpname),.true.,istatus)
              if(istatus /= success_p)stop
           endif
        enddo

 2      pvdriostat = 0
        close(lun)

     else

! Select all of the surface datasets other than maritime.
        CALL MSETSFCPVDR('ALL-MTR',.true.,istatus)
        if(istatus /= success_p)stop
        CALL MSETSFCPVDR('SAO',.true.,istatus)
        if(istatus /= success_p)stop
        CALL MSETSFCPVDR('ALL-MESO',.true.,istatus)
        if(istatus /= success_p)stop
        CALL MSETSFCPVDR('COOP',.true.,istatus)
        if(istatus /= success_p)stop

    endif

!------------------------------------------------------------------------
! Select the QC level to be returned to "max possible QC level for each
! variable".
! qcall:    0 - NO QC FILTERING (DEFAULT)
!           1 - "COARSE":   PASSED AT LEAST STAGE 1
!           2 - "SCREENED": PASSED AT LEAST STAGE 2
!           3 - "VERIFIED": PASSED AT LEAST STAGE 3
!           99 - HIGHEST QC POSSIBLE FOR VARIABLE/DATASET
! WITHOUT CALLING THIS ROUTINE, BY DEFAULT ALL OBS WILL BE
! RETURNED, ALONG WITH THEIR QC STRUCTURES, AND THE CALLER CAN
! SORT OUT WHAT HE OR SHE WANTS BY HIM OR HERSELF.
! It is called after MSETSFCPVDR subroutine.
!-----------------------------------------------------------------------
   CALL MSETQC(qcall,istatus)
   if(istatus /= success_p)stop

! Set the time window for this dataset with the user's choices.

     CALL MSETWIN(madis_metar_minbck,madis_metar_minfwd,madis_metar_recwin,istatus)
     if(istatus /= success_p)stop

! Load in the stations that have data in this time window.  If we have any 
! problems reading in the stations we'll skip this dataset.  When we're done
! with all the datasets, if nothing's been read in there's a problem
! and we'll stop with an error.  If a particular dataset is missing, but
! the others aren't, that's not as fundamental of a problem.

     if (trim(madis_version) == '4.2') then
        CALL MSFCSTA(atime,nsta,stanam,wmoid,lat,lon,elev,timeob,provdr,istatus,source_n)
     else
        CALL MSFCSTA(atime,nsta,stanam,wmoid,lat,lon,elev,timeob,provdr,istatus)
     endif

    if(istatus /= success_p)stop
  
! change obtime for Julian date to YYYYMMDDHHMM  
     do i = 1, nsta
        CALL MTRNTIM(timeob(i),2,obtime(i),istatus)
     enddo

! Read in the observations, with QC filtering as specified in MSETQC --
! this will put MADIS missing flags in all obs that didn't pass the QC.
! Note that we don't check the status on each variable read.  It's simpler
! to fill in missing flags into each variable before reading them, then
! we can sort this all out below.

     CALL MGETSFC(atime,'P',ntmp,nobs,p,qcd,qca,qcr,istatus)
     CALL MGETSFC(atime,'TD',ntmp,nobs,td,qcd,qca,qcr,istatus)
     CALL MGETSFC(atime,'T',ntmp,nobs,t,qcd,qca,qcr,istatus)
     CALL MGETSFC(atime,'DD',ntmp,nobs,dd,qcd,qca,qcr,istatus)
     CALL MGETSFC(atime,'FF',ntmp,nobs,ff,qcd,qca,qcr,istatus)
     CALL MGETSFC(atime,'SLP',ntmp,nobs,slp,qcd,qca,qcr,istatus)
    
     do i = 1, nsta
        if (p(i) == madis_miss )   p(i)  = littler_miss
        if (td(i) == madis_miss )  td(i) = littler_miss
        if (t(i) == madis_miss )   t(i)  = littler_miss
        if (dd(i) == madis_miss )  dd(i) = littler_miss
        if (ff(i) == madis_miss )  ff(i) = littler_miss
        if (slp(i) == madis_miss ) slp(i) = littler_miss
     enddo

     open(unit =unit_out , file = trim(madis2little_r)//"metar/"//"METAR_LITTLE_R_"//analysis_date(1:13))
     do i  =  1, nsta
        CALL WRITE_LITTLER_SFC(p(i),slp(i),elev(i),t(i),td(i),ff(i),dd(i),lat(i),lon(i),obtime(i),stanam(i),unit_out,"FM-15")
     enddo
     close(unit_out)
     write(6,*) ' Finished writting MADIS arrays SFC (METAR, SAO, ALL-MESO, COOP) obs... to LITTLE_R' 
     write(6,*)
  
     deallocate (stanam)
     deallocate (provdr)
     deallocate (timeob)
     deallocate (obtime)
     deallocate (wmoid)
     if (trim(madis_version) == '4.2') then
        deallocate (source_n)
     endif
     deallocate (lat)
     deallocate (lon)
     deallocate (elev)

     deallocate (p)
     deallocate (td)
     deallocate (t)
     deallocate (dd)
     deallocate (ff)
     deallocate (slp)
     deallocate (qca)
     deallocate (qcr)
     deallocate (qcd)

  endif ! if(use_metarobs)

  if(trim(use_shipsobs) .eq. 'TRUE')then

! Allocate the local memory for the MADIS arrays that have a level dimension
     write(6,*) ' Allocating memory for MADIS arrays SHIPS obs...'

     allocate (stanam(max_sfc))
     allocate (provdr(max_sfc))
     allocate (timeob(max_sfc))
     allocate (obtime(max_sfc))
     allocate (wmoid(max_sfc))
     if (trim(madis_version) == '4.2') then
        allocate (source_n(max_sfc))
     endif
     allocate (lat(max_sfc))
     allocate (lon(max_sfc))
     allocate (elev(max_sfc))

     allocate (p(max_sfc))
     allocate (td(max_sfc))
     allocate (t(max_sfc))
     allocate (dd(max_sfc))
     allocate (ff(max_sfc))
     allocate (slp(max_sfc))
     allocate (qca(max_sfc))
     allocate (qcr(max_sfc))
     allocate (qcd(max_sfc))

     CALL MINIT('SFC',madis_ships_db,.true.,istatus)
     if(istatus /= success_p)stop
     CALL MSETSFCPVDR('ALL-SFC',.false.,istatus)
     if(istatus /= success_p)stop
     CALL MSETSFCPVDR('MARITIME',.true.,istatus)
     if(istatus /= success_p)stop
     CALL MSETQC(qcall,istatus)
     if(istatus /= success_p)stop

! Set the time window for this dataset with the user's choices.

     CALL MSETWIN(madis_ships_minbck,madis_ships_minfwd,madis_ships_recwin,istatus)
     if(istatus /= success_p)stop
     if (trim(madis_version) == '4.2') then
        CALL MSFCSTA(atime,nsta,stanam,wmoid,lat,lon,elev,timeob,provdr,istatus,source_n)
     else
        CALL MSFCSTA(atime,nsta,stanam,wmoid,lat,lon,elev,timeob,provdr,istatus)
     endif
     if(istatus /= success_p)stop

! change obtime for Julian date to YYYYMMDDHHMM
     do i = 1, nsta
        CALL MTRNTIM(timeob(i),2,obtime(i),istatus)
     enddo

! Read in the observations, with QC filtering as specified in MSETQC --
! this will put MADIS missing flags in all obs that didn't pass the QC.
! Note that we don't check the status on each variable read.  It's simpler
! to fill in missing flags into each variable before reading them, then
! we can sort this all out below.

      CALL MGETSFC(atime,'P',ntmp,nobs,p,qcd,qca,qcr,istatus)
      CALL MGETSFC(atime,'TD',ntmp,nobs,td,qcd,qca,qcr,istatus)
      CALL MGETSFC(atime,'T',ntmp,nobs,t,qcd,qca,qcr,istatus)
      CALL MGETSFC(atime,'DD',ntmp,nobs,dd,qcd,qca,qcr,istatus)
      CALL MGETSFC(atime,'FF',ntmp,nobs,ff,qcd,qca,qcr,istatus)
      CALL MGETSFC(atime,'SLP',ntmp,nobs,slp,qcd,qca,qcr,istatus)

     do i = 1, nsta
        if (p(i) == madis_miss )   p(i)  = littler_miss
        if (td(i) == madis_miss )  td(i) = littler_miss
        if (t(i) == madis_miss )   t(i)  = littler_miss
        if (dd(i) == madis_miss )  dd(i) = littler_miss
        if (ff(i) == madis_miss )  ff(i) = littler_miss
        if (slp(i) == madis_miss ) slp(i) = littler_miss
     enddo


     open(unit =unit_out , file = trim(madis2little_r)//"maritime/"//"SHIP_LITTLE_R_"//analysis_date(1:13))
     do i  =  1, nsta
        CALL WRITE_LITTLER_SFC(p(i),slp(i),elev(i),t(i),td(i),ff(i),dd(i),lat(i),lon(i),obtime(i),stanam(i),unit_out,"FM-13")
     enddo
     close(unit_out)
     write(6,*) ' Finished writting MADIS arrays SHIPS obs... to LITTLE_R'
     write(6,*)

     deallocate (stanam)
     deallocate (provdr)
     deallocate (timeob)
     deallocate (obtime)
     deallocate (wmoid)
     deallocate (lat)
     deallocate (lon)
     deallocate (elev)
     if (trim(madis_version) == '4.2') then
        deallocate (source_n)
     endif
     deallocate (p)
     deallocate (td)
     deallocate (t)
     deallocate (dd)
     deallocate (ff)
     deallocate (slp)
     deallocate (qca)
     deallocate (qcr)
     deallocate (qcd)

  endif ! if(use_shipsobs)

  if(trim(use_gpspwobs) .eq. 'TRUE')then

! Allocate the local memory for the MADIS arrays that have a level dimension
     write(6,*) ' Allocating memory for MADIS arrays GPSPWOBS obs...'

     allocate (stanam(max_sfc))
     allocate (provdr(max_sfc))
     allocate (timeob(max_sfc))
     allocate (obtime(max_sfc))
     allocate (wmoid(max_sfc))
     allocate (lat(max_sfc))
     allocate (lon(max_sfc))
     allocate (elev(max_sfc))
     if (trim(madis_version) == '4.2') then
        allocate (source_n(max_sfc))
     endif

     allocate (pw(max_sfc))
     allocate (slp(max_sfc))
     allocate (qca(max_sfc))
     allocate (qcr(max_sfc))
     allocate (qcd(max_sfc))
       
 
     CALL MINIT('SFC',madis_gpspw_db,.true.,istatus)
     if(istatus /= success_p)stop
     CALL MSETSFCPVDR('ALL-SFC',.false.,istatus)
     if(istatus /= success_p)stop
     CALL MSETSFCPVDR('GPSMET',.true.,istatus)
     if(istatus /= success_p)stop

     CALL MSETQC(qcall,istatus)
     if(istatus /= success_p)stop
! Set the time window for this dataset with the user's choices.

     CALL MSETWIN(madis_gpspw_minbck,madis_gpspw_minfwd,madis_gpspw_recwin,istatus)
     if(istatus /= success_p)stop

! Load in the stations that have data in this time window.

     if (trim(madis_version) == '4.2') then
        CALL MSFCSTA(atime,nsta,stanam,wmoid,lat,lon,elev,timeob,provdr,istatus,source_n)
     else
        CALL MSFCSTA(atime,nsta,stanam,wmoid,lat,lon,elev,timeob,provdr,istatus)
     endif
     if(istatus /= success_p)stop

! change obtime for Julian date to YYYYMMDDHHMM
     do i = 1, nsta
        CALL MTRNTIM(timeob(i),2,obtime(i),istatus)
     enddo

     CALL MGETSFC(atime,'PWV',ntmp,nobs,pw,qcd,qca,qcr,istatus)
     CALL MGETSFC(atime,'SLP',ntmp,nobs,slp,qcd,qca,qcr,istatus)

     do i = 1, nsta
        if (pw(i) == madis_miss )   then
           pw(i)  = littler_miss
        else
           pw(i)  = pw(i) * 100 ! convert unit from m to cm
        end if
        if (slp(i) == madis_miss )  slp(i)  = littler_miss
     enddo

     open(unit =unit_out , file = trim(madis2little_r)//"gpspw/"//"GPSPW_LITTLE_R_"//analysis_date(1:13))
     do i  =  1, nsta
        CALL WRITE_LITTLER_GPSPW(slp(i),pw(i),elev(i),lat(i),lon(i),obtime(i),stanam(i),unit_out,"FM-111")
     enddo
     close(unit_out)
 
     write(6,*) ' Finished writting MADIS arrays GPSPW  obs... to LITTLE_R'
     write(6,*)
  
     deallocate (stanam)
     deallocate (provdr)
     deallocate (timeob)
     deallocate (obtime)
     deallocate (wmoid)
     deallocate (lat)
     deallocate (lon)
     deallocate (elev)
     if (trim(madis_version) == '4.2') then
        deallocate (source_n)
     endif

     deallocate (pw)
     deallocate (slp)
     deallocate (qca)
     deallocate (qcr)
     deallocate (qcd)

  endif ! if(use_gpspw)

 
  if(trim(use_soundobs) .eq. 'TRUE')then

! Allocate the local memory for the MADIS arrays that have a level dimension.
     write(6,*) ' Allocating memory for MADIS arrays SOUND obs...' 
  
     allocate (stanam(max_raob))
     allocate (provdr(max_raob))
     allocate (timeob(max_raob))
     allocate (obtime(max_raob))
     allocate (wmoid(max_raob))
     allocate (lat(max_raob))
     allocate (lon(max_raob))
     allocate (elev(max_raob))
     allocate (nlevels(max_raob))

     allocate (p(max_raoblev*max_raob))
     allocate (td(max_raoblev*max_raob))
     allocate (t(max_raoblev*max_raob))
     allocate (z(max_raoblev*max_raob))
     allocate (dd(max_raoblev*max_raob))
     allocate (ff(max_raoblev*max_raob))
     allocate (qca(max_raoblev*max_raob))
     allocate (qcr(max_raoblev*max_raob))
     allocate (qcd(max_raoblev*max_raob))
     allocate (levtype(max_raoblev*max_raob))
      
     CALL MINIT('RAOB',madis_sound_db,.true.,istatus)
     if(istatus /= success_p)stop
     CALL MSETQC(qcall,istatus)
     if(istatus /= success_p)stop

! Set the time window and load in the station info.

     CALL MSETWIN(madis_sound_minbck,madis_sound_minfwd,madis_sound_recwin,istatus)
     if(istatus /= success_p)stop
     CALL MRAOBSTA(atime,nsta,stanam,wmoid,lat,lon,elev,timeob,istatus)
     if(istatus /= success_p)stop   ! Can't possibly happen, so stop if it does.

     do i = 1, nsta
       CALL MTRNTIM(timeob(i),2,obtime(i),istatus)
     enddo

! Read in the observations.
! I tested two files, nlevels is different for each of nsta, however < 1000 (max_raoblev)
     CALL MGETRAOB(atime,'P',ntmp,nobs,nlevels,p,qcd,qca,qcr,istatus)
     CALL MGETRAOB(atime,'TD',ntmp,nobs,nlevels,td,qcd,qca,qcr,istatus)
     CALL MGETRAOB(atime,'T',ntmp,nobs,nlevels,t,qcd,qca,qcr,istatus)
     CALL MGETRAOB(atime,'DD',ntmp,nobs,nlevels,dd,qcd,qca,qcr,istatus)
     CALL MGETRAOB(atime,'FF',ntmp,nobs,nlevels,ff,qcd,qca,qcr,istatus)
     CALL MGETRAOB(atime,'HT',ntmp,nobs,nlevels,z,qcd,qca,qcr,istatus)
     CALL MGETRAOB(atime,'LEVTYPE',ntmp,nobs,nlevels,levtype,qcd,qca,qcr,istatus)

     do i = 1, max_raoblev*nsta
        if (p(i) == madis_miss )   p(i) = littler_miss
        if (td(i) == madis_miss )  td(i) = littler_miss
        if (t(i) == madis_miss )   t(i) = littler_miss
        if (dd(i) == madis_miss )  dd(i) = littler_miss
        if (ff(i) == madis_miss )  ff(i) = littler_miss
        if (z(i) == madis_miss )   z(i) = littler_miss
     enddo  

     j = 0
     open(unit =unit_out , file = trim(madis2little_r)//"raob/"//"RAOB_LITTLE_R_"//analysis_date(1:13))
     do i  =  1, nsta
       CALL WRITE_LITTLER_UPA(p(j+1:j+max_raoblev),z(j+1:j+max_raoblev),t(j+1:j+max_raoblev),td(j+1:j+max_raoblev),&
                              &ff(j+1:j+max_raoblev),dd(j+1:j+max_raoblev),elev(i),lat(i),lon(i),obtime(i),stanam(i),&
                              &nlevels(i),unit_out,"FM-35")
       j = j + max_raoblev 
     enddo

     close(unit_out)
     write(6,*) ' Finished writting MADIS arrays SOUND obs... to LITTLE_R'
     write(6,*)

     deallocate (stanam)
     deallocate (provdr)
     deallocate (timeob)
     deallocate (obtime)
     deallocate (wmoid)
     deallocate (lat)
     deallocate (lon)
     deallocate (elev)
     deallocate (nlevels)
      
     deallocate (p)
     deallocate (td)
     deallocate (t)
     deallocate (z)
     deallocate (dd)
     deallocate (ff)
     deallocate (qca)
     deallocate (qcr)
     deallocate (qcd)
     deallocate (levtype)

  endif ! if(use_soundobs)then


  if(trim(use_npnobs) .eq. 'TRUE')then
! Allocate the local memory for the MADIS arrays that have a level dimension.

     write(6,*) ' Allocating memory for MADIS arrays NOAA profiler network (NPN) obs...'
     allocate (stanam(max_npn))
     allocate (provdr(max_npn))
     allocate (timeob(max_npn))
     allocate (obtime(max_npn))
     allocate (wmoid(max_npn))
     allocate (lat(max_npn))
     allocate (lon(max_npn))
     allocate (elev(max_npn))
     allocate (nlevels(max_npn))

     if(madis_profiler_db(1:3) == 'FSL')then
        nlev = max_npnlev_madis
     else
        nlev = max_npnlev_awips
     endif

     allocate (p(nlev*max_npn))
     allocate (z(nlev*max_npn))
     allocate (t(nlev*max_npn))
     allocate (td(nlev*max_npn))
     allocate (dd(nlev*max_npn))
     allocate (ff(nlev*max_npn))
     allocate (qca(nlev*max_npn))
     allocate (qcr(nlev*max_npn))
     allocate (qcd(nlev*max_npn))

     CALL MINIT('NPN',madis_profiler_db,.true.,istatus)
     if(istatus /= success_p)stop
     CALL MSETQC(qcall,istatus)
     if(istatus /= success_p)stop

! Set the time window and load in the station info.

     CALL MSETWIN(madis_profiler_minbck,madis_profiler_minfwd,madis_profiler_recwin,istatus)
     if(istatus /= success_p)stop
     CALL MNPNSTA(atime,nsta,stanam,wmoid,lat,lon,elev,timeob,istatus)
     if(istatus /= success_p)stop   ! Can't possibly happen, so stop if it does.
     do i = 1, nsta
       CALL MTRNTIM(timeob(i),2,obtime(i),istatus)
     enddo

! Read in the observations.
! I tested two files, nlevels=map_npnlev_madis=64
     CALL MGETNPN(atime,'P',ntmp,nobs,nlevels,p,qcd,qca,qcr,istatus)
     CALL MGETNPN(atime,'DD',ntmp,nobs,nlevels,dd,qcd,qca,qcr,istatus)
     CALL MGETNPN(atime,'FF',ntmp,nobs,nlevels,ff,qcd,qca,qcr,istatus)
     CALL MGETNPN(atime,'HT',ntmp,nobs,nlevels,z,qcd,qca,qcr,istatus)

     do i = 1, nlev*max_npn
        if (p(i) == madis_miss )   p(i) = littler_miss
        if (dd(i) == madis_miss )  dd(i) = littler_miss
        if (ff(i) == madis_miss )  ff(i) = littler_miss
        if (z(i) == madis_miss )   z(i) = littler_miss
     enddo

     t(1:nlev*max_npn) = littler_miss
     td(1:nlev*max_npn) = littler_miss

     j = 0
     open(unit =unit_out , file = trim(madis2little_r)//"npn/"//"NPN_LITTLE_R_"//analysis_date(1:13))
     do i  =  1, nsta
       CALL WRITE_LITTLER_UPA(p(j+1:j+nlev),z(j+1:j+nlev),t(j+1:j+nlev),&
                              td(j+1:j+nlev),ff(j+1:j+nlev),dd(j+1:j+nlev),&
                              elev(i),lat(i),lon(i),obtime(i),stanam(i),nlevels(i),unit_out,"FM-132")
       j = j + nlev
     enddo
     close(unit_out)
     write(6,*) ' Finished writting MADIS arrays NPN obs... to LITTLE_R'
     write(6,*)


     deallocate (stanam)
     deallocate (provdr)
     deallocate (timeob)
     deallocate (obtime)
     deallocate (wmoid)
     deallocate (lat)
     deallocate (lon)
     deallocate (elev)
     deallocate (nlevels)

     deallocate (p)
     deallocate (td)
     deallocate (t)
     deallocate (z)
     deallocate (dd)
     deallocate (ff)
     deallocate (qca)
     deallocate (qcr)
     deallocate (qcd)

  endif ! if(use_npnobs)then


 if(trim(use_mapobs) .eq. 'TRUE')then
! Allocate the local memory for the MADIS arrays that have a level dimension.

     write(6,*) ' Allocating memory for MADIS arrays Multi-Agency Profilers (MAP) obs...'
     allocate (stanam(max_map))
     allocate (provdr(max_map))
     allocate (timeob(max_map))
     allocate (obtime(max_map))
     allocate (wmoid(max_map))
     allocate (lat(max_map))
     allocate (lon(max_map))
     allocate (elev(max_map))
     allocate (nlevels(max_map))

     nlev = max_maplev

     allocate (p(nlev*max_map))
     allocate (z(nlev*max_map))
     allocate (t(nlev*max_map))
     allocate (td(nlev*max_map))
     allocate (dd(nlev*max_map))
     allocate (ff(nlev*max_map))
     allocate (qca(nlev*max_map))
     allocate (qcr(nlev*max_map))
     allocate (qcd(nlev*max_map))

     CALL MINIT('MAP','FSL',.true.,istatus) ! No AWIPS database for MAP
     if(istatus /= success_p)stop
     CALL MSETQC(qcall,istatus)
     if(istatus /= success_p)stop

! Set the time window and load in the station info.

     CALL MSETWIN(madis_profiler_minbck,madis_profiler_minfwd,madis_profiler_recwin,istatus)
     if(istatus /= success_p)stop
     CALL MMAPSTA(atime,nsta,stanam,wmoid,lat,lon,elev,timeob,provdr,istatus)
     if(istatus /= success_p)stop   ! Can't possibly happen, so stop if it does.
     do i = 1, nsta
       CALL MTRNTIM(timeob(i),2,obtime(i),istatus)
     enddo

! Read in the observations.

! I tested two files, nlevels=max_maplevel=202     
     CALL MGETMAP(atime,'P',ntmp,nobs,nlevels,p,qcd,qca,qcr,istatus)
     CALL MGETMAP(atime,'DD',ntmp,nobs,nlevels,dd,qcd,qca,qcr,istatus)
     CALL MGETMAP(atime,'FF',ntmp,nobs,nlevels,ff,qcd,qca,qcr,istatus)
     CALL MGETMAP(atime,'HT',ntmp,nobs,nlevels,z,qcd,qca,qcr,istatus)

     do i = 1, nlev*max_map
        if (p(i) == madis_miss )   p(i) = littler_miss
        if (dd(i) == madis_miss )  dd(i) = littler_miss
        if (ff(i) == madis_miss )  ff(i) = littler_miss
        if (z(i) == madis_miss )   z(i) = littler_miss
     enddo

     t(1:nlev*max_map) = littler_miss
     td(1:nlev*max_map) = littler_miss

     j = 0
     open(unit =unit_out , file = trim(madis2little_r)//"map/"//"MAP_LITTLE_R_"//analysis_date(1:13))
     do i  =  1, nsta
       CALL WRITE_LITTLER_UPA(p(j+1:j+nlev),z(j+1:j+nlev),t(j+1:j+nlev),&
                              td(j+1:j+nlev),ff(j+1:j+nlev),dd(j+1:j+nlev),&
                              elev(i),lat(i),lon(i),obtime(i),stanam(i),nlevels(i),unit_out,"FM-132")
       j = j + nlev
     enddo
     close(unit_out)
     
     write(6,*) ' Finished writting MADIS arrays MAP obs... to LITTLE_R'
     write(6,*)

     deallocate (stanam)
     deallocate (provdr)
     deallocate (timeob)
     deallocate (obtime)
     deallocate (wmoid)
     deallocate (lat)
     deallocate (lon)
     deallocate (elev)
     deallocate (nlevels)

     deallocate (p)
     deallocate (td)
     deallocate (t)
     deallocate (z)
     deallocate (dd)
     deallocate (ff)
     deallocate (qca)
     deallocate (qcr)
     deallocate (qcd)

  endif ! if(use_mapobs)then

  if(trim(use_airepobs) .eq. 'TRUE')then

! Allocate the local memory for the MADIS arrays that have a level dimension.
     write(6,*) ' Allocating memory for MADIS arrays AIREP obs...'
     allocate (stanam(max_acars))
     allocate (timeob(max_acars))
     allocate (obtime(max_acars))
     allocate (lat(max_acars))
     allocate (lon(max_acars))

     allocate (p(max_acars))
     allocate (td(max_acars))
     allocate (t(max_acars))
     allocate (z(max_acars))
     allocate (dd(max_acars))
     allocate (ff(max_acars))
     allocate (qca(max_acars))
     allocate (qcr(max_acars))
     allocate (qcd(max_acars))
   
     CALL MINIT('ACARS',madis_airep_db,.true.,istatus)
     if(istatus /= success_p)stop
     CALL MSETQC(qcall,istatus)
     if(istatus /= success_p)stop

! Set the time window for this dataset with the user's choices.

     CALL MSETWIN(madis_airep_minbck,madis_airep_minfwd,madis_airep_recwin,istatus)
     if(istatus /= success_p)stop

! Load in the stations with data for this time window.

     CALL MACARSSTA(atime,nsta,stanam,timeob,istatus)
     if(istatus /= success_p)stop
! change obtime for Julian date to YYYYMMDDHHMM
     do i = 1, nsta
        CALL MTRNTIM(timeob(i),2,obtime(i),istatus)
     enddo

! Read in the observations.  Note that unlike the other MADIS datasets,
! the lat/lon are read in as obs, not station info.

     CALL MGETACARS(atime,'P',ntmp,nobs,p,qcd,qca,qcr,istatus)
     CALL MGETACARS(atime,'T',ntmp,nobs,t,qcd,qca,qcr,istatus)
     CALL MGETACARS(atime,'TD',ntmp,nobs,td,qcd,qca,qcr,istatus)
     CALL MGETACARS(atime,'DD',ntmp,nobs,dd,qcd,qca,qcr,istatus)
     CALL MGETACARS(atime,'FF',ntmp,nobs,ff,qcd,qca,qcr,istatus)
     CALL MGETACARS(atime,'LAT',ntmp,nobs,lat,qcd,qca,qcr,istatus)
     CALL MGETACARS(atime,'LON',ntmp,nobs,lon,qcd,qca,qcr,istatus)
     CALL MGETACARS(atime,'HT',ntmp,nobs,z,qcd,qca,qcr,istatus)

     do i = 1, nsta
        if (p(i) == madis_miss )    p(i)   = littler_miss
        if (t(i) == madis_miss )    t(i)   = littler_miss
        if (td(i) == madis_miss )   td(i)  = littler_miss
        if (dd(i) == madis_miss )   dd(i)  = littler_miss
        if (ff(i) == madis_miss )   ff(i)  = littler_miss
        if (lat(i) == madis_miss )  lat(i) = littler_miss
        if (lon(i) == madis_miss )  lon(i) = littler_miss
        if (z(i) == madis_miss )    z(i)   = littler_miss
     enddo

     open(unit =unit_out , file = trim(madis2little_r)//"acars/"//"ACARS_LITTLE_R_"//analysis_date(1:13))
     do i  =  1, nsta
        CALL WRITE_LITTLER_ONELVL(p(i),z(i),t(i),td(i),ff(i),dd(i),lat(i),lon(i),obtime(i),stanam(i),unit_out,"FM-96")
     enddo
     close(unit_out)
     write(6,*) ' Finished writting MADIS arrays AIREP obs... to LITTLE_R'
     write(6,*)

     deallocate (stanam)
     deallocate (timeob)
     deallocate (obtime)
     deallocate (lat)
     deallocate (lon)
     deallocate (p)
     deallocate (td)
     deallocate (t)
     deallocate (dd)
     deallocate (ff)
     deallocate (z)
     deallocate (qca)
     deallocate (qcr)
     deallocate (qcd)

  endif ! if(use_airepobs)then
 
 if(trim(use_geoamvobs) .eq. 'TRUE')then

! Allocate the local memory for the MADIS arrays that have a level dimension.
     write(6,*) ' Allocating memory for MADIS arrays SATOB obs...'
     allocate (stanam(max_satw))
     allocate (timeob(max_satw))
     allocate (obtime(max_satw))
     allocate (lat(max_satw))
     allocate (lon(max_satw))
     allocate (provdr(max_satw))

     allocate (p(max_satw))
     allocate (td(max_satw))
     allocate (t(max_satw))
     allocate (z(max_satw))
     allocate (dd(max_satw))
     allocate (ff(max_satw))
     allocate (pw(max_satw))
     allocate (slp(max_satw))
     allocate (qca(max_satw))
     allocate (qcr(max_satw))
     allocate (qcd(max_satw))

     allocate (tmp_obtime(max_satw))
     allocate (tmp_lat(max_satw))
     allocate (tmp_lon(max_satw))
     allocate (tmp_p(max_satw))


     CALL MINIT('SATWND',madis_geoamv_db,.true.,istatus)
     if(istatus /= success_p)stop

! Set the number and types of SATW variables to read.
      nsatw_vartype = 0

      if(madis_geoamv_ir.and.madis_geoamv_wv.and.madis_geoamv_vis.and. &
         madis_geoamv_s10.and.madis_geoamv_s11)then

         nsatw_vartype = 1
         satw_var_len(1) = 2
         satw_var(1,1) = 'DD'
         satw_var(2,1) = 'FF'

      else

         if(madis_geoamv_ir)then
            nsatw_vartype = nsatw_vartype + 1
            satw_var_len(nsatw_vartype) = 4
            satw_var(1,nsatw_vartype) = 'DDIR'
            satw_var(2,nsatw_vartype) = 'FFIR'
         endif

         if(madis_geoamv_wv)then
            nsatw_vartype = nsatw_vartype + 1
            satw_var_len(nsatw_vartype) = 4
            satw_var(1,nsatw_vartype) = 'DDWV'
            satw_var(2,nsatw_vartype) = 'FFWV'
         endif
         if(madis_geoamv_vis)then
            nsatw_vartype = nsatw_vartype + 1
            satw_var_len(nsatw_vartype) = 5
            satw_var(1,nsatw_vartype) = 'DDVIS'
            satw_var(2,nsatw_vartype) = 'FFVIS'
         endif

         if(madis_geoamv_s10)then
            nsatw_vartype = nsatw_vartype + 1
            satw_var_len(nsatw_vartype) = 5
            satw_var(1,nsatw_vartype) = 'DDS10'
            satw_var(2,nsatw_vartype) = 'FFS10'
         endif
         if(madis_geoamv_s11)then
            nsatw_vartype = nsatw_vartype + 1
            satw_var_len(nsatw_vartype) = 5
            satw_var(1,nsatw_vartype) = 'DDS11'
            satw_var(2,nsatw_vartype) = 'FFS11'
         endif
     endif

! If I do not call these two subs, it looks like that ALL-GOES-O is set true somewhere by default
! so that 3h ob can be read. That's the reason I call two subs here to make sure to read 1h and 
! 3h ob if they are there.

     CALL MSETSATWNDPVDR('ALL-GOES-O',.true.,istatus)
     CALL MSETSATWNDPVDR('ALL-GOES-X',.true.,istatus)

! Set the time window for this dataset with the user's choices.
     CALL MSETWIN(madis_geoamv_minbck,madis_geoamv_minfwd,madis_geoamv_recwin,istatus)
     if(istatus /= success_p)stop

! Load in the stations with data for this hour.  Note that the station call
! covers all variable types.  Therefore, when we read each variable type's
! data separately, we'll have to overlay that into the dd/ff arrays so
! we don't wipe out data read for an earlier variable type.  We'll use the
! not-applicable pw/slp arrays for temporary storage.

     CALL MSATWNDSTA(atime,nsta,provdr,lat,lon,p,timeob,istatus)
     if(istatus /= success_p)stop
! change obtime for Julian date to YYYYMMDDHHMM
     do i = 1, nsta
        CALL MTRNTIM(timeob(i),2,obtime(i),istatus)
     enddo

! Read in the observations, appending each variable type as we go along.
     k=0
     do i = 1, nsatw_vartype

        CALL MGETSATWND(atime,satw_var(1,i)(1:satw_var_len(i)),ntmp,nobs, &
                      pw,qcd,qca,qcr,istatus)
        CALL MGETSATWND(atime,satw_var(2,i)(1:satw_var_len(i)),ntmp,nobs, &
                      slp,qcd,qca,qcr,istatus)
! ---------------------------------------------------------------------------------------------
! I tested MGETSATWND for madis_geoamv_vis,madis_geoamv_s10, madis_geoamv_s11. No data returned.
! So it is reasonable to set them false in namelist.madis. 
! I tested MGETSATWND for madis_geoamv_wv and madis_geoamv_ir. The ranges of data are returned 
! for each of them, however there is no data overlay. the left ranges are missing data 999999.00.  
! So k is defined to accumulate the total number of non_missing data for madis_geoamv_wv and 
! madis_geoamv_ir. tmp_lat,tmp_lon,tmp_p,tmp_obtime are to get the right matching lat, lon, p,
! obtime for each of dd and ff.
! However when I set all of madis_geoamv_vis,madis_geoamv_s10,madis_geoamv_s11, madis_geoamv_wv,
! madis_geoamv_ir true, it looks like that returned data does not have missing data.
! ntmp >= ntmp from setting madis_geoamv_wv and madis_geoamv_ir true. However ntmp is always
! equal to nsta for MSATWNDSTA and MGETSATWND calls.
! March 3. 2011
! --------------------------------------------------------------------------------------------- 
       if(istatus == success_p)then
           do j = 1, ntmp
              if((pw(j) /= madis_miss) .and. (slp(j) /= madis_miss))then
                 k=k+1
                 dd(k) = pw(j)
                 ff(k) = slp(j)
                 tmp_lat(k) = lat(j)
                 tmp_lon(k) = lon(j)
                 tmp_p(k) = p(j)
                 tmp_obtime(k) = obtime(j)
              endif
           enddo
        endif

     enddo


! Fill in missing flags for the variables that aren't in this dataset,
! changes madis missing to little_r missing and write to litter_r file.
     z(1:k) = littler_miss
     t(1:k) = littler_miss
     td(1:k) = littler_miss
     do i = 1, k
        if (tmp_p(i) == madis_miss )    tmp_p(i)   = littler_miss
        if (tmp_lat(i) == madis_miss )  tmp_lat(i) = littler_miss
        if (tmp_lon(i) == madis_miss )  tmp_lon(i) = littler_miss
     enddo
     
     open(unit=unit_out, file = trim(madis2little_r)//"HDW/"//"SATOB_LITTLE_R_"//analysis_date(1:13))
     do i  =  1, k
        CALL WRITE_LITTLER_ONELVL(p(i),z(i),t(i),td(i),ff(i),dd(i),lat(i),lon(i),obtime(i)," ",unit_out,"FM-88")
     enddo
     close(unit_out)
     write(6,*) ' Finished writting MADIS arrays SATOB obs... to LITTLE_R'
     write(6,*)

     deallocate (stanam)
     deallocate (timeob)
     deallocate (obtime)

     deallocate (lat)
     deallocate (lon)
     deallocate (provdr)
     
     deallocate (p)
     deallocate (td)
     deallocate (t)
     deallocate (dd)
     deallocate (ff)
     deallocate (pw)
     deallocate (slp)
     deallocate (z)
     deallocate (qca)
     deallocate (qcr)
     deallocate (qcd)

     deallocate (tmp_obtime)
     deallocate (tmp_lat)
     deallocate (tmp_lon)
     deallocate (tmp_p)

endif ! if(use_geoamvobs)



8000 if(pvdriostat /= 0)then

! I/O error on opening or reading a provider-selection file.

      write(0,*)'ERROR:  ',pvdriotype,' failure on ',trim(pvdrfile), &
                ' IOSTAT = ',pvdriostat
      stop

     endif

end program madis_to_little_r

