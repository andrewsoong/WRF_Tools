 PROGRAM p_interp
!  Program to read wrfout data and interpolate to pressure levels
!  The program reads namelist.pinterp
!  November 2007 - Cindy Bruyere
!
!=================================Make Executable============================
!  Make executable:
!    DEC Alpha
!      f90 p_interp.F90 -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -free  -o p_interp
!
!   Linux flags
!      pgf90 p_interp.F90 -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -Mfree  -o p_interp
!
!   Sun flags
!      f90 p_interp.F90 -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -free  -o p_interp
!
!   SGI flags
!      f90 p_interp.F90 -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -freeform  -o p_interp
!
!   IBM serial flags:
!      xlf p_interp.F90 -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -qfree=f90  -o p_interp
!
!   IBM parallel flags:
!      mpxlf_r -qfree=f90 -L/usr/local/netcdf/lib -lnetcdf -lm \
!      -I/usr/local/netcdf/include -o p_interp p_interp.F90 -WF,-D_MPI
!
!   IBM parallel debug:
!      mpxlf_r -qfree=f90 -g -C -qsigtrap=xl__trcedump -qflttrap=ov:zero:inv:en \
!      -L/usr/local/netcdf/lib -lnetcdf -lm -I/usr/local/netcdf/include -o \
!      p_interp p_interp.F90 -WF,-D_MPI
!
!   Mac flags (with xlf compiler)
!      xlf p_interp.F90 -L/usr/local/netcdf-xlf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf-xlf/include  -qfree=f90  -o p_interp
!
!   Mac flags (with g95 compiler)
!	g95 p_interp.F90 -L/usr/local/netcdf/lib -lnetcdf -lm  \
!	-I/usr/local/netcdf/include -ffree-form -o p_interp
!
!   Mac flags (with pgf90 compiler)
!      pgf90 p_interp.F90 -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -Mfree  -o p_interp
!
!============================================================================
!----------------------------------------------------------------------------

      IMPLICIT NONE
      
      INCLUDE 'netcdf.inc'

#ifdef _MPI
      INCLUDE 'mpif.h'
#endif

      INTERFACE
         SUBROUTINE def_map_proj_var (mcid, map_proj,           &
                              std_parallel, central_merid_lon,  &
                              straight_vert_lon_from_pole,      &
                              proj_origin_lat, proj_origin_lon, &
                              false_easting, false_northing     )

            INTEGER              , INTENT(IN) :: mcid          ! file id
            INTEGER              , INTENT(IN) :: map_proj      ! map_proj from global atts
            REAL, INTENT(IN), OPTIONAL        :: std_parallel(2)
            REAL, INTENT(IN), OPTIONAL        :: central_merid_lon
            REAL, INTENT(IN), OPTIONAL        :: straight_vert_lon_from_pole
            REAL, INTENT(IN), OPTIONAL        :: proj_origin_lat
            REAL, INTENT(IN), OPTIONAL        :: proj_origin_lon
            REAL, INTENT(IN), OPTIONAL        :: false_easting
            REAL, INTENT(IN), OPTIONAL        :: false_northing
         END SUBROUTINE def_map_proj_var
      END INTERFACE

      INTERFACE
         SUBROUTINE def_time_var (mcid, times_in_file, cval, long_name, &
                                  time_data, dtime, units, calendar)
            INTEGER     , INTENT(IN)           :: mcid            ! file id
            INTEGER     , INTENT(IN)           :: times_in_file   ! number of times in a file
            CHARACTER(*), INTENT(IN)           :: cval            ! variable short name
            CHARACTER(*), INTENT(IN)           :: long_name
            INTEGER,          DIMENSION(times_in_file) , INTENT(IN), OPTIONAL &
                                         :: time_data       ! generic integer time
            DOUBLE PRECISION, DIMENSION(times_in_file) , INTENT(IN), OPTIONAL &
                                         :: dtime           ! double precision time (coordinate var)
            CHARACTER(*), INTENT(IN), OPTIONAL :: units
            CHARACTER(*), INTENT(IN), OPTIONAL :: calendar
         END SUBROUTINE def_time_var
      END INTERFACE

      REAL, PARAMETER                                    :: Rd = 287.04
      REAL, PARAMETER                                    :: Cp = 7.*Rd/2.
      REAL, PARAMETER                                    :: RCP = Rd/Cp
      REAL, PARAMETER                                    :: p0 = 100000.
      INTEGER, PARAMETER                                 :: path_file_length=250
      INTEGER, PARAMETER                                 :: dname_length=31

      CHARACTER,        ALLOCATABLE, DIMENSION(:,:,:,:) :: text
      CHARACTER (LEN=dname_length),ALLOCATABLE, DIMENSION(:)       :: dnamei, dnamej
      CHARACTER (LEN=19),ALLOCATABLE, DIMENSION(:)       :: Times_strings
      CHARACTER(LEN=path_file_length),ALLOCATABLE, DIMENSION(:) :: input_file_names
      CHARACTER(LEN=path_file_length),ALLOCATABLE, DIMENSION(:) :: output_file_names
      DOUBLE PRECISION,  ALLOCATABLE, DIMENSION(:)       :: dtime
      REAL,              ALLOCATABLE, DIMENSION(:,:,:,:) :: data1, data2
      REAL,              ALLOCATABLE, DIMENSION(:,:,:,:) :: pres_field, pres_out
      REAL,              ALLOCATABLE, DIMENSION(:,:,:,:) :: pres_stagU, pres_stagV
      REAL,              ALLOCATABLE, DIMENSION(:,:,:,:) :: ght, phb, qv, tk, rh, geop_hgt
      REAL,              ALLOCATABLE, DIMENSION(:,:,:,:) :: landusef, soilctop, soil_layers
      REAL,              ALLOCATABLE, DIMENSION(:,:,:,:) :: invert_soil_info
      REAL,              ALLOCATABLE, DIMENSION(:,:,:)   :: psfc, soilhgt
      REAL,              ALLOCATABLE, DIMENSION(:,:,:)   :: sea_level_pressure, t_sea_level, t_surf
      REAL,              ALLOCATABLE, DIMENSION(:,:,:)   :: XLAT, XLONG
      REAL,              ALLOCATABLE, DIMENSION(:,:)     :: dzs
      REAL,              ALLOCATABLE, DIMENSION(:,:)     :: ter
      REAL,              ALLOCATABLE, DIMENSION(:)       :: pressure
! dvali = input dimensions ; dvalj = output dimensions
      INTEGER,           ALLOCATABLE, DIMENSION(:)       :: dvali, dvalj, mcid_arr
      INTEGER,           ALLOCATABLE, DIMENSION(:)       :: year, month, day, hour, minute, second
      INTEGER,           ALLOCATABLE, DIMENSION(:)       :: yyyymmddhh
      INTEGER,           ALLOCATABLE, DIMENSION(:)       :: time
      INTEGER,           ALLOCATABLE, DIMENSION(:,:,:,:) :: idata1, idata2
      INTEGER,           ALLOCATABLE, DIMENSION(:,:,:)   :: level
      INTEGER,                        DIMENSION(4)       :: start_dims = 1
      INTEGER,                        DIMENSION(4)       :: dims_in, dims_out, pdim, indx
      INTEGER,                        DIMENSION(6)       :: ishape, jshape
      INTEGER, PARAMETER                                 :: int_buff_size=12 
      INTEGER,                 DIMENSION(int_buff_size)  :: int_buffer
      INTEGER                                            :: new_dim, this_output_file

      INTEGER                                            :: num_st_layers, i_sf_sfc_phys
      INTEGER, PARAMETER                                 :: cval_len=80
      INTEGER, PARAMETER                                 :: z_dim24=24, z_dim16=16, z_dim12=12
      CHARACTER (LEN=cval_len)                           :: cval, cval_not_used
      CHARACTER (LEN=path_file_length)                   :: long_string
      CHARACTER (LEN=31)                                 :: cname, test_dim_name
      CHARACTER (LEN=80)                                 :: att_text
      CHARACTER (LEN=path_file_length)                   :: input_file, output_file
      CHARACTER (LEN=path_file_length)                   :: path_to_input
      CHARACTER (LEN=path_file_length)                   :: path_to_output
      CHARACTER (LEN=path_file_length)                   :: input_name
      CHARACTER (LEN=path_file_length)                   :: output_name
      CHARACTER (LEN=2)                                  :: ch_grid_id
      CHARACTER (LEN=132)                                :: command
      INTEGER, PARAMETER                                 :: p_len=20
      INTEGER, PARAMETER                                 :: f_len=2000
      INTEGER, PARAMETER                                 :: n_interp_levels=99
      CHARACTER (LEN=p_len)                              :: process, dummy
      CHARACTER (LEN=f_len)                              :: fields, process_these_fields
!----------------------------------------------------------------------------
! var_name: Diagnostic fields calculated: 
! 1) automatically if process is set to 'all' or 
! 2) if these fields are set explicitly in 'fields'  
! If  you add a field to this array, you will need 
! to add code at the end of this program to calculate it.
!----------------------------------------------------------------------------
      INTEGER, PARAMETER :: nfields=4
      CHARACTER (LEN=10) :: var_name(nfields)=(/"PRES","TT  ","GHT ","RH  "/)
      CHARACTER (LEN=20) :: var_unit(nfields)=(/"Pa","K ","m ","% "/)
      CHARACTER (LEN=50) :: var_desc(nfields)=(/"Pressure           ", &
                                                "Temperature        ", &
                                                "Geopotential Height", &
                                                "Relative Humidity  "/)
      LOGICAL            :: diag_processed(nfields)=.FALSE.

! Fields calculated to add for met_em* files, that aren't in initial wrfout file
      INTEGER, PARAMETER :: met_em_fields=5
      CHARACTER (LEN=11) :: met_em_name_all(met_em_fields)=(/"LANDUSEF   ", &
                                                             "SOILCTOP   ", &
                                                             "SOIL_LAYERS", &
                                                             "SOILHGT    ", &
                                                             "PMSL       "/)
      CHARACTER (LEN=20) :: met_em_unit_all(met_em_fields)=(/"category","category","cm      ", &
                                                             "m       ","Pa      "/)
      CHARACTER (LEN=50) :: met_em_desc_all(met_em_fields)=(/"24-category USGS landuse        ", &
                                                            "16-category top-layer soil type ", &
                                                            "                                ", &
                                                            "Terrain field of source analysis", &
                                                            "Sea-level Pressure              "/)
      CHARACTER (LEN=3)  :: met_em_mem_order_all(met_em_fields)=(/"XYZ", "XYZ", "XYZ", &
                                                                 "XY ", "XY "/)
      LOGICAL                               :: met_em_processed(met_em_fields)=.FALSE.
      LOGICAL                               :: met_em_exist
      CHARACTER (LEN=50), ALLOCATABLE, DIMENSION(:) :: met_em_name, met_em_unit, met_em_desc, &
                                                       met_em_mem_order
      REAL, DIMENSION(n_interp_levels)      :: interp_levels
      REAL                                  :: rval
      REAL                                  :: MISSING=1.e36
      REAL                                  :: truelat(2), stand_lon
      REAL                                  :: proj_origin_lat, proj_origin_lon
      REAL                                  :: false_easting=0.0, false_northing=0.0
      REAL                                  :: time_start, time_end, accum_depth
      INTEGER                               :: LINLOG = 1
      INTEGER                               :: interp_method=1
      INTEGER                               :: extrapolate=0
      INTEGER                               :: ncid, mcid, rcode
      INTEGER                               :: idm, ndims, nvars, natt, ngatts
      INTEGER                               :: dimid, n_soil_layers, icount
      INTEGER                               :: nunlimdimid, map_proj, grid_id
      INTEGER                               :: i, ii, j, jj, kk,iweg, isng, ibtg
      INTEGER                               :: ivar, jvar, isample_in, jsample_in
      INTEGER                               :: isample_out, jsample_out, time_dim
      INTEGER                               :: id_var, times_in_input_file
      INTEGER                               :: times_in_output_file, num_output_files
      INTEGER                               :: ilen, itype, ival, na, funit, ios
      INTEGER                               :: num_metgrid_levels
      INTEGER                               :: number_of_input_files
      INTEGER                               :: ierr, loop, loslen, lent
      INTEGER                               :: is_there, jdiag
      INTEGER                               :: n_diag_fields, extra_fields
      INTEGER                               :: wrf_times_2udunits_c, wrf_times_to_ymdh
      LOGICAL                               :: is_used, got_a_diagnostic, got_a_met_em
      LOGICAL                               :: debug=.FALSE.
      LOGICAL                               :: mpi_debug=.FALSE.
      LOGICAL                               :: interpolate=.FALSE.
      LOGICAL                               :: unstagger_grid
      LOGICAL                               :: fix_meta_stag=.FALSE.
      LOGICAL                               :: bit64=.FALSE.
      LOGICAL                               :: first=.TRUE.
      LOGICAL                               :: output_grid_mapping
      LOGICAL                               :: met_em_output=.FALSE.
      LOGICAL                               :: split_output =.FALSE.
! Variables added for parallelization
      INTEGER, PARAMETER                    :: master_task = 0
      INTEGER, PARAMETER                    :: from_master = 1
      INTEGER, PARAMETER                    :: from_worker = 2
      INTEGER                               :: my_task, numtasks, dest
      INTEGER                               :: sn_chunksize, sn_extra, sn_cols, sn_size
      INTEGER                               :: sn_col_start, sn_col_end, iend, istart
      INTEGER                               :: xyzt_arraysize, ix, iy, iz
      INTEGER                               :: xyt_arraysize, xy_arraysize
      INTEGER                               :: xyzt_masssize, xyt_masssize, xy_masssize
      INTEGER                               :: xyzt_dimsout, mass_cols
      REAL, ALLOCATABLE, DIMENSION(:,:,:,:) :: new_data1, new_data_buff
      REAL, ALLOCATABLE, DIMENSION(:,:,:,:) :: data2_from_worker, data2_to_master
      REAL, ALLOCATABLE, DIMENSION(:,:,:,:) :: new_pressure, new_pressure_buff
      REAL, ALLOCATABLE, DIMENSION(:,:,:,:) :: tk_buff, qv_buff
      REAL, ALLOCATABLE, DIMENSION(:,:,:)   :: psfc_buff
      REAL, ALLOCATABLE, DIMENSION(:,:)     :: ter_buff

#ifdef _MPI
      INTEGER :: status(MPI_STATUS_SIZE)
#endif

      NAMELIST /io/ path_to_input, input_name, path_to_output, output_name,  &
                    process, fields, mpi_debug, debug, bit64, met_em_output, &
                    split_output
      NAMELIST /interp_in/ interp_levels, interp_method, extrapolate, unstagger_grid

#ifdef _MPI
      write (6,*) 'Initializing MPI'
      call MPI_INIT(ierr)
      call MPI_COMM_RANK(MPI_COMM_WORLD, my_task, ierr)
      call MPI_COMM_SIZE(MPI_COMM_WORLD, numtasks, ierr)
#else
! not MPI
      my_task = master_task
      numtasks = 1
#endif
      IF (my_task == master_task) THEN
         CALL cpu_time(time_start)     ! Start timer
      ENDIF

      path_to_input   = './'
      path_to_output  = './'
      output_name     = ' '
      interp_levels   = -99999.
      process         = 'all'
      unstagger_grid  = .FALSE.


      IF (my_task == master_task) THEN
      ! Read parameters from Fortran namelist
         DO funit=10,100
            INQUIRE(unit=funit, opened=is_used)
            IF (.not. is_used) EXIT
         END DO
         OPEN(funit,file='namelist.pinterp',status='old',form='formatted',iostat=ios)
         IF ( ios /= 0 ) call handle_err(ios, "ERROR opening namelits.pinterp")
         READ(funit,io)
         READ(funit,interp_in)
         CLOSE(funit)

      ! Get all the input file names

         lent = len_trim(path_to_input)
         IF ( path_to_input(lent:lent) /= "/" ) THEN
            path_to_input = TRIM(path_to_input)//"/"
         ENDIF
         lent = len_trim(path_to_output)
         IF ( path_to_output(lent:lent) /= "/" ) THEN
            path_to_output = TRIM(path_to_output)//"/"
         ENDIF

         input_name = TRIM(path_to_input)//TRIM(input_name)

         !  Build a UNIX command, and "ls", of all of the input files 
         loslen = LEN ( command )
         CALL all_spaces ( command , loslen ) 
         WRITE ( command , FMT='("ls -1 ",A," > .foo")' ) TRIM ( input_name )
           
        !  We stuck all of the matching files in the ".foo" file.  Now we place the 
        !  number of the those file (i.e. how many there are) in ".foo1". 
  
         CALL SYSTEM ( TRIM ( command ) ) 
         CALL SYSTEM ( '( cat .foo | wc -l > .foo1 )' )
  
        !  Read the number of files.
         OPEN (FILE   = '.foo1'       , &
               UNIT   = 112           , &
               STATUS = 'OLD'         , &
               ACCESS = 'SEQUENTIAL'  , &
               FORM   = 'FORMATTED'     )
  
         READ ( 112 , * ) number_of_input_files
         CLOSE ( 112 )
  
        !  If we want met_em files, turn on extrapolation
         IF ( met_em_output ) THEN
            IF ( TRIM(process) .eq. 'list' ) THEN
               print*, '       If you have met_em_output = .TRUE.,'
               call handle_err (1, "       process must be set to 'all' in the namelist.")
            END IF
            write(6,*) "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
            write(6,*) "  NOTE: Extrapolation is being turned on for met_em files "
            write(6,*) "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
            extrapolate = 1
          ! Check that the lowest pressure level is close to the surface
            IF ( interp_levels(1) .lt. 950.) THEN
               write (6,*) "ERROR:  Lowest pressure level set in interp_levels in the"
               write (6,*) "namelist is above 950 mb.  met_em needs surface data. "
               write (6,*) "Include a pressure level close to the surface: 1000 mb "
               write (6,*) "and other mandatory levels: 925, 850, 700, 500, 400, 300,"
               call handle_err (1, "250, 200, 150, 100 ")
            END IF
            split_output = .TRUE.   
            unstagger_grid = .FALSE.   
         END IF
        !  If there are zero files, we are toast.
         IF ( number_of_input_files .LE. 0 ) THEN
            print*, ' Oops, we need at least ONE input file for the program to read.'
            print*, '       Make sure you have the path, and name file(s) correct,'
            call handle_err (1, "       including wild characters if needed.")
         END IF
  
        !  Allocate space for this many files.
         ALLOCATE (  input_file_names(number_of_input_files) , STAT=ierr )

        !  Did the allocate work OK?
         IF ( ierr .NE. 0 ) THEN
            print*,  ' tried to allocate ', number_of_input_files, ' input files, (look at ./foo)'
            call handle_err( 1, " ")
         END IF

        !  Initialize all of the file names to blank.
          input_file_names = '                                                  ' // &
                             '                                                  ' // &
                             '                                '
        !  Open the file that has the list of filenames.
         OPEN (FILE   = '.foo'        , &
               UNIT   = 111           , &
               STATUS = 'OLD'         , &
               ACCESS = 'SEQUENTIAL'  , &
               FORM   = 'FORMATTED'     )
  
        !  Read all of the file names and store them.
         DO loop = 1 , number_of_input_files
            READ ( 111 , FMT='(A)' ) input_file_names(loop)
         END DO
         CLOSE ( 111 )
         print*, " " 
  
        !   We clean up our own messes.
         CALL SYSTEM ( '/bin/rm -f .foo'  )
         CALL SYSTEM ( '/bin/rm -f .foo1' )
     
        ! Do we have a list of field that we want on output?
         process_these_fields = ','
         IF ( INDEX(process,'list') /= 0) THEN
            DO i = 1 , len(fields)
               IF (fields(i:i) /= ' ' ) THEN
                  process_these_fields = trim(process_these_fields)//fields(i:i)   ! Remove spaces
               ENDIF
            END DO
            process_these_fields = trim(process_these_fields)//","
! Are any diagnostics fields in 'process_these_fields'?
            n_diag_fields = 0
            DO i = 1, nfields 
               IF (INDEX(process_these_fields,TRIM(var_name(i))) /= 0) THEN
                  n_diag_fields = n_diag_fields + 1
               ENDIF
            ENDDO
            extra_fields = n_diag_fields
         ELSEIF ( INDEX(process,'all') /= 0) THEN
            DO i = 1, nfields                       ! Put var_names in process_these_fields
               process_these_fields = trim(process_these_fields)//TRIM(var_name(i))//","
            ENDDO
            extra_fields = nfields
            IF ( met_em_output ) THEN
!-----------------------------------------------------------------
! The fields in met_em_fields may or may not be in the input file.
! Open the file and check for field.  If there, it will be accounted
! for in the nnvar count.  If not there, add to process_these_fields
! list.  We are assuming that there are the same fields in each file.
!-----------------------------------------------------------------
               icount = 0
               rcode = nf_open(input_file_names(1), 0, ncid)
               IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error opening input file for met_em fields")
               IF (ALLOCATED(met_em_name)) deallocate(met_em_name) ; ALLOCATE (met_em_name(met_em_fields))
               IF (ALLOCATED(met_em_unit)) deallocate(met_em_unit) ; ALLOCATE (met_em_unit(met_em_fields))
               IF (ALLOCATED(met_em_desc)) deallocate(met_em_desc) ; ALLOCATE (met_em_desc(met_em_fields))
               IF (ALLOCATED(met_em_mem_order)) deallocate(met_em_mem_order) 
               ALLOCATE (met_em_mem_order(met_em_fields))
               DO kk = 1, met_em_fields 
                  rcode = nf_inq_varid(ncid, TRIM(met_em_name_all(kk)), i)   ! get ID
                  IF (rcode /= nf_noerr) THEN  ! field not in file, will have to generate
                     icount = icount + 1
                     met_em_name(icount) = TRIM(met_em_name_all(kk))
                     met_em_unit(icount) = TRIM(met_em_unit_all(kk))
                     met_em_desc(icount) = TRIM(met_em_desc_all(kk))
                     met_em_mem_order(icount) = TRIM(met_em_mem_order_all(kk))
                  ENDIF
               ENDDO
               DO kk = 1, icount
                  process_these_fields = trim(process_these_fields)//TRIM(met_em_name(kk))//","
               ENDDO
               extra_fields = nfields + icount
               rcode = nf_close(ncid)
            ENDIF
         ELSE
            write (6,*) TRIM(process), " is not a valid option for namelist variable 'process'"
            call handle_err (1, "Set this option to 'all' or 'list' in the namelist file")
         END IF
         write (6,*) 'process_these_fields = ',trim(process_these_fields)

         write(6,*) 
         write(6,*) "##############################################################"
         write(6,'(A,i4,A)') " RUNNING p_interp V1.0 on ", number_of_input_files, " file(s)."

         write(6,*) 
         write(6,'(A,$)') " INTERPOLATION METHOD: "
         IF ( interp_method == 1 ) write(6,*) " linear in p"
         IF ( interp_method == 2 ) write(6,*) " linear in log p"
         IF (extrapolate == 0) write(6,*)"BELOW GROUND will be set to missing values"
         IF (extrapolate == 0) write(6,*)"ABOVE model top will be set to missing values"
         IF (extrapolate == 1) write(6,*)"BELOW GROUND will be extrapolated"
         IF (extrapolate == 1) write(6,*)"ABOVE model top will be set to values at model top"
         IF (.not. unstagger_grid) write(6,*)"Data will be output on C-grid" 
         IF (unstagger_grid) write(6,*)"Data will be output on unstaggered grid"

      ! Find the pressure levels to interpolate to
         write(6,*)
         write(6,*) "INTERPOLATING TO PRESSURE LEVELS: "
         write(6,*)
         write(6,*)
      ENDIF   ! End of master_task

#ifdef _MPI
      ! Broascast necessary variables to all processors 
      call MPI_BCAST(path_to_input ,path_file_length  ,MPI_CHARACTER, master_task, MPI_COMM_WORLD, ierr)
      call MPI_BCAST(path_to_output, path_file_length ,MPI_CHARACTER, master_task, MPI_COMM_WORLD, ierr)
      call MPI_BCAST(input_name    , path_file_length ,MPI_CHARACTER, master_task, MPI_COMM_WORLD, ierr)
      call MPI_BCAST(output_name   , path_file_length ,MPI_CHARACTER, master_task, MPI_COMM_WORLD, ierr)
      call MPI_BCAST(process       , p_len            ,MPI_CHARACTER, master_task, MPI_COMM_WORLD, ierr)
      call MPI_BCAST(fields        , f_len            ,MPI_CHARACTER, master_task, MPI_COMM_WORLD, ierr)
      call MPI_BCAST(debug         , 1                ,MPI_LOGICAL  , master_task, MPI_COMM_WORLD, ierr)
      call MPI_BCAST(mpi_debug     , 1                ,MPI_LOGICAL  , master_task, MPI_COMM_WORLD, ierr)
      call MPI_BCAST(bit64         , 1                ,MPI_LOGICAL  , master_task, MPI_COMM_WORLD, ierr)
      call MPI_BCAST(met_em_output , 1                ,MPI_LOGICAL  , master_task, MPI_COMM_WORLD, ierr)
      call MPI_BCAST(interp_method , 1                ,MPI_INTEGER  , master_task, MPI_COMM_WORLD, ierr)
      call MPI_BCAST(interp_levels , n_interp_levels  ,MPI_INTEGER  , master_task, MPI_COMM_WORLD, ierr)
      call MPI_BCAST(number_of_input_files , 1        ,MPI_INTEGER  , master_task, MPI_COMM_WORLD, ierr)
      call MPI_BCAST(extrapolate   , 1                ,MPI_INTEGER  , master_task, MPI_COMM_WORLD, ierr)
      call MPI_BCAST(unstagger_grid, 1                ,MPI_LOGICAL  , master_task, MPI_COMM_WORLD, ierr)
      call MPI_BCAST(process_these_fields, p_len      ,MPI_CHARACTER, master_task, MPI_COMM_WORLD, ierr)

      IF (MPI_DEBUG) THEN
         PRINT *, "TASK #", my_task, " has path_to_input= ",TRIM(path_to_input)
         PRINT *, "TASK #", my_task, " has path_to_output= ",TRIM(path_to_output)
         PRINT *, "TASK #", my_task, " has input_name= ",TRIM(input_name)
         PRINT *, "TASK #", my_task, " has output_name= ",TRIM(output_name)
         PRINT *, "TASK #", my_task, " has process= ",TRIM(process)
         PRINT *, "TASK #", my_task, " has fields= ",TRIM(fields)
         PRINT *, "TASK #", my_task, " has debug= ",debug
         PRINT *, "TASK #", my_task, " has mpi_debug= ",mpi_debug
         PRINT *, "TASK #", my_task, " has bit64= ",bit64
         PRINT *, "TASK #", my_task, " has met_em_output= ",met_em_output
         PRINT *, "TASK #", my_task, " has interp_method= ",interp_method
         PRINT *, "TASK #", my_task, " has interp_levels= ",interp_levels
         PRINT *, "TASK #", my_task, " has number_of_input_files= ",number_of_input_files
         PRINT *, "TASK #", my_task, " has extrapolate= ",extrapolate
         PRINT *, "TASK #", my_task, " has unstagger_grid= ",unstagger_grid
         PRINT *, "TASK #", my_task, " has process_these_fields= ",TRIM(process_these_fields)
      ENDIF
#endif

      LINLOG = interp_method
      num_metgrid_levels = 0
      DO
         IF (interp_levels(num_metgrid_levels+1) == -99999.) EXIT
         num_metgrid_levels = num_metgrid_levels + 1
         IF (my_task == master_task) THEN
            IF (mod(num_metgrid_levels,8) /= 0 )write(6,'(f8.3,$)') interp_levels(num_metgrid_levels)
            IF (mod(num_metgrid_levels,8) == 0 )write(6,'(f8.3)') interp_levels(num_metgrid_levels)
         ENDIF
         interp_levels(num_metgrid_levels) = interp_levels(num_metgrid_levels) * 100.0   !!! Pa
      END DO

      ! Add an additional surface level for the met_em file, necessary for real.exe
      IF (met_em_output) THEN
         num_metgrid_levels = num_metgrid_levels + 1
         interp_levels(2:num_metgrid_levels) = interp_levels(1:num_metgrid_levels-1)
         interp_levels(1) = interp_levels(2) + 500.    ! Add 5 mb to lowest pressure level
      END IF

      IF (ALLOCATED(pressure)) deallocate(pressure) ; ALLOCATE (pressure(num_metgrid_levels))
      pressure = interp_levels(1:num_metgrid_levels)/100.0
      
 100  format ('0',i1)
 101  format (i2)

      DO loop = 1, number_of_input_files

! ALLOCATE SOME VARIABLES FOR ALL TASKS
         IF (ALLOCATED(dnamei)) deallocate(dnamei) ; ALLOCATE (dnamei(20))
         IF (ALLOCATED(dnamej)) deallocate(dnamej) ; ALLOCATE (dnamej(20))
         IF (ALLOCATED(dvali))  deallocate(dvali)  ; ALLOCATE (dvali(20))
         IF (ALLOCATED(dvalj))  deallocate(dvalj)  ; ALLOCATE (dvalj(20))

         IF (my_task == master_task) THEN
            diag_processed   = .false.        ! initialize for each file
            met_em_processed = .false.
            IF (debug) write (6,*)  
            IF (debug) write(6,*) "##############################################################"
            input_file  = input_file_names(loop)
!----------------------------------------------------------------------------------
! Open input file and get Times and grid_id
!----------------------------------------------------------------------------------
            write (6,*)
            input_file  = input_file_names(loop)
            rcode = nf_open(input_file, 0, ncid)
            IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error opening input file")

            rcode = nf_inq_dimid(ncid, 'Time', i)
            IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error inquiring Time ID")

            rcode = nf_inq_dimlen(ncid, i, times_in_input_file)
            IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error inquiring Time length")

            rcode = nf_inq_varid    ( ncid, "Times", i )
            IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error inquiring Times ID")

            IF (ALLOCATED(Times_strings)) deallocate(Times_strings)
            allocate (Times_strings(times_in_input_file))
            rcode = nf_get_var_text ( ncid, i, Times_strings )
            IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error reading Times_strings")

! Some files have GRID_ID as a global attribute, some have grid_id
            rcode = nf_get_att_int (ncid, nf_global, 'GRID_ID', grid_id)
            IF (rcode .ne. nf_noerr) THEN
               rcode = nf_get_att_int (ncid, nf_global, 'grid_id', grid_id)
               IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error reading GRID_ID and grid_id")
            ENDIF

! How many output files and times in each output file for this input file?
            IF (met_em_output .OR. split_output) THEN
               num_output_files = times_in_input_file
               times_in_output_file = 1
            ELSE
               num_output_files = 1
               times_in_output_file = times_in_input_file
            ENDIF
            IF (ALLOCATED(output_file_names)) deallocate(output_file_names)
            ALLOCATE (output_file_names(num_output_files))
            IF ( .not. debug) write (6,*)

! Make an array of output file names for this input file
            num_output_file_loop: DO this_output_file = 1, num_output_files
!----------------------------------------------------------------------------------
! Create the name of the output file, there are 3 forms:
! 1) met_em.<domain>._<date_from_file(i)>.nc
! 2a) wrfout_<domain>_<date_from_file(i)>_PLEV     ! If output_file is not set
! 2b) wrfinput_<domain)_<date_from_file(i)>_PLEV   ! key off of input file, using
! 2c) p_interp_<domain>_<date_from_file(i)>_PLEV   ! p_interp as a last resort
! 3) my_file_name_<domain>_<date_from_file(i)>_PLEV
!----------------------------------------------------------------------------------
               ilen = INDEX(TRIM(input_file_names(loop)),'/',.TRUE.)   ! starting position of last slash
               IF (grid_id .lt. 10) THEN
                  write (ch_grid_id, 100) grid_id
               ELSEIF ( grid_id .le. 99) THEN
                  write (ch_grid_id, 101) grid_id
               ELSE
                  call handle_err (1, "ERROR: grid value is over 100")
               ENDIF

               IF ( met_em_output ) THEN
               !------------------------------------------------
               ! For met_em output, make a filename that real
               ! will recognize, and a new file for each time
               !------------------------------------------------

                  output_file_names(this_output_file) = TRIM(path_to_output)// &
                       "met_em.d"//ch_grid_id//"."//Times_strings(this_output_file)//".nc"

                  INQUIRE (file=output_file_names(this_output_file), exist = met_em_exist)
                  IF (met_em_exist) THEN
                     write(6,*) 'ERROR:  file '//output_file_names(this_output_file)// ' already exists'
                     call handle_err( 1, " ")
                  ENDIF
               ELSE
!                 IF (times_in_output_file == 1 .OR. split_output ) THEN ! Make a new file
                     IF ( output_name == ' ' ) THEN     ! Not set to anything in the namelist
                        IF (input_file_names(loop)(ilen+1:ilen+6) == "wrfout") THEN
                           output_file_names(this_output_file) = TRIM(path_to_output)//"wrfout_d" &
                                          //ch_grid_id//"_"//Times_strings(this_output_file)
                        ELSEIF (input_file_names(loop)(ilen+1:ilen+6) == "wrfinp") THEN
                           output_file_names(this_output_file) = TRIM(path_to_output)//"wrfinput_d" &
                                          //ch_grid_id//"_"//Times_strings(this_output_file)
                        ELSE
                           output_file_names(this_output_file) = TRIM(path_to_output)//"p_interp_d" &
                                          //ch_grid_id//"_"//Times_strings(this_output_file)
                        ENDIF
                     ELSE                               ! output_name set in namelist
                        output_file_names(this_output_file) = TRIM(path_to_output)//TRIM(output_name) &
                                       //ch_grid_id//"_"//Times_strings(this_output_file)
                     ENDIF
                     output_file_names(this_output_file) = TRIM(output_file_names(this_output_file))//"_PLEV"
!                 ENDIF
               ENDIF
               IF ( .not. debug ) write(6,*) " Output will be written to: ", &
                                               trim(output_file_names(this_output_file))
            END DO num_output_file_loop

            IF (debug) THEN
              write(6,*) " INPUT FILE:         ",trim(input_file)
              DO i = 1, num_output_files
                 write(6,*) " OUTPUT FILE(S):     ",trim(output_file_names(i))
              ENDDO
              write(6,*) "  "
            ENDIF
!----------------------------------------------------------------------------
! OPEN INPUT AND OUTPUT FILE
! output_file is input_file_new
!----------------------------------------------------------------------------
            rcode = nf_open(input_file, 0, ncid)
            IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error opening input file")

            IF (ALLOCATED(mcid_arr)) deallocate(mcid_arr) ; allocate (mcid_arr(num_output_files))
            DO i = 1, num_output_files 
               IF (bit64) THEN
                  rcode = nf_create(output_file_names(i), NF_64BIT_OFFSET, mcid_arr(i))
               ELSE
                  rcode = nf_create(output_file_names(i), 0, mcid_arr(i))
               ENDIF
               IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error creating output file(s)")
            ENDDO
!----------------------------------------------------------------------------
! GET BASIC INFORMTION ABOUT THE FILE
! most important 
!   ndims:  number of dimensions
!   nvars:  number of variables
!   ngatts: number of global attributes
!----------------------------------------------------------------------------
            rcode = nf_inq(ncid, ndims, nvars, ngatts, nunlimdimid)
            IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error inquiring dimensions from input file")
            IF (debug) THEN
              write(6,*) ' INPUT file has = ',ndims, ' dimensions, '
              write(6,*) '                  ',nvars, ' variables, and '      
              write(6,*) '                  ',ngatts,' global attributes '
              write(6,*) "  "
            ENDIF
            rcode = nf_get_att_int (ncid, nf_global, 'WEST-EAST_GRID_DIMENSION', iweg)
            rcode = nf_get_att_int (ncid, nf_global, 'SOUTH-NORTH_GRID_DIMENSION', isng)
            rcode = nf_get_att_int (ncid, nf_global, 'BOTTOM-TOP_GRID_DIMENSION', ibtg)
            IF (met_em_output) THEN
               rcode = nf_get_att_int (ncid, nf_global, 'SF_SURFACE_PHYSICS', i_sf_sfc_phys)
               IF (rcode .NE. nf_noerr) THEN
                  IF (rcode .ne. nf_noerr) call handle_err(rcode, &
                      "Error reading global attribute SF_SURFACE_PHYSICS")
               ENDIF
            ENDIF

            output_grid_mapping = .true.
            rcode = nf_get_att_int (ncid, nf_global, 'MAP_PROJ', map_proj)
            IF (rcode .NE. nf_noerr) THEN
               write (6,*) 'Error reading global attribute MAP_PROJ'
               output_grid_mapping = .false.
            ENDIF
            rcode = nf_get_att_real (ncid, nf_global, 'TRUELAT1', truelat(1))
            IF (rcode .NE. nf_noerr) THEN
               write (6,*) 'Error reading global attribute TRUELAT1'
               output_grid_mapping = .false.
            ENDIF
            rcode = nf_get_att_real (ncid, nf_global, 'TRUELAT2', truelat(2))
            IF (rcode .NE. nf_noerr .AND. map_proj .EQ. 1) THEN    ! Only needed for Lambert Conformal
               write (6,*) 'Error reading global attribute TRUELAT2'
               output_grid_mapping = .false.
            ENDIF
            rcode = nf_get_att_real (ncid, nf_global, 'STAND_LON', stand_lon)
            IF (rcode .NE. nf_noerr .AND. map_proj .NE. 3) THEN    ! Not needed for Mercator
               write (6,*) 'Error reading global attribute STAND_LON'
               output_grid_mapping = .false.
            ENDIF
            IF (.NOT.output_grid_mapping) write (6,*) 'Not writing grid_mapping info to output file'

! READ ALL DIMS FROM INPUT FILE AND CREATE SOME DIMS FOR OUTPUT FILE
            j = 0
            DO i = 1, ndims        ! Number of dimensions at top of netCDF input file
              rcode = nf_inq_dim(ncid, i, dnamei(i), dvali(i))   ! Get name and value of input dimensions
              IF ( dnamei(i) == "Time" ) THEN     ! Set time dimension for output file
                j = j + 1
                dnamej(j) = dnamei(i)              
                dvalj(j) = dvali(i)                 ! j=1,dvalj(j)=2
!               dvalj(j) = times_in_output_file     ! Makes core dump Calling interp  (j=1, dvalj(j)=1)
                DO ii = 1, num_output_files
                   rcode = nf_def_dim(mcid_arr(ii), dnamej(j), NF_UNLIMITED, j)
                ENDDO
              ENDIF 
              IF (met_em_output) THEN
                 IF ( dnamei(i) == "soil_layers_stag" ) THEN
                    num_st_layers = dvali(i)
                    IF (debug) write (6,*) 'Setting number of soil layers',dvali(i)
                 ENDIF
              ENDIF
            ENDDO

        !!! Create a pressure dims
            j = j + 1
            dnamej(j) = 'num_metgrid_levels'
            dvalj(j) = num_metgrid_levels
            DO ii = 1, num_output_files
               rcode = nf_def_dim(mcid_arr(ii), dnamej(j), dvalj(j), j)
            ENDDO
            pdim=j
!--------------------------------------------------------------
! Create dimensions for met_em_output varialbes
!--------------------------------------------------------------
            IF (met_em_output) THEN
               j = j + 1
               dnamej(j) = 'z-dimension0024'
               dvalj(j)  =  z_dim24
               DO ii = 1, num_output_files
                  rcode = nf_def_dim(mcid_arr(ii), dnamej(j), dvalj(j), j)
               ENDDO
               j = j + 1
               dnamej(j) = 'z-dimension0016'
               dvalj(j)  =  z_dim16
               DO ii = 1, num_output_files
                  rcode = nf_def_dim(mcid_arr(ii), dnamej(j), dvalj(j), j)
               ENDDO
               j = j + 1
               dnamej(j) = 'z-dimension0012'
               dvalj(j)  =  z_dim12
               DO ii = 1, num_output_files
                  rcode = nf_def_dim(mcid_arr(ii), dnamej(j), dvalj(j), j)
               ENDDO
               j = j + 1
               dnamej(j) = 'num_st_layers'
               dvalj(j)  =  num_st_layers
               DO ii = 1, num_output_files
                  rcode = nf_def_dim(mcid_arr(ii), dnamej(j), dvalj(j), j)
               ENDDO
            ENDIF

! DEALING WITH THE GLOBAL ATTRIBUTES
! Get global attributes from the input file (ncid) and write to output file (mcid)
            IF (debug) THEN
              write(6,*) 
              write(6,*) " OUTPUT FILE attributes:"
            ENDIF
            DO i = 1, ngatts
              rcode = nf_inq_attname(ncid, nf_global, i,    cname)
              rcode = nf_inq_atttype(ncid, nf_global, cname, itype)
              rcode = nf_inq_attlen (ncid, nf_global, cname, ilen)
  
	      IF ( itype .eq. 2 ) THEN        ! characters
	        rcode = nf_get_att_text (ncid, nf_global, cname, cval)
	        IF(cname(1:5) .eq. 'TITLE') THEN
                   cval = cval(1:ilen)//" - ON PRES LEVELS"
                   ilen = len_trim(cval)
                ENDIF
                IF (debug) write(6,'("     i = ",i2," : ",A," = ",A)') &
                                 i,cname,cval(1:ilen)
                DO ii = 1, num_output_files
	           rcode = nf_put_att_text(mcid_arr(ii), nf_global, cname, ilen,&
                             cval(1:ilen))
                ENDDO
  
	      ELSEIF ( itype .eq. 4 ) THEN     ! integers
	        rcode = nf_get_att_int (ncid, nf_global, cname, ival)
                IF ( INDEX(cname,'BOTTOM-TOP_PATCH') == 0 ) THEN
	           IF (cname .eq. 'BOTTOM-TOP_GRID_DIMENSION') ival = num_metgrid_levels
                   IF (debug) write(6,'("     i = ",i2," : ",A," = ",i7)') &
                                    i,cname,ival        
                   DO ii = 1, num_output_files
                      rcode = nf_put_att_int(mcid_arr(ii), nf_global, cname, itype,&
                                ilen, ival)
                 ENDDO
                 ENDIF
  
	      ELSEIF ( itype .eq. 5 ) THEN    ! real
	        rcode = nf_get_att_real (ncid, nf_global, cname, rval)
                IF (debug) write(6,'("     i = ",i2," : ",A," = ",G18.10E2)') &
                                 i,cname,rval
                DO ii = 1, num_output_files
	           rcode = nf_put_att_real(mcid_arr(ii), nf_global, cname, itype,&
                          ilen, rval)
                ENDDO
	      ENDIF
            ENDDO
! Output some additional global attributes for met_em file
            IF (met_em_output) THEN
               DO ii = 1, num_output_files
                  IF (i_sf_sfc_phys == 1 .OR. i_sf_sfc_phys == 2 .OR. i_sf_sfc_phys == 7) THEN
                     rcode = nf_put_att_int (mcid_arr(ii), nf_global, 'FLAG_SOIL_LAYERS', nf_int, 1, 1)
                  ENDIF
                  IF (i_sf_sfc_phys == 3) THEN
                     rcode = nf_put_att_int (mcid_arr(ii), nf_global, 'FLAG_SOIL_LEVELS', nf_int, 1, 1)
                  ENDIF
                  IF (i_sf_sfc_phys == 0) THEN
                     rcode = nf_put_att_int (mcid_arr(ii), nf_global, 'FLAG_SOIL_LEVELS', nf_int, 1, 0)
                     rcode = nf_put_att_int (mcid_arr(ii), nf_global, 'FLAG_SOIL_LAYERS', nf_int, 1, 0)
                  ENDIF
                  rcode = nf_put_att_int (mcid_arr(ii), nf_global, 'FLAG_SLP', nf_int, 1, 1)
                  rcode = nf_put_att_int (mcid_arr(ii), nf_global, 'FLAG_PSFC', nf_int, 1, 1)
                  rcode = nf_put_att_int (mcid_arr(ii), nf_global, 'FLAG_SOILHGT', nf_int, 1, 1)
                  rcode = nf_put_att_int (mcid_arr(ii), nf_global, 'FLAG_MF_XY', nf_int, 1, 1)
                  rcode = nf_put_att_int (mcid_arr(ii), nf_global, 'FLAG_METGRID', nf_int, 1, 1)
                  rcode = nf_put_att_int (mcid_arr(ii), nf_global, 'FLAG_P_INTERP', nf_int, 1, 1)
               ENDDO
            ENDIF

            DO ii = 1, num_output_files
               rcode = nf_enddef(mcid_arr(ii))  ! Take open netcdf file out of define mode
            ENDDO

!-----------------------------------------------------------------------
! Read in the Times character strings and convert to CF compliant times
!-----------------------------------------------------------------------
            IF (ALLOCATED(yyyymmddhh)) deallocate(yyyymmddhh)
   
            allocate (yyyymmddhh(times_in_input_file))
   
            IF (ALLOCATED(year)) deallocate(year)     ; allocate (year(times_in_input_file))
            IF (ALLOCATED(month)) deallocate(month)   ; allocate (month(times_in_input_file))
            IF (ALLOCATED(day)) deallocate(day)       ; allocate (day(times_in_input_file))
            IF (ALLOCATED(hour)) deallocate(hour)     ; allocate (hour(times_in_input_file))
            IF (ALLOCATED(minute)) deallocate(minute) ; allocate (minute(times_in_input_file))
            IF (ALLOCATED(second)) deallocate(second) ; allocate (second(times_in_input_file))
            IF (ALLOCATED(time)) deallocate(time)     ; allocate (time(times_in_input_file))
            IF (ALLOCATED(dtime)) deallocate(dtime)   ; allocate (dtime(times_in_input_file))
   
            DO i = 1, times_in_input_file
               read (Times_strings(i)(1:4),'(i4)') year(i)
               read (Times_strings(i)(6:7),'(i2)') month(i)
               read (Times_strings(i)(9:10),'(i2)') day(i)
               read (Times_strings(i)(12:13),'(i2)') hour(i)
               read (Times_strings(i)(15:16),'(i2)') minute(i)
               read (Times_strings(i)(18:19),'(i2)') second(i)
               yyyymmddhh(i) = wrf_times_to_ymdh   (year(i),month(i),day(i),hour(i))
               time(i)       = wrf_times_2Udunits_c(year(i),month(i),day(i),hour(i))
               dtime(i)=dble(time(i))
            ENDDO
!-----------------------------------------------------------------------
! Set attributes for the time info
!-----------------------------------------------------------------------
            DO i = 1, num_output_files
               IF ( .NOT. split_output ) THEN
                  istart = 1
                  iend = times_in_output_file   ! Put times in output file in array
               ELSE
                  istart = i      ! Put times in output files one at a time
                  iend = i 
               ENDIF

               CALL def_time_var (mcid_arr(i), times_in_output_file, cval="Time", long_name="Time",   &
                                  dtime=dtime(istart:iend), units="hours since 1997-01-01 00:00:00", &
                                  calendar="standard")
               CALL def_time_var (mcid_arr(i), times_in_output_file, time_data=yyyymmddhh(istart:iend), &
                                  cval="DateTime", long_name="Date and Time")
               CALL def_time_var (mcid_arr(i), times_in_output_file, time_data=year(istart:iend)  ,     &
                                  cval="year",  long_name="year")
               CALL def_time_var (mcid_arr(i), times_in_output_file, time_data=month(istart:iend) ,     &
                                  cval="month", long_name="month")
               CALL def_time_var (mcid_arr(i), times_in_output_file, time_data=day(istart:iend)   ,     &
                                  cval="day",   long_name="day")
               CALL def_time_var (mcid_arr(i), times_in_output_file, time_data=hour(istart:iend)  ,     &
                                  cval="hour",  long_name="hour")
               CALL def_time_var (mcid_arr(i), times_in_output_file, time_data=minute(istart:iend),     &
                                  cval="minute",long_name="minute")
               CALL def_time_var (mcid_arr(i), times_in_output_file, time_data=second(istart:iend),     &
                                  cval="second",long_name="second")
!-----------------------------------------------------------------------
!------ Done with time info --------------------------------------------
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
! Set attributes for the pressure info
!-----------------------------------------------------------------------
               rcode = nf_redef(mcid_arr(i))
               IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error opening define mode for pressure")
               rcode = nf_def_var(mcid_arr(i), "pressure", NF_FLOAT, 1, pdim, jvar)
               IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error defining variable for pressure")
               rcode = nf_put_att_text(mcid_arr(i), jvar, "long_name", 15, "Pressure Levels" )
               IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error putting pressure long_name text")
               rcode = nf_put_att_text(mcid_arr(i), jvar, "standard_name", 12, "air_pressure" )
               IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error putting pressure standard_name")
               rcode = nf_put_att_text(mcid_arr(i), jvar, "units", 3, "hPa" )
               IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error putting pressure units text")
               rcode = nf_put_att_text(mcid_arr(i), jvar, "positive", 4, "down" )
               IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error putting pressure positive text")
               rcode = nf_enddef(mcid_arr(i))            ! leave define mode
               IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error leaving pressure define mode")
               rcode = nf_put_vara_real(mcid_arr(i), jvar, 1, num_metgrid_levels, pressure)
               IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error putting dtime variable")
            ENDDO
!-----------------------------------------------------------------------
!------ Done with pressure info ----------------------------------------
!-----------------------------------------------------------------------

! WE NEED SOME BASIC FIELDS
            IF (ALLOCATED(data1)) deallocate(data1)
            allocate (data1(times_in_input_file,1,1,1))
            rcode = nf_inq_varid    ( ncid, "P_TOP", i )
            rcode = nf_get_var_real ( ncid, i, data1 )
            IF ( first ) THEN
               IF ( extrapolate == 1 .AND. &
                    (data1(1,1,1,1)-interp_levels(num_metgrid_levels)) > 0.0 ) THEN
                  write(6,*)
                  write(6,*) "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
                  write(6,*) " WARNING: Highest requested pressure level is above PTOP."
                  write(6,'(A,F7.2,A)') "           Use all pressure level data above", data1(1,1,1,1)*.01, " mb"
                  write(6,*) "          with caution."
                  write(6,*) "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
               ENDIF
               first = .FALSE.
            ENDIF
            deallocate (data1)
   
            IF (ALLOCATED(pres_field)) deallocate(pres_field)
            allocate (pres_field(iweg-1, isng-1, ibtg-1, times_in_input_file ))
            IF (ALLOCATED(data1)) deallocate(data1)
            allocate (data1(iweg-1, isng-1, ibtg-1, times_in_input_file ))
            rcode = nf_inq_varid    ( ncid, "P", i )
            rcode = nf_get_var_real ( ncid, i, pres_field )
            rcode = nf_inq_varid    ( ncid, "PB", i )
            rcode = nf_get_var_real ( ncid, i, data1 )
            pres_field = pres_field + data1
            deallocate (data1)

! JLS not alot of computational meat here to benefit parallelizing this
            IF (ALLOCATED(pres_stagU)) deallocate(pres_stagU)
            IF (ALLOCATED(pres_stagV)) deallocate(pres_stagV)
            allocate (pres_stagU(iweg, isng-1, ibtg-1, times_in_input_file ))
            allocate (pres_stagV(iweg-1, isng, ibtg-1, times_in_input_file ))
            pres_stagU(1,:,:,:)        =  pres_field(1,:,:,:)
            pres_stagU(iweg,:,:,:)     =  pres_field(iweg-1,:,:,:)
            pres_stagU(2:iweg-1,:,:,:) = (pres_field(1:iweg-2,:,:,:) +    &
                                          pres_field(2:iweg-1,:,:,:))*.5
            pres_stagV(:,1,:,:)        =  pres_field(:,1,:,:)
            pres_stagV(:,isng,:,:)     =  pres_field(:,isng-1,:,:)
            pres_stagV(:,2:isng-1,:,:) = (pres_field(:,1:isng-2,:,:) +    &
                                          pres_field(:,2:isng-1,:,:))*.5
   
            IF (ALLOCATED(psfc)) deallocate(psfc)
            allocate (psfc(iweg-1, isng-1, times_in_input_file ))
            IF (ALLOCATED(data1)) deallocate(data1)
            allocate (data1(iweg-1, isng-1, 1, times_in_input_file ))
            rcode = nf_inq_varid    ( ncid, "PSFC", i )
            rcode = nf_get_var_real ( ncid, i, data1 )
            psfc(:,:,:) = data1(:,:,1,:)
            deallocate (data1)
   
            IF (output_grid_mapping) THEN
   
               IF (ALLOCATED(XLAT)) deallocate(XLAT)
               allocate (XLAT(iweg-1, isng-1, times_in_input_file ))
               rcode = nf_inq_varid    ( ncid, "XLAT", i )
               rcode = nf_get_var_real ( ncid, i, XLAT )
!-----------------------------------------------------------------------
! If there is more than one time in a file, check that XLAT stays the same
!-----------------------------------------------------------------------
               IF (times_in_input_file .GT. 1) THEN
                  DO i = 2, times_in_input_file
                     IF ( XLAT(1,1,i) .NE. XLAT(1,1,i-1) ) THEN
                        write (6,*) 'There are different values of XLAT in file ',TRIM(input_file)
                        call handle_err (1, 'You may want to put each time in a separate file')
                     ENDIF
                  ENDDO
               ENDIF
               proj_origin_lat = XLAT(1,1,1)
               deallocate (XLAT)
   
               IF (ALLOCATED(XLONG)) deallocate(XLONG)
               allocate (XLONG(iweg-1, isng-1, times_in_input_file ))
               rcode = nf_inq_varid    ( ncid, "XLONG", i )
               rcode = nf_get_var_real ( ncid, i, XLONG )
!-----------------------------------------------------------------------
! If there is more than one time in a file, check that XLONG stays the same
!-----------------------------------------------------------------------
               IF (times_in_input_file .GT. 1) THEN
                  DO i = 2, times_in_input_file
                     IF ( XLONG(1,1,i) .NE. XLONG(1,1,i-1) ) THEN
                        write (6,*) 'There are different values of XLONG in file ',TRIM(input_file)
                        call handle_err (1, 'You may want to put each time in a separate file')
                     ENDIF
                  ENDDO
               ENDIF
               proj_origin_lon = XLONG(1,1,1)
               deallocate (XLONG)
   
               IF (map_proj .EQ. 1) THEN      ! Lambert conformal
                  DO i = 1, num_output_files
                     CALL def_map_proj_var (mcid = mcid_arr(i), map_proj = map_proj,    &
                                            std_parallel      = truelat,         &
                                            central_merid_lon = stand_lon,       &
                                            proj_origin_lat   = proj_origin_lat, &
                                            proj_origin_lon   = proj_origin_lon, &
                                            false_easting     = false_easting,   &
                                            false_northing    = false_northing   )
                  ENDDO
               ELSEIF (map_proj .eq. 2) THEN     ! Polar stereographic
                  DO i = 1, num_output_files
                     CALL def_map_proj_var (mcid = mcid_arr(i), map_proj = map_proj,      &
                                            std_parallel      = truelat,           &
                                            straight_vert_lon_from_pole=stand_lon, &
                                            proj_origin_lat   = proj_origin_lat,   &
                                            proj_origin_lon   = proj_origin_lon,   &
                                            false_easting     = false_easting,     &
                                            false_northing    = false_northing     )
                  ENDDO
               ELSEIF (map_proj .eq. 3) THEN     ! Mercator
                  DO i = 1, num_output_files
                     CALL def_map_proj_var (mcid = mcid_arr(i), map_proj = map_proj,    &
                                            std_parallel      = truelat,         &
                                            proj_origin_lat   = proj_origin_lat, &
                                            proj_origin_lon   = proj_origin_lon, &
                                            false_easting     = false_easting,   &
                                            false_northing    = false_northing   )
                  ENDDO
               ELSEIF (map_proj .eq. 6) THEN     ! lat-lon
                  write (6,*) "Havent done lat-lon yet ", map_proj
               ELSE
                  write (6,*) "Not sure what this map_proj is ", map_proj
                  write (6,*) "Not writing any grid_mapping information to output file"
               ENDIF
            ENDIF

            IF (ALLOCATED(pres_out)) deallocate(pres_out)
            allocate (pres_out(iweg-1, isng-1, num_metgrid_levels, times_in_input_file))
            DO i = 1, num_metgrid_levels
              pres_out (:,:,i,:) = interp_levels(i)
            ENDDO
            IF (ALLOCATED(ght)) deallocate(ght)
            allocate (ght(iweg-1, isng-1, ibtg-1, times_in_input_file ))
            IF (ALLOCATED(phb)) deallocate(phb)
            allocate (phb(iweg-1, isng-1, ibtg, times_in_input_file ))
            IF (ALLOCATED(data1)) deallocate(data1)
            allocate (data1(iweg-1, isng-1, ibtg, times_in_input_file ))
            rcode = nf_inq_varid    ( ncid, "PH", i )
            rcode = nf_get_var_real ( ncid, i, data1 )
            rcode = nf_inq_varid    ( ncid, "PHB", i )
            rcode = nf_get_var_real ( ncid, i, phb )
            data1 = (data1 + phb) 
            ght(:,:,1:ibtg-1,:) = ( data1(:,:,1:ibtg-1,:) + data1(:,:,2:ibtg,:) )*.5
            deallocate (data1)
            deallocate (phb)
   
            IF (ALLOCATED(ter)) deallocate(ter)
            allocate (ter(iweg-1, isng-1))
            IF (ALLOCATED(data1)) deallocate(data1)
            allocate (data1(iweg-1, isng-1, 1, times_in_input_file ))
            rcode = nf_inq_varid    ( ncid, "HGT", i )
            rcode = nf_get_var_real ( ncid, i, data1 )
            ter(:,:) = data1(:,:,1,1)
            IF (ALLOCATED(soilhgt)) deallocate(soilhgt)
            allocate (soilhgt(iweg-1, isng-1, times_in_input_file ))
            soilhgt=data1(:,:,1,:)
            deallocate (data1)

            IF (ALLOCATED(qv)) deallocate(qv)
            allocate (qv(iweg-1, isng-1, ibtg-1, times_in_input_file ))
            rcode = nf_inq_varid    ( ncid, "QVAPOR", i )
            rcode = nf_get_var_real ( ncid, i, qv )
   
   
            IF (ALLOCATED(tk)) deallocate(tk)
            allocate (tk(iweg-1, isng-1, ibtg-1, times_in_input_file ))
            IF (ALLOCATED(data1)) deallocate(data1)
            allocate (data1(iweg-1, isng-1, ibtg-1, times_in_input_file ))
            rcode = nf_inq_varid    ( ncid, "T", i )
            rcode = nf_get_var_real ( ncid, i, data1 )
            tk = (data1+300.) * ( pres_field / p0 )**RCP
            deallocate (data1)


            IF (ALLOCATED(rh)) deallocate(rh)
            allocate (rh(iweg-1, isng-1, ibtg-1, times_in_input_file ))
            IF (ALLOCATED(data1)) deallocate(data1)
            IF (ALLOCATED(data2)) deallocate(data2)
            allocate (data1(iweg-1, isng-1, ibtg-1, times_in_input_file ))
            allocate (data2(iweg-1, isng-1, ibtg-1, times_in_input_file ))
            data1 = 10.*0.6112*exp(17.67*(tk-273.16)/(TK-29.65))
            data2 = 0.622*data1/(0.01 * pres_field -  (1.-0.622)*data1)
            rh    = 100.*AMAX1(AMIN1(qv/data2,1.0),0.0)
            deallocate (data1)
            deallocate (data2)

            IF (met_em_output) THEN

! LANDUSEF may be in wrfinput files, if so, just read it in, if not, calculate it here
               rcode = nf_inq_varid    ( ncid, "LANDUSEF", i )

               IF (rcode .ne. nf_noerr) THEN
                  write (6,*) 'LANDUSEF is not in input file, calculating from IVGTYP'
                  IF (ALLOCATED(idata1)) deallocate(idata1)
                  allocate (idata1(iweg-1, isng-1, 1, times_in_input_file ))
                  rcode = nf_inq_varid    ( ncid, "IVGTYP", i )
                  IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error getting IVGTYP id from file")
                  rcode = nf_get_var_int ( ncid, i, idata1 )
                  IF (ALLOCATED(landusef)) deallocate(landusef)
                  allocate (landusef(iweg-1, isng-1, z_dim24, times_in_input_file ))

                  DO kk = 1,times_in_input_file
                     DO jj = 1,isng-1
                        DO ii = 1,iweg-1
                           landusef(ii, jj, :, kk) = 0.
                           landusef(ii, jj, idata1(ii, jj, 1, kk), kk) = 1.
                        ENDDO
                     ENDDO
                  ENDDO
                  deallocate (idata1)
               ENDIF

! SOILCTOP may be in wrfinput files, if so, just read it in, if not, calculate it here
               rcode = nf_inq_varid    ( ncid, "SOILCTOP", i )

               IF (rcode .ne. nf_noerr) THEN
                  write (6,*) 'SOILCTOP is not in input file, calculating from ISLTYP'

                  IF (ALLOCATED(idata2)) deallocate(idata2)
                  allocate (idata2(iweg-1, isng-1, 1, times_in_input_file ))
                  rcode = nf_inq_varid    ( ncid, "ISLTYP", i )
                  IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error getting ISLTYP id from file")
                  rcode = nf_get_var_int ( ncid, i, idata2 )
                  IF (ALLOCATED(soilctop)) deallocate(soilctop)
                  allocate (soilctop(iweg-1, isng-1, z_dim16, times_in_input_file ))
                  DO kk = 1,times_in_input_file
                     DO jj = 1,isng-1
                        DO ii = 1,iweg-1
                           soilctop(ii, jj, :, kk) = 0.
                           soilctop(ii, jj, idata2(ii, jj, 1, kk), kk) = 1.
                        ENDDO
                     ENDDO
                  ENDDO
                  deallocate (idata2)
               ENDIF

!----------------------------------------------------------------------------
! Set SOILHGT (in met_em file) is set to HGT (in wrfout file) below
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
! Convert soil layer thickness (dzs in wrfout) to soil layer depth (SOIL_LAYERS in met_em)
!----------------------------------------------------------------------------
               rcode = nf_inq_dimid(ncid, 'soil_layers_stag', dimid)
               IF (rcode .ne. nf_noerr) call handle_err (rcode, &
                       "Couldnt find dimension variable soil_layers_stag in input file")
               rcode = nf_inq_dimlen(ncid, dimid, n_soil_layers)
               IF (ALLOCATED(dzs)) deallocate(dzs)
               ALLOCATE (dzs(n_soil_layers, times_in_input_file ))
               IF (ALLOCATED(soil_layers)) deallocate(soil_layers)
               ALLOCATE (soil_layers(iweg-1, isng-1, n_soil_layers, times_in_input_file ))
               rcode = nf_inq_varid    ( ncid, "DZS", i )
               rcode = nf_get_var_real ( ncid, i, dzs )
               IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error getting DZS from file")
               DO kk = 1,times_in_input_file
                  accum_depth = 0.
                  DO jj = 1,n_soil_layers
                     accum_depth = accum_depth + dzs(jj,kk)*100.
                     soil_layers(:, :, n_soil_layers + 1- jj, kk) = accum_depth
                  ENDDO
               ENDDO
               deallocate (dzs)
!----------------------------------------------------------------------------
! Compute sea level pressure for each time in file
!----------------------------------------------------------------------------
               IF (ALLOCATED(geop_hgt)) deallocate(geop_hgt)
               ALLOCATE (geop_hgt(iweg-1, isng-1, ibtg-1, times_in_input_file ))
               geop_hgt = ght/9.81
               IF (ALLOCATED(sea_level_pressure)) deallocate(sea_level_pressure)
               ALLOCATE (sea_level_pressure(iweg-1, isng-1, times_in_input_file ))
               IF (ALLOCATED(t_sea_level)) deallocate(t_sea_level)
               ALLOCATE (t_sea_level(iweg-1, isng-1, times_in_input_file ))
               IF (ALLOCATED(t_surf)) deallocate(t_surf)
               ALLOCATE (t_surf(iweg-1, isng-1, times_in_input_file ))
               IF (ALLOCATED(level)) deallocate(level)
               ALLOCATE (level(iweg-1, isng-1, times_in_input_file ))

               DO jj = 1, times_in_input_file
                  CALL compute_seaprs (iweg-1, isng-1, ibtg-1, geop_hgt(:,:,:,jj), &
                                       tk(:,:,:,jj), pres_field(:,:,:,jj), qv(:,:,:,jj), &
                                       sea_level_pressure(:,:,jj), t_sea_level, t_surf, level)
               ENDDO
! not used
               DEALLOCATE(geop_hgt)
               DEALLOCATE(t_sea_level)
               DEALLOCATE(t_surf)
               DEALLOCATE(level)
            ENDIF   ! met_em_output

! TRAIN FILE 
           IF (debug) THEN
             write(6,*) 
             write(6,*) 
             write(6,*) "FILE variables:"
           ENDIF
         ENDIF   ! End master_task work

#ifdef _MPI
         call MPI_BCAST(iweg     , 1 , MPI_INTEGER, master_task, MPI_COMM_WORLD, ierr)
         call MPI_BCAST(isng     , 1 , MPI_INTEGER, master_task, MPI_COMM_WORLD, ierr)
         call MPI_BCAST(ibtg     , 1 , MPI_INTEGER, master_task, MPI_COMM_WORLD, ierr)
         call MPI_BCAST(j        , 1 , MPI_INTEGER, master_task, MPI_COMM_WORLD, ierr)
         call MPI_BCAST(ndims    , 1 , MPI_INTEGER, master_task, MPI_COMM_WORLD, ierr)
         call MPI_BCAST(nvars    , 1 , MPI_INTEGER, master_task, MPI_COMM_WORLD, ierr)
         call MPI_BCAST(extra_fields     ,1 , MPI_INTEGER, master_task, MPI_COMM_WORLD, ierr)
         call MPI_BCAST(nfields          ,1 , MPI_INTEGER, master_task, MPI_COMM_WORLD, ierr)
         call MPI_BCAST(n_diag_fields    ,1 , MPI_INTEGER, master_task, MPI_COMM_WORLD, ierr)
         call MPI_BCAST(dvalj(1:j)       ,j , MPI_INTEGER, master_task, MPI_COMM_WORLD, ierr)
         call MPI_BCAST(times_in_input_file,1,MPI_INTEGER, master_task, MPI_COMM_WORLD, ierr)
         call MPI_BCAST(dvali(1:ndims),ndims, MPI_INTEGER, master_task, MPI_COMM_WORLD, ierr)
         call MPI_BCAST(num_output_files ,1 , MPI_INTEGER, master_task, MPI_COMM_WORLD, ierr)

         IF (MPI_DEBUG) THEN
            PRINT *, "TASK #", my_task, " has iweg= ",iweg 
            PRINT *, "TASK #", my_task, " has isng= ",isng
            PRINT *, "TASK #", my_task, " has ibtg= ",ibtg
            PRINT *, "TASK #", my_task, " has j= ",j
            PRINT *, "TASK #", my_task, " has ndims= ",ndims
            PRINT *, "TASK #", my_task, " has dvali= ",dvali(1:ndims)
            PRINT *, "TASK #", my_task, " has dvalj= ",j,dvalj(1:j)
            PRINT *, "TASK #", my_task, " has times_in_input_file= ",times_in_input_file
            PRINT *, "TASK #", my_task, " has nvars= ",nvars
            PRINT *, "TASK #", my_task, " has extra_fields= ",extra_fields
            PRINT *, "TASK #", my_task, " has nfields= ",nfields
            PRINT *, "TASK #", my_task, " has n_diag_fields= ",n_diag_fields
            PRINT *, "TASK #", my_task, " has num_output_files= ",num_output_files
         ENDIF
#endif

        jvar = 0
!############################################################################
!   Loop through the variables
!############################################################################
        loop_variables : DO ivar = 1, nvars + extra_fields

          got_a_diagnostic = .false.
          got_a_met_em     = .false.
          IF (my_task == master_task) THEN
! For each ivar, read the variable.  ncid, ivar input, rest output.
             IF ( ivar <= nvars ) then   ! Variable counted in nvars, ivar known
                rcode = nf_inq_var(ncid, ivar, cval, itype, idm, ishape, natt)
                IF (rcode /= nf_noerr) THEN
                   long_string = "Couldnt find variable "//TRIM(cval)//" in 'process_these_fields'"
                   call handle_err(1, TRIM(long_string))
                ENDIF
             ELSE                        ! This is a diagnostic or met_em field
                DO jdiag = 1,nfields
                   IF (INDEX(process_these_fields,TRIM(var_name(jdiag))) /= 0) THEN
                      IF (.not.diag_processed(jdiag)) THEN
! This is a diagnostic field that hasn't been processed before
                         cval = TRIM(var_name(jdiag))
                         got_a_diagnostic = .true.
                         diag_processed(jdiag) = .true.
                         goto 300     ! Got a diagnostic, don't search the met_em fields
                      ENDIF
                   ENDIF
                ENDDO
                IF ( met_em_output ) THEN
                   DO jdiag = 1,icount
                      IF (INDEX(process_these_fields,TRIM(met_em_name(jdiag))) /= 0) THEN
                         IF (.not.met_em_processed(jdiag)) THEN
! This is a met_em field that hasn't been processed before
                            cval = TRIM(met_em_name(jdiag))
                            got_a_met_em = .true.
                            met_em_processed(jdiag) = .true.
                            exit
                         ENDIF
                      ENDIF
                   ENDDO
                ENDIF
 300            CONTINUE     ! Got a field, don't look further
                IF (got_a_diagnostic .OR. got_a_met_em) THEN    ! This is a diagnostic or met_em field
! Use QVAPOR to get itype, idm, ishape and natt to use for 4D diagnostics
                   rcode  = nf_inq_varid(ncid, "QVAPOR", id_var)
                   rcode = nf_inq_var(ncid, id_var, cval_not_used, itype, idm, ishape, natt)
! Use HGTto get itype, idm, ishape and natt to use for 3D diagnostics
                   IF ( TRIM(cval) == "SOILHGT" .OR. TRIM(cval) == "PMSL") THEN
                      rcode  = nf_inq_varid(ncid, "HGT", id_var)
                      rcode = nf_inq_var(ncid, id_var, cval_not_used, itype, idm, ishape, natt)
                   ENDIF
                ENDIF
             ENDIF ! diagnostic or met_em field
          ENDIF    ! master_task


#ifdef _MPI
          call MPI_BCAST(cval , cval_len, MPI_CHARACTER, master_task, MPI_COMM_WORLD, ierr)
          call MPI_BCAST(idm  ,        1, MPI_INTEGER,   master_task, MPI_COMM_WORLD, ierr)
          call MPI_BCAST(itype,        1, MPI_INTEGER,   master_task, MPI_COMM_WORLD, ierr)
          call MPI_BCAST(ishape,       6, MPI_INTEGER,   master_task, MPI_COMM_WORLD, ierr)
          call MPI_BCAST(got_a_diagnostic, 1, MPI_LOGICAL,   master_task, MPI_COMM_WORLD, ierr)
          call MPI_BCAST(got_a_met_em, 1, MPI_LOGICAL,   master_task, MPI_COMM_WORLD, ierr)
          IF (MPI_DEBUG) THEN
             PRINT *, "TASK #", my_task, " has cval= ",TRIM(cval)
             PRINT *, "TASK #", my_task, " has idm= ",idm
             PRINT *, "TASK #", my_task, " has itype= ",itype
             PRINT *, "TASK #", my_task, " has ishape= ",ishape
          ENDIF
#endif

          !!! Do we want this variable
          IF ( trim(cval) == 'P'    .OR. trim(cval) == 'PB'  ) CYCLE loop_variables
          IF ( trim(cval) == 'PH'   .OR. trim(cval) == 'PHB' ) CYCLE loop_variables
          IF ( trim(cval) == 'ZNU'  .OR. trim(cval) == 'ZNW' ) CYCLE loop_variables
          IF ( trim(cval) == 'FNM'  .OR. trim(cval) == 'FNP' ) CYCLE loop_variables
          IF ( trim(cval) == 'RDNW' .OR. trim(cval) == 'RDN' ) CYCLE loop_variables
          IF ( trim(cval) == 'DNW'  .OR. trim(cval) == 'DN'  ) CYCLE loop_variables
          IF ( trim(cval) == 'T' ) CYCLE loop_variables
          IF ( unstagger_grid .AND. (INDEX(cval,'_U') /= 0) ) CYCLE loop_variables !!! no sense in keeping these
          IF ( unstagger_grid .AND. (INDEX(cval,'_V') /= 0) ) CYCLE loop_variables !!! no sense in keeping these
          IF ( INDEX(process,'all') == 0 ) THEN
             !!! Only want some variables - see which
             dummy = ","//trim(cval)//","
             is_there = INDEX(process_these_fields,trim(dummy))
             IF ( is_there == 0 ) THEN
                IF ( debug ) print*,"NOTE: ", trim(cval), " - Not requested, task=",my_task
                CYCLE loop_variables !!! don't want this one
             ENDIF
          ENDIF

          IF ( idm >= 4 .AND. itype == 4 ) THEN
            print*,"NOTE: We cannot deal with 3D integers - maybe later"
            CYCLE loop_variables
          ENDIF
          IF ( itype == 6 ) THEN
            print*,"NOTE: We cannot deal with double precision data - maybe later"
            CYCLE loop_variables
          ENDIF
          IF ( itype == 2 .OR. itype == 4 .OR. itype == 5 ) THEN
            !!! OK I know what to do this this
          ELSE
            print*,"NOTE: Do not understand this data type ", itype, " skip field."
            CYCLE loop_variables
          ENDIF

! Rename some variables
          IF ( trim(cval) == 'U'   ) cval = 'UU'
          IF ( trim(cval) == 'V'   ) cval = 'VV'
          IF ( trim(cval) == 'TSK' ) cval = 'SKINTEMP'
          IF ( met_em_output ) THEN
             IF ( trim(cval) == 'XLAT'  ) cval = 'XLAT_M'
             IF ( trim(cval) == 'XLONG' ) cval = 'XLONG_M'
             IF ( trim(cval) == 'HGT'   ) cval = 'HGT_M'
             IF ( trim(cval) == 'TSLB'  ) cval = 'ST'
             IF ( trim(cval) == 'SMOIS' ) cval = 'SM'
             IF ( trim(cval) == 'SH2O'  ) cval = 'SW'
             IF ( trim(cval) == 'TMN'   ) cval = 'SOILTEMP'
          ENDIF

          !!! OK - we want this - lets continue
          jvar = jvar + 1
          jshape = 0

          interpolate = .FALSE.
          IF (got_a_diagnostic) THEN
              IF (TRIM(cval) == "PRES") THEN 
                interpolate = .false.
              ELSE
                interpolate = .true.
              ENDIF
          ENDIF

          fix_meta_stag = .FALSE.

          IF (my_task == master_task) THEN
             DO i = 1, num_output_files
                rcode = nf_redef(mcid_arr(i))
             ENDDO
          ENDIF

          DO ii = 1, idm
#ifdef _MPI
            call MPI_BCAST(dnamei(ishape(ii)), dname_length, MPI_CHARACTER, master_task, MPI_COMM_WORLD, ierr)
            if (debug) PRINT *, "TASK #", my_task, " has dnamei(ishape(ii))= ",TRIM(dnamei(ishape(ii)))
#endif
            IF ( got_a_diagnostic .or. got_a_met_em ) THEN
              IF ( ii == 1 ) test_dim_name = 'west_east'
              IF ( ii == 2 ) test_dim_name = 'south_north'
              IF ( ii == 3 ) test_dim_name = 'num_metgrid_levels'
              IF ( ii == 3 .and. trim(cval) == 'SOIL_LAYERS' ) test_dim_name = 'num_st_layers'
              IF ( ii == 3 .and. (TRIM(cval) == "SOILHGT" .OR. TRIM(cval) == "PMSL")) &
                             test_dim_name = 'Time'
              IF ( ii == 4 ) test_dim_name = 'Time'
            ELSE
               test_dim_name = dnamei(ishape(ii))
            ENDIF

            IF (met_em_output) THEN
               IF ( test_dim_name == 'soil_layers_stag') test_dim_name = 'num_st_layers'
               IF ( test_dim_name == 'land_cat_stag' .and. trim(cval) == 'LANDUSEF' ) test_dim_name = 'z-dimension0024'
               IF ( test_dim_name == 'soil_cat_stag' .and. trim(cval) == 'SOILCTOP' ) test_dim_name = 'z-dimension0016'
!              IF ( ii == 3 .and. trim(cval) == 'LANDUSEF' ) test_dim_name = 'z-dimension0024'
!              IF ( ii == 3 .and. trim(cval) == 'SOILCTOP' ) test_dim_name = 'z-dimension0016'
            ENDIF

            new_dim = 0
            IF ( test_dim_name == 'bottom_top' .OR. test_dim_name == 'bottom_top_stag' ) THEN
                 IF ( test_dim_name == 'bottom_top_stag' ) fix_meta_stag = .TRUE.
                 test_dim_name = 'num_metgrid_levels'
                 interpolate = .TRUE.
            ENDIF
            IF ( unstagger_grid .AND. test_dim_name == 'west_east_stag' )   THEN
               test_dim_name = 'west_east'
               fix_meta_stag = .TRUE.
               new_dim = dvali(ishape(ii)) - 1
            ENDIF
            IF ( unstagger_grid .AND. test_dim_name == 'south_north_stag' ) THEN
               test_dim_name = 'south_north'
               fix_meta_stag = .TRUE.
               new_dim = dvali(ishape(ii)) - 1
            ENDIF
            DO jj = 1,j
#ifdef _MPI
              call MPI_BCAST(dnamej(jj), dname_length, MPI_CHARACTER, master_task, MPI_COMM_WORLD, ierr)
              if (debug) PRINT *, "TASK #", my_task, " has dnamej(jj)= ",TRIM(dnamej(jj))
#endif
              IF ( test_dim_name == dnamej(jj) ) THEN
                jshape(ii) = jj
              ENDIF
            ENDDO

            IF ( jshape(ii) == 0 ) THEN
              j = j + 1
              jshape(ii) = j
              !!dnamej(j) = dnamei(ishape(ii))
              dnamej(j) = test_dim_name
              dvalj(j) = dvali(ishape(ii))
              IF (new_dim /= 0) dvalj(j) = new_dim
              IF (my_task == master_task) THEN
                 DO i = 1, num_output_files
                    rcode = nf_def_dim(mcid_arr(i), dnamej(j), dvalj(j), j)
                 ENDDO
              ENDIF
            ENDIF
            IF (test_dim_name .eq. 'Time') time_dim = ii
          ENDDO    ! idm loop

          IF (my_task == master_task) THEN
             DO i = 1, num_output_files
                rcode = nf_def_var(mcid_arr(i), cval, itype, idm, jshape, jvar)   ! jvar returned
             ENDDO
   
             DO na = 1, natt
                rcode = nf_inq_attname(ncid, ivar, na, cname)
                IF ( fix_meta_stag .AND. trim(cname) == 'stagger' ) THEN
                   att_text = "-"
                   ilen = len_trim(att_text)
                   DO i = 1, num_output_files
                      rcode = nf_put_att_text(mcid_arr(i), jvar, cname, ilen, att_text(1:ilen) )
                   ENDDO
                ELSEIF ( fix_meta_stag .AND. trim(cname) == 'coordinates' ) THEN
                   att_text = "XLONG XLAT"
                   ilen = len_trim(att_text)
                   DO i = 1, num_output_files
                      rcode = nf_put_att_text(mcid_arr(i), jvar, cname, ilen, att_text(1:ilen) )
                   ENDDO
                ELSE
                   DO i = 1, num_output_files
                      rcode = nf_copy_att(ncid, ivar, cname, mcid_arr(i), jvar)
                   ENDDO
                ENDIF
             ENDDO
   
             IF ( extrapolate == 0 .and. .not. got_a_diagnostic ) THEN
               DO i = 1, num_output_files
                  rcode = nf_put_att_real(mcid_arr(i), jvar, 'missing_value', NF_FLOAT, 1, MISSING )
               ENDDO
             ENDIF
   
             DO i = 1, num_output_files
                rcode = nf_enddef(mcid_arr(i))
             ENDDO
          ENDIF    ! my_task == master_task

! GET THE DIMS FOR INPUT AND OUTPUT FROM THE SHAPE
          dims_in  = 1
          dims_out = 1
          indx     = 1
          DO ii = 1,idm
            dims_in(ii)  = dvali(ishape(ii))
            dims_out(ii) = dvalj(jshape(ii))
          ENDDO

          IF (my_task == master_task) THEN
             IF (debug) THEN
               write(6,*) 'VAR: ',trim(cval)
               write(6,*) '     DIMS  IN: ',dims_in
               write(6,*) '     DIMS OUT: ',dims_out
             ENDIF
          ENDIF
! Set some indices for sample values, avoiding out of bounds problems
          isample_in=max(1,dims_in(1)/2)
          jsample_in=max(1,dims_in(2)/2)
          isample_out=max(1,dims_out(1)/2)
          jsample_out=max(1,dims_out(2)/2)
   
   ! ALLOCATE THE INPUT AND OUTPUT ARRAYS
   ! READ THE DATA FROM INPUT FILE
   
      	  IF     (itype == 2) THEN          ! character
             IF (my_task == master_task) THEN
                allocate (text(dims_in(1), dims_in(2), dims_in(3), dims_in(4)))
      	        rcode = nf_get_var_text(ncid, ivar, text)
                DO i = 1, num_output_files
                  IF ( .NOT. split_output ) THEN    ! Put whole array of times into output file
                     rcode = nf_put_vara_text (mcid_arr(i), jvar, start_dims, dims_in, text)
                  ELSE                             ! Put times in output files one at a time
                     DO ii = 1, idm
                        IF (ii .eq. time_dim ) THEN
                           dims_in(ii) = 1
                           indx(ii) = i
                        ENDIF
                     ENDDO
                     rcode = nf_put_vara_text (mcid_arr(i), jvar, start_dims, dims_in, &
                                               text(indx(1),indx(2),indx(3),indx(4)))
                  ENDIF
                ENDDO
                IF (debug) write(6,*) '     SAMPLE VALUE = ',text(:,1,1,1)
                deallocate (text)
             ENDIF
        
          ELSEIF (itype == 4) THEN          ! integer
             IF (my_task == master_task) THEN
                allocate (idata1(dims_in(1), dims_in(2), dims_in(3), dims_in(4)))
      	        rcode = nf_get_var_int(ncid, ivar, idata1)
                DO i = 1, num_output_files
                  IF ( .NOT. split_output ) THEN    ! Put whole array of times into output file
                     rcode = nf_put_vara_int (mcid_arr(i), jvar, start_dims, dims_in, idata1)
                  ELSE                             ! Put times in output files one at a time
                     DO ii = 1, idm
                        IF (ii .eq. time_dim ) THEN
                           dims_in(ii) = 1
                           indx(ii) = i
                        ENDIF
                     ENDDO
                  ENDIF
  	           rcode = nf_put_vara_int (mcid_arr(i), jvar, start_dims, dims_in, &
                                            idata1(indx(1),indx(2),indx(3),indx(4)))
                ENDDO
                IF (debug) write(6,*) '     SAMPLE VALUE = ',idata1(isample_in,jsample_in,1,1)
                deallocate (idata1)
             ENDIF
        
      	  ELSEIF (itype == 5) THEN          ! real
             IF (my_task == master_task) THEN
                allocate (data1(dims_in(1), dims_in(2), dims_in(3), dims_in(4)))
                allocate (data2(dims_out(1),dims_out(2),dims_out(3),dims_out(4)))
                IF ( got_a_diagnostic ) THEN
                   SELECT CASE(TRIM(cval))
                   CASE("PRES")
                      data2 = pres_out
                      jdiag = 1
                   CASE("TT")
                      data1 = tk    ! data1 fields need interpolating
                      jdiag = 2
                   CASE("GHT")
                      data1 = ght
                      jdiag = 3
                   CASE("RH")
                      data1 = rh
                      jdiag = 4
                   CASE DEFAULT
                      write (6,*) TRIM(cval),"is not a valid diagnostic variable"
                      call handle_err(1, "Add a new variable to var_name and code to calculate it")
                   END SELECT
                   DO i = 1, num_output_files
                      CALL def_var (mcid_arr(i), jvar, TRIM(cval), 5, 4, "XYZ", &
                                    var_desc(jdiag), var_unit(jdiag), "-", "XLONG XLAT")
                   ENDDO
                ELSEIF ( got_a_met_em ) THEN
                   if (ALLOCATED(data2)) DEALLOCATE(data2)
                   DO kk = 1, icount
                      IF (TRIM(cval) == TRIM(met_em_name(kk))) THEN
                         jdiag = kk
                         IF (TRIM(cval) == "LANDUSEF") THEN
                            allocate (data2(dims_out(1),dims_out(2),z_dim24,dims_out(4)))
                            data2 = landusef
                            dims_out(3) = z_dim24 
                         ELSEIF (TRIM(cval) == "SOILCTOP") THEN
                            allocate (data2(dims_out(1),dims_out(2),z_dim16,dims_out(4)))
                            data2 = soilctop
                            dims_out(3) = z_dim16
                         ELSEIF (TRIM(cval) == "SOIL_LAYERS") THEN
                            allocate (data2(dims_out(1),dims_out(2),n_soil_layers,dims_out(4)))
                            data2 = soil_layers
                            dims_out(3) = n_soil_layers
                         ELSEIF (TRIM(cval) == "SOILHGT") THEN
                            allocate (data2(dims_out(1),dims_out(2),1,dims_out(4)))
                            data2(:,:,1,:) = soilhgt(:,:,:) ! JLS g95 may want loops
                            dims_out(3) = 1
                         ELSEIF (TRIM(cval) == "PMSL") THEN
                            allocate (data2(dims_out(1),dims_out(2),1,dims_out(4)))
                            data2(:,:,1,:) = sea_level_pressure(:,:,:)
                            dims_out(3) = 1
                         ELSE
                            write (6,*) TRIM(cval),"is not a valid met_em variable"
                            call handle_err(1, "Add a new variable to met_em_name and code to calculate it")
                         ENDIF
                      ENDIF
                   ENDDO
                   DO i = 1, num_output_files
                      CALL def_var (mcid_arr(i), jvar, TRIM(cval), 5, 4, met_em_mem_order(jdiag), &
                                    met_em_desc(jdiag), met_em_unit(jdiag), "-", "XLONG XLAT")
                   ENDDO
                ELSE
!  READ IN THE REAL DATA
      	           rcode = nf_get_var_real(ncid, ivar, data1)

! Uncorrect TMN for terrain height
                   IF ( (met_em_output .AND. TRIM(cval) == "SOILTEMP") .OR. &    ! This is TMN, renamed to SOILTEMP
                                            (TRIM(cval) == "TMN") ) THEN
                      IF (DEBUG) write (6,*) 'Uncorrecting TMN for hgt'
                      data1(:,:,1,1) = data1(:,:,1,1) + 0.0065 * ter(:,:)
                   ENDIF

                   IF (met_em_output) THEN    ! After reading in SM, ST and SW, turn them upside down
                      IF ( TRIM(cval) == "SM" .OR. TRIM(cval) == "ST" .OR. TRIM(cval) == "SW" ) THEN

                         IF (ALLOCATED(invert_soil_info)) deallocate(invert_soil_info)
                         ALLOCATE (invert_soil_info(iweg-1, isng-1, n_soil_layers, times_in_input_file ))
                         invert_soil_info = data1    ! Make copy to avoid clobbering data

                         DO jj = 1,n_soil_layers
                             data1(:, :, n_soil_layers + 1 - jj, :) = &
                                     invert_soil_info(:, :, jj, :)
                         ENDDO
                         DEALLOCATE(invert_soil_info)
                      ENDIF    ! SM, ST or SW inverted
                   ENDIF       ! met_em_output
                ENDIF          ! not a met_em or diagnostic variable
             ENDIF             ! my_task == master_task
   
             IF (idm >= 4 .AND. interpolate) THEN  
    
                IF (my_task == master_task) THEN
                   IF (debug) write(6,*) '     THIS IS A FIELD WE NEED TO INTERPOLATE'       
!----------------------------------------------------------------------------
! Get the size of variable domain
! Create a universal pressure array
!----------------------------------------------------------------------------
                   IF (ALLOCATED(new_pressure)) DEALLOCATE(new_pressure) 
                   IF ( dims_in(1) == iweg .AND. .not. unstagger_grid ) THEN
                      ix = size(pres_stagU(:,1,1,1))
                      iy = size(pres_stagU(1,:,1,1))
                      iz = size(pres_stagU(1,1,:,1))
                      ALLOCATE (new_pressure(ix,iy,iz,dims_in(4)))
                      new_pressure = pres_stagU
                   ELSEIF ( dims_in(2) == isng .AND. .not. unstagger_grid ) THEN
                      ix = size(pres_stagV(:,1,1,1))
                      iy = size(pres_stagV(1,:,1,1))
                      iz = size(pres_stagV(1,1,:,1))
                      ALLOCATE (new_pressure(ix,iy,iz,dims_in(4)))
                      new_pressure = pres_stagV
                   ELSE
                      ix = size(pres_field(:,1,1,1))
                      iy = size(pres_field(1,:,1,1))
                      iz = size(pres_field(1,1,:,1))
                      ALLOCATE (new_pressure(ix,iy,iz,dims_in(4)))
                      new_pressure = pres_field
                   END IF         

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
                   IF (ALLOCATED(new_data1)) DEALLOCATE(new_data1) 
    
                   IF ( dims_in(1) == iweg .AND. unstagger_grid ) THEN
                      ALLOCATE (new_data1(iweg-1, isng-1, ibtg-1, dims_in(4)))
                      new_data1(1:iweg-1,:,:,:) = (data1(1:iweg-1,:,:,:) + &
                                                   data1(2:iweg,:,:,:)) * .5
                   ELSEIF ( dims_in(2) == isng .AND. unstagger_grid ) THEN
                      ALLOCATE (new_data1(iweg-1, isng-1, ibtg-1, dims_in(4)))
                      new_data1(:,1:isng-1,:,:) = (data1(:,1:isng-1,:,:) + &
                                                   data1(:,2:isng,:,:)) * .5
                   ELSEIF ( dims_in(3) == ibtg ) THEN
                      ALLOCATE (new_data1(iweg-1, isng-1, ibtg-1, dims_in(4)))
                      new_data1(:,:,1:ibtg-1,:) = (data1(:,:,1:ibtg-1,:) + &
                                                   data1(:,:,2:ibtg,:)) * .5
                   ELSE
                      ALLOCATE (new_data1(dims_in(1), dims_in(2), dims_in(3), dims_in(4)))
                      new_data1 = data1
                   END IF         
!----------------------------------------------------------------------------
! Lets parallelize along y for now, most efficient to decompose by column
!----------------------------------------------------------------------------
                   sn_chunksize = iy/numtasks      ! Min number of cols per processor
                   sn_extra = mod(iy,numtasks)     ! Extra rows
                   sn_col_end = sn_chunksize

!----------------------------------------------------------------------------
! Distribute data to all tasks (only copy to master_task, send to others)
!----------------------------------------------------------------------------
#ifdef _MPI
                   distribute : DO dest=1, numtasks-1
                      IF (dest .le. sn_extra) THEN     ! If this workers ID is <= extra rows
                         sn_cols = sn_chunksize + 1    ! This worker gets an extra row
                      ELSE
                         sn_cols = sn_chunksize        ! otherwise, workers get the min number
                      ENDIF
                      sn_col_start = sn_col_end + 1
                      sn_col_end = sn_col_start + sn_cols - 1
                      if (MPI_DEBUG) write (6,*) 'TASK # ',my_task,'updating sn_col_start to ',sn_col_start
                      if (MPI_DEBUG) write (6,*) 'TASK # ',my_task,'updating sn_col_end to ',sn_col_end
                      if (MPI_DEBUG) write (6,*) 'TASK # ',my_task,'updating sn_cols to ',sn_cols

! Make a copy of part of the data to send to worker task
                      IF (ALLOCATED(new_data_buff)) DEALLOCATE(new_data_buff) 
                      ALLOCATE(new_data_buff(ix,sn_cols,iz,dims_in(4)))
                      new_data_buff(:,:,:,:) = new_data1(:,sn_col_start:sn_col_end,:,:)
                      if (MPI_DEBUG) write (6,*) 'Max new_data_buff = ',maxval(new_data_buff), &
                                                 'Min new_data_buff = ',minval(new_data_buff)

                      IF (ALLOCATED(new_pressure_buff)) DEALLOCATE(new_pressure_buff) 
                      ALLOCATE(new_pressure_buff(ix,sn_cols,iz,dims_in(4)))
                      new_pressure_buff(:,:,:,:) = new_pressure(:,sn_col_start:sn_col_end,:,:)
                      if (MPI_DEBUG) write (6,*) 'Max new_pressure_buff = ',maxval(new_pressure_buff), &
                                                 'Min new_pressure_buff = ',minval(new_pressure_buff)

! sn_cols calculation is based on iy, which may be on the staggered grid, psfc, ... are on the mass points
                      if (sn_col_end .gt. isng-1) then
                         iend = isng-1
                         mass_cols = sn_cols-1
                      else
                         iend = sn_col_end
                         mass_cols = sn_cols
                      endif

                      IF (ALLOCATED(psfc_buff)) DEALLOCATE(psfc_buff) 
                      ALLOCATE(psfc_buff(iweg-1,mass_cols,times_in_input_file))
                      psfc_buff(1:iweg-1,1:mass_cols,:) = psfc(1:iweg-1,sn_col_start:iend,:)
                      if (MPI_DEBUG) write (6,*) 'Alloc Max psfc_buff = ',maxval(psfc_buff), &
                                                 'Min psfc_buff = ',minval(psfc_buff), mass_cols

                      IF (ALLOCATED(ter_buff)) DEALLOCATE(ter_buff) 
                      ALLOCATE(ter_buff(iweg-1,mass_cols))
                      ter_buff(1:iweg-1,1:mass_cols) = ter(1:iweg-1,sn_col_start:iend)
                      if (MPI_DEBUG) write (6,*) 'Alloc Max ter_buff = ',maxval(ter_buff), &
                                                 'Min ter_buff = ',minval(ter_buff), mass_cols

                      IF (ALLOCATED(tk_buff)) DEALLOCATE(tk_buff) 
                      ALLOCATE(tk_buff(iweg-1,mass_cols,ibtg-1,times_in_input_file))
                      tk_buff(1:iweg-1,1:mass_cols,:,:) = tk(1:iweg-1,sn_col_start:iend,:,:)
                      if (MPI_DEBUG) write (6,*) 'Alloc Max tk_buff = ',maxval(tk_buff(:,:,:,:)), &
                                                 'Min tk_buff = ',minval(tk_buff(:,:,:,:)), mass_cols

                      IF (ALLOCATED(qv_buff)) DEALLOCATE(qv_buff) 
                      ALLOCATE(qv_buff(iweg-1,mass_cols,ibtg-1,times_in_input_file))
                      qv_buff(1:iweg-1,1:mass_cols,:,:) = qv(1:iweg-1,sn_col_start:iend,:,:)
                      if (MPI_DEBUG) write (6,*) 'Alloc Max qv_buff = ',maxval(qv_buff), &
                                                 'Min qv_buff = ',minval(qv_buff), mass_cols

                      int_buffer(1)  = sn_cols
                      int_buffer(2)  = sn_col_start
                      int_buffer(3)  = sn_col_end
                      int_buffer(4)  = ix
                      int_buffer(5)  = iz
                      int_buffer(6)  = dims_in(4)
                      int_buffer(7)  = ix*sn_cols*iz*dims_in(4)
                      int_buffer(8)  = ix*sn_cols*dims_in(4)
                      int_buffer(9)  = ix*sn_cols
                      int_buffer(10) = (iweg-1)*mass_cols*(ibtg-1)*times_in_input_file
                      int_buffer(11) = (iweg-1)*mass_cols*times_in_input_file
                      int_buffer(12) = (iweg-1)*mass_cols

! Send the integers to the workers
                      call MPI_SEND(int_buffer, int_buff_size, MPI_INTEGER, dest, &
                                    from_master, MPI_COMM_WORLD, ierr )

                      if (MPI_DEBUG) THEN
                         write(6,*) 'Sending',int_buffer(1), ' sn_cols to task'       ,dest
                         write(6,*) 'Sending',int_buffer(2), ' sn_col_start to task'  ,dest
                         write(6,*) 'Sending',int_buffer(3), ' sn_col_end to task'    ,dest
                         write(6,*) 'Sending',int_buffer(4), ' ix to task'            ,dest
                         write(6,*) 'Sending',int_buffer(5), ' iz to task'            ,dest
                         write(6,*) 'Sending',int_buffer(6), ' dims_in(4) to task'    ,dest
                         write(6,*) 'Sending',int_buffer(7), ' xyzt_arraysize to task',dest
                         write(6,*) 'Sending',int_buffer(8), ' xyt_arraysize to task ',dest
                         write(6,*) 'Sending',int_buffer(9), ' xy_arraysize to task  ',dest
                         write(6,*) 'Sending',int_buffer(10),' xyzt_masssize to task ',dest
                         write(6,*) 'Sending',int_buffer(11),' xyt_masssize to task  ',dest
                         write(6,*) 'Sending',int_buffer(12),' xy_masssize to task   ',dest
                      ENDIF

! Send the real arrays to the workers
                      call MPI_SEND(new_data_buff, int_buffer(7), MPI_REAL, dest, from_master,MPI_COMM_WORLD, ierr )
                      if (MPI_DEBUG) write(6,*) 'Sent new_data_buff to task',dest,int_buffer(7)
                      call MPI_SEND(new_pressure_buff, int_buffer(7), MPI_REAL, dest, from_master,MPI_COMM_WORLD, ierr )
                      if (MPI_DEBUG) write(6,*) 'Sent new_pressure_buff to task',dest,int_buffer(7)
                      call MPI_SEND(psfc_buff, int_buffer(11), MPI_REAL, dest, from_master,MPI_COMM_WORLD, ierr )
                      if (MPI_DEBUG) write(6,*) 'Sent psfc_buff to task',dest,int_buffer(11)
                      call MPI_SEND(ter_buff, int_buffer(12), MPI_REAL, dest, from_master,MPI_COMM_WORLD, ierr )
                      if (MPI_DEBUG) write(6,*) 'Sent ter_buff to task',dest,int_buffer(12)
                      call MPI_SEND(tk_buff, int_buffer(10), MPI_REAL, dest, from_master,MPI_COMM_WORLD, ierr )
                      if (MPI_DEBUG) write(6,*) 'Sent tk_buff to task',dest,int_buffer(10)
                      call MPI_SEND(qv_buff, int_buffer(10), MPI_REAL, dest, from_master,MPI_COMM_WORLD, ierr )
                      if (MPI_DEBUG) write(6,*) 'Sent qv_buff to task',dest,int_buffer(10)
                   ENDDO distribute
#endif
!-----------------------------------------------
! Copy the first chunk to master task
!-----------------------------------------------
                   sn_cols = sn_chunksize 
                   if (MPI_DEBUG) write (6,*) 'TASK # ',my_task,'COPY to master_task',sn_chunksize

                   IF (ALLOCATED(new_data_buff)) DEALLOCATE(new_data_buff) 
                   ALLOCATE(new_data_buff(ix,sn_chunksize,iz,dims_in(4)))
                   new_data_buff(:,:,:,:) = new_data1(:,1:sn_chunksize,:,:)
                   if (MPI_DEBUG) write (6,*) 'Max new_data_buff = ',maxval(new_data_buff), &
                                              'Min new_data_buff = ',minval(new_data_buff)

                   IF (ALLOCATED(new_pressure_buff)) DEALLOCATE(new_pressure_buff) 
                   ALLOCATE(new_pressure_buff(ix,sn_chunksize,iz,dims_in(4)))
                   new_pressure_buff(:,:,:,:) = new_pressure(:,1:sn_chunksize,:,:)
                   if (MPI_DEBUG) write (6,*) 'Max new_pressure_buff = ',maxval(new_pressure_buff), &
                                              'Min new_pressure_buff = ',minval(new_pressure_buff)

! sn_cols calculation is based on iy, which may be on the staggered grid, psfc, ... are on the mass points
                   if (sn_chunksize .gt. isng-1) then
                      mass_cols = sn_chunksize-1
                   else
                      mass_cols = sn_chunksize
                   endif

                   IF (ALLOCATED(psfc_buff)) DEALLOCATE(psfc_buff) 
                   ALLOCATE(psfc_buff(iweg-1,mass_cols,times_in_input_file))
                   psfc_buff(1:iweg-1,:,:) = psfc(1:iweg-1,1:mass_cols,:)
                   if (MPI_DEBUG) write (6,*) 'Alloc Max psfc_buff = ',maxval(psfc_buff), &
                                              'Min psfc_buff = ',minval(psfc_buff), mass_cols

                   IF (ALLOCATED(ter_buff)) DEALLOCATE(ter_buff) 
                   ALLOCATE(ter_buff(iweg-1,mass_cols))
                   ter_buff(1:iweg-1,:) = ter(1:iweg-1,1:mass_cols)
                   if (MPI_DEBUG) write (6,*) 'Alloc Max ter_buff = ',maxval(ter_buff), &
                                              'Min ter_buff = ',minval(ter_buff), mass_cols

                   IF (ALLOCATED(tk_buff)) DEALLOCATE(tk_buff) 
                   ALLOCATE(tk_buff(iweg-1,mass_cols,ibtg-1,times_in_input_file))
                   tk_buff(1:iweg-1,:,:,:) = tk(1:iweg-1,1:mass_cols,:,:)
                   if (MPI_DEBUG) write (6,*) 'Alloc Max tk_buff = ',maxval(tk_buff(:,:,:,:)), &
                                              'Min tk_buff = ',minval(tk_buff(:,:,:,:)), mass_cols

                   IF (ALLOCATED(qv_buff)) DEALLOCATE(qv_buff) 
                   ALLOCATE(qv_buff(iweg-1,mass_cols,ibtg-1,times_in_input_file))
                   qv_buff(1:iweg-1,:,:,:) = qv(1:iweg-1,1:mass_cols,:,:)
                   if (MPI_DEBUG) write (6,*) 'Alloc Max qv_buff = ',maxval(qv_buff), &
                                                 'Min qv_buff = ',minval(qv_buff),mass_cols

                   int_buffer(7)  = ix*sn_cols*iz*dims_in(4)                 ! xyzt_arraysize
                   int_buffer(8)  = ix*sn_cols*dims_in(4)                    ! xyt_arraysize
                   int_buffer(9)  = ix*sn_cols                               ! xy_arraysize
                   int_buffer(10) = (iweg-1)*mass_cols*(ibtg-1)*times_in_input_file  ! xyzt_masssize
                   int_buffer(11) = (iweg-1)*mass_cols*times_in_input_file           ! xyt_masssize
                   int_buffer(12) = (iweg-1)*mass_cols                         ! xy_masssize
!----------------------------------------------------------------------------
! Receive results from worker tasks
!----------------------------------------------------------------------------
#ifdef _MPI
                   receive : DO i = 1, numtasks-1
                      call MPI_RECV(sn_size,      1, MPI_INTEGER, i, from_worker, &
                                    MPI_COMM_WORLD, status, ierr )
                      call MPI_RECV(sn_col_start, 1, MPI_INTEGER, i, from_worker, &
                                    MPI_COMM_WORLD, status, ierr )
                      call MPI_RECV(sn_col_end,   1, MPI_INTEGER, i, from_worker, &
                                    MPI_COMM_WORLD, status, ierr )
                      call MPI_RECV(xyzt_dimsout,   1, MPI_INTEGER, i, from_worker, &
                                    MPI_COMM_WORLD, status, ierr )
                      if (ALLOCATED(data2_from_worker)) DEALLOCATE(data2_from_worker)
                      allocate (data2_from_worker(dims_out(1),sn_size,dims_out(3),dims_out(4)))
                      call MPI_RECV(data2_from_worker, xyzt_dimsout, &
                                    MPI_REAL, i, from_worker, MPI_COMM_WORLD, status, ierr )
! Each process puts their chunk into data2
                      data2(:,sn_col_start:sn_col_end,:,:) = data2_from_worker(:,1:sn_size,:,:)
                      if (MPI_DEBUG)  write (6,*) 'Master RECV Max/min data2',sn_col_start,sn_col_end,sn_size, &
                                      maxval(data2(:,sn_col_start:sn_col_end,:,:)), &
                                      minval(data2(:,sn_col_start:sn_col_end,:,:))
                   ENDDO receive 
#endif

                ENDIF   ! master_task

                IF (my_task > master_task ) THEN
!----------------------------------------------------------------------------
! Receive array data from master_task
!----------------------------------------------------------------------------
#ifdef _MPI
! Reveive integers from master task
                   call MPI_RECV(int_buffer, int_buff_size, MPI_INTEGER, master_task, from_master, &
                                 MPI_COMM_WORLD, status, ierr )
                   if (MPI_DEBUG) THEN
                      write(6,*) 'Received',int_buffer(1), ' sn_cols from task'       ,dest
                      write(6,*) 'Received',int_buffer(2), ' sn_col_start from task'  ,dest
                      write(6,*) 'Received',int_buffer(3), ' sn_col_end from task'    ,dest
                      write(6,*) 'Received',int_buffer(4), ' ix from task'            ,dest
                      write(6,*) 'Received',int_buffer(5), ' iz from task'            ,dest
                      write(6,*) 'Received',int_buffer(6), ' dims_in(4) from task'    ,dest
                      write(6,*) 'Received',int_buffer(7), ' xyzt_arraysize from task',dest
                      write(6,*) 'Received',int_buffer(8), ' xyt_arraysize from task ',dest
                      write(6,*) 'Received',int_buffer(9), ' xy_arraysize from task  ',dest
                      write(6,*) 'Received',int_buffer(10),' xyzt_masssize from task ',dest
                      write(6,*) 'Received',int_buffer(11),' xyt_masssize from task  ',dest
                      write(6,*) 'Received',int_buffer(12),' xy_masssize from task   ',dest
                   ENDIF
                   sn_cols        = int_buffer(1)
                   sn_col_start   = int_buffer(2)
                   sn_col_end     = int_buffer(3)
                   ix             = int_buffer(4)
                   iz             = int_buffer(5)
                   dims_in(4)     = int_buffer(6)
                   xyzt_arraysize = int_buffer(7)
                   xyt_arraysize  = int_buffer(8)
                   xy_arraysize   = int_buffer(9)
                   xyzt_masssize  = int_buffer(10)
                   xyt_masssize   = int_buffer(11)
                   xy_masssize    = int_buffer(12)
#endif
                   IF (ALLOCATED(new_data_buff)) DEALLOCATE(new_data_buff) 
                   ALLOCATE(new_data_buff(ix,sn_cols,iz,dims_in(4)))

                   IF (ALLOCATED(new_pressure_buff)) DEALLOCATE(new_pressure_buff) 
                   ALLOCATE(new_pressure_buff(ix,sn_cols,iz,dims_in(4)))

                   IF (ALLOCATED(psfc_buff)) DEALLOCATE(psfc_buff) 
                   ALLOCATE(psfc_buff(iweg-1,sn_cols,times_in_input_file))

                   IF (ALLOCATED(ter_buff)) DEALLOCATE(ter_buff) 
                   ALLOCATE(ter_buff(iweg-1,sn_cols))

                   IF (ALLOCATED(tk_buff)) DEALLOCATE(tk_buff) 
                   ALLOCATE(tk_buff(iweg-1,sn_cols,ibtg-1,times_in_input_file))

                   IF (ALLOCATED(qv_buff)) DEALLOCATE(qv_buff) 
                   ALLOCATE(qv_buff(iweg-1,sn_cols,ibtg-1,times_in_input_file))

#ifdef _MPI
! Receive real arrays from master task
                   call MPI_RECV(new_data_buff,    xyzt_arraysize, &
                                 MPI_REAL, master_task,from_master, MPI_COMM_WORLD, status, ierr )
                   if (MPI_DEBUG) write (6,*) 'Recv Max new_data_buff = ',maxval(new_data_buff), &
                                              'Recv Min new_data_buff = ',minval(new_data_buff),xyzt_arraysize

                   call MPI_RECV(new_pressure_buff, xyzt_arraysize, &
                                 MPI_REAL, master_task,from_master, MPI_COMM_WORLD, status, ierr )
                   if (MPI_DEBUG) write (6,*) 'Recv Max new_pressure_buff = ',maxval(new_pressure_buff), &
                                              'Recv Min new_pressure_buff = ',minval(new_pressure_buff),xyzt_arraysize
                   call MPI_RECV(psfc_buff,         xyt_masssize, &
                                 MPI_REAL, master_task,from_master, MPI_COMM_WORLD, status, ierr )
                   if (MPI_DEBUG) write (6,*) 'Recv Max psfc_buff = ',maxval(psfc_buff), &
                                              'Recv Min psfc_buff = ',minval(psfc_buff),xyt_masssize
                   call MPI_RECV(ter_buff,          xy_masssize, &
                                 MPI_REAL, master_task,from_master, MPI_COMM_WORLD, status, ierr )
                   if (MPI_DEBUG) write (6,*) 'Recv Max ter_buff = ',maxval(ter_buff), &
                                              'Recv Min ter_buff = ',minval(ter_buff),xy_masssize
                   call MPI_RECV(tk_buff,           xyzt_masssize, &
                                 MPI_REAL, master_task,from_master, MPI_COMM_WORLD, status, ierr )
                   if (MPI_DEBUG) write (6,*) 'Recv Max tk_buff = ',maxval(tk_buff), &
                                              'Recv Min tk_buff = ',minval(tk_buff),xyzt_masssize
                   call MPI_RECV(qv_buff,           xyzt_masssize, &
                                 MPI_REAL, master_task,from_master, MPI_COMM_WORLD, status, ierr )
                   if (MPI_DEBUG) write (6,*) 'Recv Max qv_buff = ',maxval(qv_buff), &
                                              'Recv Min qv_buff = ',minval(qv_buff),xyzt_masssize
#else
                   new_data_buff     = new_data1
                   new_pressure_buff = new_pressure
                   psfc_buff         = psfc
                   ter_buff          = ter
                   tk_buff           = tk
                   qv_buff           = qv
#endif
                END IF     ! worker tasks
!----------------------------------------------------------------------------
! All tasks do the work
!----------------------------------------------------------------------------
                if (ALLOCATED(data2_to_master)) DEALLOCATE(data2_to_master)
                allocate (data2_to_master(dims_out(1),sn_cols,dims_out(3),dims_out(4)))
                if (MPI_DEBUG) write (6,*) &
                      'Max new_data_buff = ',maxval(new_data_buff), &
                      'Min new_data_buff = ',minval(new_data_buff)
                CALL interp (data2_to_master, new_data_buff, new_pressure_buff,    &
                             interp_levels, psfc_buff,      &
                             ter_buff, tk_buff, qv_buff,  &
                             ix, sn_cols, iz, dims_in(4),       &
                             num_metgrid_levels, LINLOG,        &
                             extrapolate, .FALSE., MISSING)
!----------------------------------------------------------------------------
! Each task calculates their diagnostics 
!----------------------------------------------------------------------------
                IF (TRIM(cval) .EQ. 'GHT') data2_to_master = data2_to_master/9.81
                IF (TRIM(cval) .EQ. 'RH' ) THEN
                   WHERE ( data2_to_master < 0.0 ) 
                      data2_to_master = 0.0
                   ENDWHERE
                   WHERE ( data2_to_master > 100.0 )
                      data2_to_master = 100.0
                   ENDWHERE
                ENDIF
                if (MPI_DEBUG) write (6,*) &
                       'Max data2_to_master = ',maxval(data2_to_master), &
                       'Min data2_to_master = ',minval(data2_to_master)
!----------------------------------------------------------------------------
!     Send results back to master task
!----------------------------------------------------------------------------
                IF (my_task == master_task) THEN
                   data2(:,1:sn_chunksize,:,:) = data2_to_master(:,1:sn_chunksize,:,:)
                   if (MPI_DEBUG)  write (6,*) 'COPY Max/min data2_to_master',sn_chunksize, &
                                   maxval(data2(:,1:sn_chunksize,:,:)), &
                                   minval(data2(:,1:sn_chunksize,:,:))
                ELSE
#ifdef _MPI
                   call MPI_SEND(sn_cols,     1, MPI_INTEGER, master_task, from_worker, MPI_COMM_WORLD, ierr )
                   call MPI_SEND(sn_col_start,1, MPI_INTEGER, master_task, from_worker, MPI_COMM_WORLD, ierr )
                   call MPI_SEND(sn_col_end,  1, MPI_INTEGER, master_task, from_worker, MPI_COMM_WORLD, ierr )
                   xyzt_dimsout = dims_out(1)*sn_cols*dims_out(3)*dims_out(4)
                   call MPI_SEND(xyzt_dimsout,1, MPI_INTEGER, master_task, from_worker, MPI_COMM_WORLD, ierr )
                   if (MPI_DEBUG) write (6,*) 'Sending back to master Max data2_to_master = ',maxval(data2_to_master), &
                                      'Min data2_to_master = ',minval(data2_to_master), sn_cols,sn_col_start,sn_col_end
                   call MPI_SEND( data2_to_master, xyzt_dimsout, MPI_REAL, master_task, &
                                  from_worker, MPI_COMM_WORLD, ierr )
#endif
                END IF     ! worker tasks

                IF (my_task == master_task) THEN
                   IF (debug) write(6,*) '     SAMPLE VALUE IN  = ',data1(isample_in,jsample_in,1,1)
                   IF (debug) write(6,*) '     SAMPLE VALUE OUT = ',data2(isample_out,jsample_out,1,1)
                ENDIF

             ELSEIF (idm == 3 .AND. unstagger_grid ) THEN  
                IF (my_task == master_task) THEN
                   IF ( dims_in(1) == iweg ) THEN
                      data2(1:iweg-1,:,:,:) = (data1(1:iweg-1,:,:,:) + data1(2:iweg,:,:,:)) * .5
                   ELSEIF ( dims_in(2) == isng ) THEN
                      data2(:,1:isng-1,:,:) = (data1(:,1:isng-1,:,:) + data1(:,2:isng,:,:)) * .5
                   ELSE
	              data2 = data1
                   ENDIF
                   IF (debug) write(6,*) '     SAMPLE VALUE  = ',data1(isample_in,jsample_in,1,1)
                ENDIF
	     ELSE
                IF (my_task == master_task) THEN
! For PRES field and met_em fields, output array is already set to data2 (the input array is the output array) 
                   IF ( TRIM(cval) /= "PRES" .AND. .NOT. got_a_met_em ) THEN
	              data2 = data1
                      IF (debug) write(6,*) '     SAMPLE VALUE  = ',data1(isample_in,jsample_in,1,1)
                   ENDIF
                ENDIF
	     ENDIF          ! idm conditionals
            
            IF (my_task == master_task) THEN
               if (allocated(data1)) deallocate (data1)
                   if (MPI_DEBUG) write (6,*) 'Writing Max data2 = ',maxval(data2), &
                                              'Writing Min data2 = ',minval(data2)
               DO i = 1, num_output_files
                  IF ( .NOT. split_output ) THEN    ! Put whole array of times into output file
                     rcode = nf_put_vara_real (mcid_arr(i), jvar, start_dims, dims_out, data2)
                  ELSE                             ! Put times in output files one at a time
                     DO ii = 1, idm
                        IF (ii .eq. time_dim ) THEN
                           dims_out(ii) = 1
                           indx(ii) = i
                        ENDIF
                     ENDDO
                     write (6,*) 'JLS ',TRIM(cval), ' going to file ',mcid_arr(i)
                     write (6,*) 'JLS start_dims',start_dims
                     write (6,*) 'JLS dims_out',dims_out
                     write (6,*) 'JLS indx(3)',indx(3)
                     write (6,*) 'JLS indx(4)',indx(4)
                     rcode = nf_put_vara_real (mcid_arr(i), jvar, start_dims, dims_out, &
                                               data2(indx(1),indx(2),indx(3),indx(4)))
                  ENDIF
               ENDDO
               if (allocated(data2)) deallocate (data2)
	    ENDIF
  
          ENDIF    ! itype conditionals
  
        ENDDO loop_variables

        IF (my_task == master_task) THEN

!!! Close files after each time if met_em or splitting output
           IF ( met_em_output .OR. split_output ) THEN
              rcode = nf_close(ncid)
              DO i = 1, num_output_files
                 rcode = nf_close(mcid_arr(i))
              ENDDO
           ENDIF
           write(6,*) 
        ENDIF   ! master_task

      ENDDO   ! End loop over files
  
      IF (my_task == master_task) THEN
!!! Close files on exit
         rcode = nf_close(ncid)
         DO i = 1, num_output_files
            rcode = nf_close(mcid_arr(i))
         ENDDO
         CALL cpu_time(time_end)
         write (6,'(a50,f10.5,a8)') 'Total time = ',time_end - time_start,' seconds'
      ENDIF

      write(6,*) 
      write(6,*) "##############################################################"
      write(6,*) " SUCCESS: We are out of here, for task ",my_task     
      write(6,*) "##############################################################"

#ifdef _MPI
    call MPI_FINALIZE(ierr)
#endif

 END PROGRAM p_interp
!---------------------------------------------------------------------
!---------------------------------------------------------------------
!---------------------------------------------------------------------
 SUBROUTINE handle_err(rcode, msg)
     IMPLICIT NONE
      INCLUDE 'netcdf.inc'
#ifdef _MPI
      INCLUDE 'mpif.h'
#endif
    INTEGER      , INTENT(IN) :: rcode
    CHARACTER (*), INTENT(IN) :: msg
    INTEGER                   :: ierr

    write (6,*) TRIM(msg), '  Error number = ', rcode
    write (6,*) NF_STRERROR(rcode)
#ifdef _MPI
    call MPI_ABORT(MPI_COMM_WORLD,1,ierr)
#endif
    STOP
 END SUBROUTINE handle_err
!---------------------------------------------------------------------
 SUBROUTINE interp (data_out, data_in, pres_field, interp_levels, psfc, ter, tk, qv, ix, iy, iz, it, &
                     num_metgrid_levels, LINLOG, extrapolate, GEOPT, MISSING)

     INTEGER                                          :: ix, iy, iz, it
     INTEGER                                          :: num_metgrid_levels, LINLOG
     REAL, DIMENSION(ix, iy, num_metgrid_levels, it)  :: data_out
     REAL, DIMENSION(ix, iy, iz, it)                  :: data_in, pres_field, tk, qv
     REAL, DIMENSION(ix, iy, it)                      :: psfc
     REAL, DIMENSION(ix, iy)                          :: ter
     REAL, DIMENSION(num_metgrid_levels)              :: interp_levels

     INTEGER                                          :: i, j, itt, k, kk, kin
     REAL, DIMENSION(num_metgrid_levels)              :: data_out1D
     REAL, DIMENSION(iz)                              :: data_in1D, pres_field1D
     INTEGER                                          :: extrapolate
     REAL                                             :: MISSING
     REAL, DIMENSION(ix, iy, num_metgrid_levels, it)  :: N
     REAL                                             :: sumA, sumN, AVE_geopt
     LOGICAL                                          :: GEOPT

     N = 1.0

     expon=287.04*.0065/9.81


     do itt = 1, it
        do j = 1, iy
        do i = 1, ix
           data_in1D(:)    = data_in(i,j,:,itt)
           pres_field1D(:) = pres_field(i,j,:,itt)
           CALL int1D (data_out1D, data_in1D, pres_field1D, interp_levels, iz, num_metgrid_levels, LINLOG, MISSING)
           data_out(i,j,:,itt) = data_out1D(:)
        END DO
        END DO
     END DO

     ! Fill in missing values
     IF ( extrapolate == 0 ) RETURN       !! no extrapolation - we are out of here

     ! First find where about 400 hPa is located
     kk = 0
     find_kk : do k = 1, num_metgrid_levels
        kk = k
        IF ( interp_levels(k) <= 40000. ) exit find_kk
     END DO find_kk

     
     IF ( GEOPT ) THEN     !! geopt is treated different below ground

        do itt = 1, it
           do k = 1, kk
              do j = 1, iy
              do i = 1, ix
                 IF ( data_out(i,j,k,itt) == MISSING .AND. interp_levels(k) < psfc(i,j,itt) ) THEN

!                We are below the first model level, but above the ground 

                    data_out(i,j,k,itt) = ((interp_levels(k) - pres_field(i,j,1,itt))*ter(i,j)*9.81 +  &
                                           (psfc(i,j,itt) - interp_levels(k))*data_in(i,j,1,itt) ) /   &
                                          (psfc(i,j,itt) - pres_field(i,j,1,itt))

                 ELSEIF ( data_out(i,j,k,itt) == MISSING ) THEN

!                We are below both the ground and the lowest data level.

!                First, find the model level that is closest to a "target" pressure
!                level, where the "target" pressure is delta-p less that the local
!                value of a horizontally smoothed surface pressure field.  We use
!                delta-p = 150 hPa here. A standard lapse rate temperature profile
!                passing through the temperature at this model level will be used
!                to define the temperature profile below ground.  This is similar
!                to the Benjamin and Miller (1990) method, except that for
!                simplicity, they used 700 hPa everywhere for the "target" pressure.
!                Code similar to what is implemented in RIP4

                    ptarget = (psfc(i,j,itt)*.01) - 150.
                    dpmin=1.e4
                    kupper = 0
                    loop_kIN : do kin=iz,1,-1
                       kupper = kin
                       dp=abs( (pres_field(i,j,kin,itt)*.01) - ptarget )
                       IF (dp.gt.dpmin) exit loop_kIN
                       dpmin=min(dpmin,dp)
                    ENDDO loop_kIN

                    pbot=max(pres_field(i,j,1,itt),psfc(i,j,itt))
                    zbot=min(data_in(i,j,1,itt)/9.81,ter(i,j))

                    tbotextrap=tk(i,j,kupper,itt)*(pbot/pres_field(i,j,kupper,itt))**expon
                    tvbotextrap=virtual(tbotextrap,qv(i,j,1,itt))

                    data_out(i,j,k,itt) = (zbot+tvbotextrap/.0065*(1.-(interp_levels(k)/pbot)**expon))*9.81
               
                 ENDIF
              ENDDO
              ENDDO
           ENDDO
        ENDDO


        !!! Code for filling missing data with an average - we don't want to do this
        !!do itt = 1, it
           !!loop_levels : do k = 1, num_metgrid_levels
              !!sumA = SUM(data_out(:,:,k,itt), MASK = data_out(:,:,k,itt) /= MISSING)
              !!sumN = SUM(N(:,:,k,itt), MASK = data_out(:,:,k,itt) /= MISSING)
              !!IF ( sumN == 0. ) CYCLE loop_levels
              !!AVE_geopt = sumA/sumN
              !!WHERE ( data_out(:,:,k,itt) == MISSING )
                 !!data_out(:,:,k,itt) = AVE_geopt
              !!END WHERE
           !!END DO loop_levels
        !!END DO

     END IF
     
     !!! All other fields and geopt at higher levels come here
     do itt = 1, it
        do j = 1, iy
        do i = 1, ix
          do k = 1, kk
             IF ( data_out(i,j,k,itt) == MISSING ) data_out(i,j,k,itt) = data_in(i,j,1,itt)
          END DO
          do k = kk+1, num_metgrid_levels
             IF ( data_out(i,j,k,itt) == MISSING ) data_out(i,j,k,itt) = data_in(i,j,iz,itt)
          END DO
        END DO
        END DO
     END DO

 END SUBROUTINE interp 
!------------------------------------------------------------------------------
!--------------------------------------------------------
 SUBROUTINE int1D(xxout, xxin, ppin, ppout, npin, npout, LINLOG, MISSING)

! Modified from int2p - NCL code
! routine to interpolate from one set of pressure levels
! .   to another set  using linear or ln(p) interpolation
!
! NCL: xout = int2p (pin,xin,pout,linlog)
! This code was originally written for a specific purpose.
! .   Several features were added for incorporation into NCL's
! .   function suite including linear extrapolation.
!
! nomenclature:
!
! .   ppin   - input pressure levels. The pin can be
! .            be in ascending or descending order
! .   xxin   - data at corresponding input pressure levels
! .   npin   - number of input pressure levels >= 2
! .   ppout  - output pressure levels (input by user)
! .            same (ascending or descending) order as pin
! .   xxout  - data at corresponding output pressure levels
! .   npout  - number of output pressure levels
! .   linlog - if abs(linlog)=1 use linear interp in pressure
! .            if abs(linlog)=2 linear interp in ln(pressure)
! .   missing- missing data code. 

!                                                ! input types
      INTEGER   :: npin,npout,linlog,ier
      real      :: ppin(npin),xxin(npin),ppout(npout)
      real      :: MISSING       
     logical                                          :: AVERAGE
!                                                ! output
      real      :: xxout(npout)
      INTEGER   :: j1,np,nl,nin,nlmax,nplvl
      INTEGER   :: nlsave,np1,no1,n1,n2,nlstrt
      real      :: slope,pa,pb,pc

! automatic arrays
      real      :: pin(npin),xin(npin),p(npin),x(npin)
      real      :: pout(npout),xout(npout)


      xxout = MISSING
      pout  = ppout
      p     = ppin
      x     = xxin
      nlmax = npin

! exact p-level matches
      nlstrt = 1
      nlsave = 1
      do np = 1,npout
          xout(np) = MISSING
          do nl = nlstrt,nlmax
              if (pout(np).eq.p(nl)) then
                  xout(np) = x(nl)
                  nlsave = nl + 1
                  go to 10
              end if
          END DO
   10     nlstrt = nlsave
      END DO

      if (LINLOG.eq.1) then
          do np = 1,npout
              do nl = 1,nlmax - 1
                  if (pout(np).lt.p(nl) .and. pout(np).gt.p(nl+1)) then
                      slope = (x(nl)-x(nl+1))/ (p(nl)-p(nl+1))
                      xout(np) = x(nl+1) + slope* (pout(np)-p(nl+1))
                  end if
              END DO
          END DO
      elseif (LINLOG.eq.2) then
          do np = 1,npout
              do nl = 1,nlmax - 1
                  if (pout(np).lt.p(nl) .and. pout(np).gt.p(nl+1)) then
                      pa = log(p(nl))
                      pb = log(pout(np))
! special case: in case someone inadvertently enter p=0.
                      if (p(nl+1).gt.0.d0) then
                          pc = log(p(nl+1))
                      else
                          pc = log(1.d-4)
                      end if

                      slope = (x(nl)-x(nl+1))/ (pa-pc)
                      xout(np) = x(nl+1) + slope* (pb-pc)
                  end if
              END DO
          END DO
      end if


! place results in the return array;
      xxout = xout

 END SUBROUTINE int1D

!------------------------------------------------------------------------------
 FUNCTION virtual (tmp,rmix)
!      This function returns virtual temperature in K, given temperature
!      in K and mixing ratio in kg/kg.

     real                              :: tmp, rmix, virtual

     virtual=tmp*(0.622+rmix)/(0.622*(1.+rmix))

 END FUNCTION virtual

!------------------------------------------------------------------------------
 SUBROUTINE all_spaces ( command , length_of_char ) 

      IMPLICIT NONE

      INTEGER                                       :: length_of_char
      CHARACTER (LEN=length_of_char)                :: command
      INTEGER                                       :: loop

      DO loop = 1 , length_of_char
         command(loop:loop) = ' '
      END DO

 END SUBROUTINE all_spaces

!------------------------------------------------------------------------------
 SUBROUTINE def_var (mcid, jvar, cval, itype, idm, order, desc, units, stag, coord )

      IMPLICIT NONE

      INCLUDE 'netcdf.inc'

      INTEGER              :: mcid, jvar
      CHARACTER (LEN =  4) :: cval
      INTEGER              :: itype, idm
      CHARACTER (LEN =  3) :: order
      CHARACTER (LEN = 50) :: desc
      CHARACTER (LEN = 20) :: units
      CHARACTER (LEN =  1) :: stag
      CHARACTER (LEN = 10) :: coord

      INTEGER            :: rcode, ilen
      CHARACTER (LEN=50) :: att_text


      IF ( itype == 5 ) THEN
         rcode = nf_redef(mcid)
         rcode = nf_put_att_int(mcid, jvar, "FieldType", NF_INT, 1, 104)
      ENDIF

      att_text = order
      ilen = len_trim(att_text)
      rcode = nf_put_att_text(mcid, jvar, "MemoryOrder", ilen, att_text(1:ilen) )

      att_text = desc
      ilen = len_trim(att_text)
      rcode = nf_put_att_text(mcid, jvar, "description", ilen, att_text(1:ilen) )

      att_text = units
      ilen = len_trim(att_text)
      rcode = nf_put_att_text(mcid, jvar, "units", ilen, att_text(1:ilen) )

      att_text = stag
      ilen = len_trim(att_text)
      rcode = nf_put_att_text(mcid, jvar, "stagger", ilen, att_text(1:ilen) )

      att_text = coord
      ilen = len_trim(att_text)
      rcode = nf_put_att_text(mcid, jvar, "coordinates", ilen, att_text(1:ilen) )

      rcode = nf_enddef(mcid)

 END SUBROUTINE def_var
!------------------------------------------------------------------------------
 SUBROUTINE def_map_proj_var (mcid, map_proj,                     &
                              std_parallel,    central_merid_lon, &
                              straight_vert_lon_from_pole,        &
                              proj_origin_lat, proj_origin_lon,   &
                              false_easting,   false_northing     )

! Provide mapping information to the netCDF file

      IMPLICIT NONE

      INCLUDE 'netcdf.inc'

      INTEGER, INTENT(IN)           :: mcid          ! file id
      INTEGER, INTENT(IN)           :: map_proj      ! map_proj from global atts
      REAL   , INTENT(IN), OPTIONAL :: std_parallel(2)
      REAL   , INTENT(IN), OPTIONAL :: central_merid_lon
      REAL   , INTENT(IN), OPTIONAL :: straight_vert_lon_from_pole
      REAL   , INTENT(IN), OPTIONAL :: proj_origin_lat
      REAL   , INTENT(IN), OPTIONAL :: proj_origin_lon
      REAL   , INTENT(IN), OPTIONAL :: false_easting
      REAL   , INTENT(IN), OPTIONAL :: false_northing

  ! local
      INTEGER             :: rcode, ilen 
      INTEGER             :: jvar            ! Returned variable id
      CHARACTER (LEN=100) :: att_text
      CHARACTER (LEN=100) :: cvar            ! variable short name
      CHARACTER (LEN=100) :: map_name        ! map short name

      IF (map_proj .EQ. 1) THEN
         map_name = "lambert_conformal_conic"
         cvar     = "Lambert_Conformal"
      ELSEIF (map_proj .EQ. 2) THEN
         map_name = "polar_stereographic"
         cvar     = "Polar_Stereographic"
      ELSEIF (map_proj .EQ. 3) THEN
         map_name = "mercator"
         cvar     = "Mercator"
      ELSE
         write (6,*) 'Option ',map_proj, 'is not a valid option for map_proj'
      ENDIF

      rcode = nf_redef(mcid)
      IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error opening define mode for map_proj")
      rcode = nf_def_var(mcid, trim(cvar), NF_INT, 0, 0, jvar)
      IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error defining variable for map_proj")

      att_text = map_name
      ilen = len_trim(att_text)
      rcode = nf_put_att_text(mcid, jvar, "grid_mapping_name", ilen, att_text(1:ilen) )
      IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error putting grid_mapping_name text")

      IF (PRESENT(std_parallel)) THEN
         IF (map_proj .EQ. 1) THEN     ! Write out truelat1 and truelat2
            rcode = nf_put_att_real(mcid, jvar, "standard_parallel", NF_REAL, 2, std_parallel )
         ELSE                          ! Write out truelat1
            rcode = nf_put_att_real(mcid, jvar, "standard_parallel", NF_REAL, 1, std_parallel(1) )
         ENDIF
         IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error putting standard_parallel real")
      ENDIF

      IF (PRESENT(central_merid_lon)) THEN
         rcode = nf_put_att_real(mcid, jvar, "longitude_of_central_meridian", NF_REAL, 1, central_merid_lon )
         IF (rcode .ne. nf_noerr) call handle_err(rcode, &
                                  "Error putting longitude_of_central_meridian real")
      ENDIF

      IF (PRESENT(straight_vert_lon_from_pole)) THEN
         rcode = nf_put_att_real(mcid, jvar, "straight_vertical_longitude_from_pole", &
                                 NF_REAL, 1, straight_vert_lon_from_pole )
         IF (rcode .ne. nf_noerr) call handle_err(rcode, &
                                  "Error putting straight_vertical_longitude_from_pole real")
      ENDIF

      IF (PRESENT(proj_origin_lat)) THEN
         rcode = nf_put_att_real(mcid, jvar, "latitude_of_projection_origin", NF_REAL, 1, proj_origin_lat )
         IF (rcode .ne. nf_noerr) call handle_err(rcode, &
                                  "Error putting latitude_of_projection_origin real")
      ENDIF

      IF (PRESENT(proj_origin_lon)) THEN
         rcode = nf_put_att_real(mcid, jvar, "longitude_of_projection_origin", NF_REAL, 1, proj_origin_lon )
         IF (rcode .ne. nf_noerr) call handle_err(rcode, &
                                  "Error putting longitude_of_projection_origin real")
      ENDIF

      IF (PRESENT(false_easting)) THEN
         rcode = nf_put_att_real(mcid, jvar, "false_easting", NF_REAL, 1, false_easting )
         IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error putting false_easting real")
      ENDIF

      IF (PRESENT(false_northing)) THEN
         rcode = nf_put_att_real(mcid, jvar, "false_northing", NF_REAL, 1, false_northing )
         IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error putting false_northing real")
      ENDIF

      rcode = nf_enddef(mcid)            ! leave define mode
      IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error leaving map_proj define mode")

 END SUBROUTINE def_map_proj_var
!------------------------------------------------------------------------------
 SUBROUTINE def_time_var (mcid, times_in_file, cval, long_name, &
                          time_data, dtime, units, calendar)

! Provide time data and attribute information to the netCDF file

      IMPLICIT NONE

      INCLUDE 'netcdf.inc'

      INTEGER     , INTENT(IN)           :: mcid            ! file id
      INTEGER     , INTENT(IN)           :: times_in_file   ! number of times in a file
      CHARACTER(*), INTENT(IN)           :: cval            ! variable short name
      CHARACTER(*), INTENT(IN)           :: long_name
      INTEGER,          DIMENSION(times_in_file) , INTENT(IN), OPTIONAL &
                                         :: time_data       ! generic integer time
      DOUBLE PRECISION, DIMENSION(times_in_file) , INTENT(IN), OPTIONAL &
                                         :: dtime           ! double precision time (coordinate var)
      CHARACTER(*), INTENT(IN), OPTIONAL :: units
      CHARACTER(*), INTENT(IN), OPTIONAL :: calendar

  ! local
      INTEGER             :: jvar            ! Returned variable id
      INTEGER             :: rcode, ilen, timdim
      CHARACTER (LEN=100) :: att_text

      rcode = nf_redef(mcid)
      IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error opening define mode for time")
      rcode = nf_inq_unlimdim(mcid, timdim)
      IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error inquiring unlimited dimension for time")

      IF (PRESENT(time_data)) THEN
         rcode = nf_def_var(mcid, trim(cval), NF_INT, 1, timdim, jvar)
         IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error defining variable for time")
      ELSEIF (PRESENT(dtime)) THEN
         rcode = nf_def_var(mcid, trim(cval), NF_DOUBLE, 1, timdim, jvar)
         IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error defining variable for time")
      ELSE
         write (6,*) 'def_time_var: You must pass either time_data or dtime'
         call handle_err (1, 'def_time_var: into SUBROUTINE def_time_var')
      END IF

      att_text = long_name
      ilen = len_trim(att_text)
      rcode = nf_put_att_text(mcid, jvar, "long_name", ilen, att_text(1:ilen) )
      IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error putting time long_name text")

      IF (PRESENT(units)) THEN
         att_text = units
         ilen = len_trim(att_text)
         rcode = nf_put_att_text(mcid, jvar, "units", ilen, att_text(1:ilen) )
         IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error putting time units text")
      END IF

      IF (PRESENT(calendar)) THEN
         att_text = calendar
         ilen = len_trim(att_text)
         rcode = nf_put_att_text(mcid, jvar, "calendar", ilen, att_text(1:ilen) )
         IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error putting time calendar text")
      END IF

      rcode = nf_enddef(mcid)            ! leave define mode
      IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error leaving time define mode")

! While we're at it, put the data in the file

      IF (PRESENT(dtime)) THEN
         rcode = nf_put_vara_double(mcid, jvar, 1, times_in_file, dtime)
         IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error putting dtime variable")
      END IF
      IF (PRESENT(time_data)) THEN
         rcode = nf_put_vara_int(mcid, jvar, 1, times_in_file, time_data)
         IF (rcode .ne. nf_noerr) call handle_err(rcode, "Error putting time variable")
      END IF

 END SUBROUTINE def_time_var

!------------------------------------------------------------------------------
! This subroutine has been taken from wrf_user_fortran_util_0.f
! index order if (i,j,k)
! WRF staggering
! Intent in:
!         INTEGER nx, ny, nz
!         REAL z(nx,ny,nz) - geopotential height (m)
!         REAL t(nx,ny,nz) - temperature (K)
!         REAL p(nx,ny,nz) - pressure (Pa) 
!         REAL q(nx,ny,nz) - mixing ratio (kg/kg)
! Intent out:
!         REAL    sea_level_pressure(nx,ny) - sea level pressure (Pa)
!         REAL    t_sea_level(nx,ny)        - sea level temperature (K)
!         REAL    t_surf(nx,ny)             - surface temperature (K)
!         INTEGER level(nx,ny)              - zeta level that is PCONST above surface ( k level)
!------------------------------------------------------------------------------
      SUBROUTINE compute_seaprs ( nx , ny , nz  ,     &
                                  z,                  &
                                  t , p , q ,         &
                                  sea_level_pressure, &
                                  t_sea_level, t_surf, level ) 
      IMPLICIT NONE
!     Estimate sea level pressure.
      INTEGER nx , ny , nz
      REAL    z(nx,ny,nz)
      REAL    t(nx,ny,nz) , p(nx,ny,nz) , q(nx,ny,nz)
!     The output is the 2d sea level pressure.
      REAL    sea_level_pressure(nx,ny)
      INTEGER level(nx,ny)
      REAL t_surf(nx,ny) , t_sea_level(nx,ny)
!     Some required physical constants:

      REAL R, G, GAMMA
      PARAMETER (R=287.04, G=9.81, GAMMA=0.0065)

!     Specific constants for assumptions made in this routine:

      REAL    TC, PCONST
      PARAMETER (TC=273.16+17.5, PCONST = 10000)
      LOGICAL ridiculous_mm5_test
      PARAMETER (ridiculous_mm5_test = .TRUE.)
!      PARAMETER (ridiculous_mm5_test = .false.)

!     Local variables:

      INTEGER i , j , k 
      INTEGER klo , khi 


      REAL plo , phi , tlo, thi , zlo , zhi
      REAL p_at_pconst , t_at_pconst , z_at_pconst
      REAL z_half_lowest

      LOGICAL  l1 , l2 , l3, found

!     Find least zeta level that is PCONST Pa above the surface.  We later use this
!     level to extrapolate a surface pressure and temperature, which is supposed
!     to reduce the effect of the diurnal heating cycle in the pressure field.

      DO j = 1 , ny
         DO i = 1 , nx
            level(i,j) = -1

            k = 1
            found = .false.
            do while( (.not. found) .and. (k.le.nz))
               IF ( p(i,j,k) .LT. p(i,j,1)-PCONST ) THEN
                  level(i,j) = k
                  found = .true.
               END IF
               k = k+1
            END DO 

            IF ( level(i,j) .EQ. -1 ) THEN
            PRINT '(A,I4,A)'     , 'Troubles finding level ', NINT(PCONST)/100,' above ground.'
            PRINT '(A,I4,A,I4,A)', 'Problems first occur at (',i,',',j,')'
            PRINT '(A,F6.1,A)'   , 'Surface pressure = ',p(i,j,1)/100,' hPa.'
            STOP 'Error_in_finding_100_hPa_up'
         END IF


         END DO
      END DO

!     Get temperature PCONST Pa above surface.  Use this to extrapolate 
!     the temperature at the surface and down to sea level.

      DO j = 1 , ny
         DO i = 1 , nx

            klo = MAX ( level(i,j) - 1 , 1      )
            khi = MIN ( klo + 1        , nz - 1 )
     
            IF ( klo .EQ. khi ) THEN
               PRINT '(A)','Trapping levels are weird.'
               PRINT '(A,I3,A,I3,A)','klo = ',klo,', khi = ',khi, &
                            ': and they should not be equal.'
               STOP 'Error_trapping_levels'
            END IF

         plo = p(i,j,klo)
         phi = p(i,j,khi)
         tlo = t(i,j,klo) * (1. + 0.608 * q(i,j,klo) )
         thi = t(i,j,khi) * (1. + 0.608 * q(i,j,khi) )
!         zlo = zetahalf(klo)/ztop*(ztop-terrain(i,j))+terrain(i,j)
!         zhi = zetahalf(khi)/ztop*(ztop-terrain(i,j))+terrain(i,j)
         zlo = z(i,j,klo)         
         zhi = z(i,j,khi)

         p_at_pconst = p(i,j,1) - pconst
         t_at_pconst = thi-(thi-tlo)*LOG(p_at_pconst/phi)*LOG(plo/phi)
         z_at_pconst = zhi-(zhi-zlo)*LOG(p_at_pconst/phi)*LOG(plo/phi)

         t_surf(i,j) = t_at_pconst*(p(i,j,1)/p_at_pconst)**(gamma*R/g)
         t_sea_level(i,j) = t_at_pconst+gamma*z_at_pconst

         END DO
      END DO

!     If we follow a traditional computation, there is a correction to the sea level 
!     temperature if both the surface and sea level temnperatures are *too* hot.

      IF ( ridiculous_mm5_test ) THEN
         DO j = 1 , ny
            DO i = 1 , nx
               l1 = t_sea_level(i,j) .LT. TC 
               l2 = t_surf     (i,j) .LE. TC
               l3 = .NOT. l1
               IF ( l2 .AND. l3 ) THEN
                  t_sea_level(i,j) = TC
               ELSE
                  t_sea_level(i,j) = TC - 0.005*(t_surf(i,j)-TC)**2
               END IF
            END DO
         END DO
      END IF

!     The grand finale: ta da!

      DO j = 1 , ny
      DO i = 1 , nx
!         z_half_lowest=zetahalf(1)/ztop*(ztop-terrain(i,j))+terrain(i,j)
         z_half_lowest=z(i,j,1)
         sea_level_pressure(i,j) = p(i,j,1) * EXP((2.*g*z_half_lowest)/ &
                                   (R*(t_sea_level(i,j)+t_surf(i,j))))
      END DO
      END DO

!     print *,'sea pres input at weird location i=20,j=1,k=1'
!     print *,'t=',t(20,1,1),t(20,2,1),t(20,3,1)
!     print *,'z=',z(20,1,1),z(20,2,1),z(20,3,1)
!     print *,'p=',p(20,1,1),p(20,2,1),p(20,3,1)
!     print *,'slp=',sea_level_pressure(20,1),
!    *         sea_level_pressure(20,2),sea_level_pressure(20,3)
   
      END SUBROUTINE compute_seaprs

!------------------------------------------------------------------------------
 INTEGER FUNCTION wrf_times_2Udunits_c(yr,mo,dy,hr)

     implicit none
     INTEGER :: nmo, hrs_per_yr
     INTEGER :: yr, mo, dy, hr
     INTEGER :: yy ,mm, dd, hh
     INTEGER :: sumoff
     PARAMETER (nmo=12)
     PARAMETER (hrs_per_yr=365*24)
     INTEGER :: ndy(nmo)
 
     ndy(:)=[31,28,31,30,31,30,31,31,30,31,30,31]
 
     IF ((mod(yr,4) .eq. 0) .and. (mo .eq. 2)) ndy(2)=29
     sumoff=0

     DO yy=1997,yr-1
       sumoff=sumoff+hrs_per_yr
       IF (mod(yy,4) .eq. 0) sumoff=sumoff+24
     ENDDO

     DO mm=1,mo-1
       sumoff=sumoff+ndy(mm)*24
     ENDDO

     DO dd=1,dy-1
       sumoff=sumoff+24
     ENDDO

     sumoff=sumoff+hr
     wrf_times_2Udunits_c=sumoff

 END FUNCTION wrf_times_2Udunits_c
!--------------------------------------------------------
 INTEGER FUNCTION wrf_times_to_ymdh(yr,mo,dy,hr)

     implicit none

     INTEGER :: yr, mo, dy, hr

     wrf_times_to_ymdh=yr*1000000+mo*10000+dy*100+hr
 
 END FUNCTION wrf_times_to_ymdh


!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
