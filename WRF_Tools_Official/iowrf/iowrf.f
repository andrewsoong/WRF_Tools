      program iowrf
!  Program to read/write wrf output. 
!  OPTION -thin  : It will thin data to the ratio given
!  OPTION -thina : It will average the fields over a user-specified grid area.
!  OPTION -A     : De-stagger data
!  OPTION -box   : Will get data from a user defined box
!  Updated: January 8, 2008
!           Add de-staggering option
!  Updated: Jun 19, 2007
!           Change time to unlimted on output
!   Origincal code:
!           Cindy Bruyere - March 2006
!           Some code borrowed from Jim Bresch
!=================================Run Program================================
!  To extract a box from your input file
!     iowrf wrfout_file -box x 10 50 y 10 60 [-debug]
!
!  To thin your input file down (by picking up corresponding points)
!     iowrf wrfout_file -thin 3 [-debug]
!
!  To thin your input file down (by averaging)
!     iowrf wrfout_file -thina 3 [-debug]
!
!  To de-stagger the data
!     iowrf wrfout_file -A
!
!  To CREATE large 64bit data files
!     -64bit
!
!  To see more options
!     iowrf -help         
!
!  The output will be written to a file with original file name + -box/-thin/-thina/-A
!
!=================================Make Executable============================
!  Make executable:
!    DEC Alpha
!      f90 iowrf.f -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -free  -o iowrf
!
!   linux flags
!      pgf90 iowrf.f -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -Mfree  -o iowrf
!
!   Sun flags
!      f90 iowrf.f -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -free  -o iowrf
!
!   SGI flags
!      f90 iowrf.f -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -freeform  -o iowrf
!
!   IBM flags (NCAR bluesky - 32bit)
!      xlf iowrf.f -L/usr/local/lib32/r4i4 -lnetcdf -lm  \
!      -I/usr/local/include  -qfree=f90  -o iowrf
!
!   IBM flags (NCAR bluesky - 64bit)
!      xlf iowrf.f -L/usr/local/lib64/r4i4 -lnetcdf -lm  \
!      -I/usr/local/include  -qfree=f90  -o iowrf
!
!   IBM flags (NCAR bluevista)   
!      xlf iowrf.f -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -qfree=f90  -o iowrf
!
!   Mac flags (with xlf compiler)
!      xlf iowrf.f -L/usr/local/netcdf-xlf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf-xlf/include  -qfree=f90  -o iowrf
!
!   Mac flags (with g95 compiler)
!	g95 iowrf.f -L/usr/local/netcdf/lib -lnetcdf -lm  \
!	-I/usr/local/netcdf/include -ffree-form -o iowrf
!
!============================================================================

      implicit none
      INCLUDE 'netcdf.inc'
      integer  :: jdim
      parameter (jdim=6)
      integer ncid, status
      integer ishape(jdim)
      integer ishape2(jdim)
      character cval*50
      character name*31
      character (len=31),allocatable, dimension(:)      :: dname
      integer,           allocatable, dimension(:)       :: dval, dval2
      real,              allocatable, dimension(:,:,:,:) :: data, data2
      double precision,  allocatable, dimension(:,:,:,:) :: ddata, ddata2
      integer,           allocatable, dimension(:,:,:,:) :: idata, idata2
      character,         allocatable, dimension(:,:,:,:) :: text
      character omit(10)*80
      integer             :: start_dims(4)
      integer             :: dims_in(4), dims_out(4), box_start(3), box_end(3)
      integer             :: firstS,firstE, secondS,secondE, thirdS,thirdE
      integer             :: idm, ndims, nvars, natt, ngatts, nunlimdimid, iratio
      integer             :: i, ii, j, iweg, jweg, isng, jsng, ibtg, jbtg, ix, iy
      integer             :: i_shape_we, i_shape_sn, i_shape_bt
      integer             :: i_shape_we_stag, i_shape_sn_stag, i_shape_bt_stag
      integer             :: ilen, itype, ival, na
      integer             :: mcid
      real                :: dx, rval
      real                :: new_cen
      real                :: okm
      character (len=80)  :: input_file, output_file
      character (len=10)  :: option
      logical             :: debug=.FALSE.
      logical             :: x_ave=.FALSE.
      logical             :: y_ave=.FALSE.
      logical             :: bit64

      call read_args(input_file,option,iratio,box_start,box_end,bit64,debug)
      output_file  = trim(input_file)//option

      write(6,*) 
      write(6,*) "#########################################"
      write(6,*) "Running IOWRF "
      write(6,*) 
      write(6,*) "INPUT FILE:         ",trim(input_file)
      write(6,*) "OUTPUT FILE:        ",trim(output_file)
      write(6,*) "OPTION:             ",option    

      IF (debug) THEN
        if ( option(1:5) == '-thin' ) then           ! used for -thina and -thin
          write(6,*) "RATIO:             ",iratio    
        elseif ( option == '-box' )then
          write(6,*) "BOX START (x y z): ",box_start    
          write(6,*) "BOX END   (x y z): ",box_end    
        endif
      ENDIF


! OPEN INPUT AND OUTPUT FILE
! output_file is input_file_new
      status = nf_open(input_file, 0, ncid)
      if (status .ne. nf_noerr) call handle_err(status)
      if (bit64) then
        status = nf_create(output_file, NF_64BIT_OFFSET, mcid)
      else
        status = nf_create(output_file, 0, mcid)
      endif
      if (status .ne. nf_noerr) call handle_err(status)

! GET BASIC INFORMTION ABOUT THE FILE
! most important 
!   ndims:  number of dimensions
!   nvars:  number of variables
!   ngatts: number of global attributes
      status = nf_inq(ncid, ndims, nvars, ngatts, nunlimdimid)
      if (status .ne. nf_noerr) call handle_err(status)
      IF (debug) THEN
        write(6,*) 
        write(6,'(4(A,i4))') ' ndims = ',ndims,'    nvars = ',nvars,'    ngatts = ',ngatts, &
                   '    nunlimdimid =',nunlimdimid
        write(6,*) 
      ENDIF

! ALLOCATE SOME VARIABLES
      allocate (dval(ndims))
      allocate(dval2(ndims))
      allocate(dname(ndims))

! GET SOME BASIC DIMS FROM INPUT_FILE
      dx = -99.
      status = nf_get_att_real (ncid, nf_global, 'DX', dx)
      status = nf_get_att_int (ncid, nf_global, 'WEST-EAST_GRID_DIMENSION', iweg)
      status = nf_get_att_int (ncid, nf_global, 'SOUTH-NORTH_GRID_DIMENSION', isng)
      status = nf_get_att_int (ncid, nf_global, 'BOTTOM-TOP_GRID_DIMENSION', ibtg)
      IF (debug) THEN
        write(6,*) "BASICS from input file:"
        write(6,*) "       DX= ", dx
        write(6,*) "        X= ", iweg
        write(6,*) "        Y= ", isng
        write(6,*) "        Z= ", ibtg
      ENDIF
      if (dx .lt. 0.) stop 'dx is bad'

! CALCULATE DIMS FOR OUTPUT FILE
      IF ( option(1:5) == '-thin' ) THEN           ! used for -thina and -thin
        okm = dx*iratio
        jweg = int((iweg-1)/iratio) + 1
        jsng = int((isng-1)/iratio) + 1
        jbtg = ibtg
      ELSEIF ( option == '-box' ) THEN
        okm = dx
        jweg = iweg
        jsng = isng
        jbtg = ibtg
        if ( box_end(1) .ne. 0 ) jweg = int(box_end(1) - box_start(1)) + 1
        if ( box_end(2) .ne. 0 ) jsng = int(box_end(2) - box_start(2)) + 1
        if ( box_end(3) .ne. 0 ) jbtg = int(box_end(3) - box_start(3)) + 1
      ELSE
        okm = dx
        jweg = iweg
        jsng = isng
        jbtg = ibtg
      ENDIF
      IF (debug) THEN
        write(6,*) "BASICS for output file:"
        write(6,*) "       DX= ", okm
        write(6,*) "        X= ", jweg
        write(6,*) "        Y= ", jsng
        write(6,*) "        Z= ", jbtg
      ENDIF
      !! We also need to fix the CEN_LAT and CEN_LON later, so get
      !! the middle of the new domain
      ix = int((jweg-1)/2.)
      iy = int((jsng-1)/2.)
      if ( ix .eq. int(jweg/2.) ) x_ave = .TRUE.
      if ( iy .eq. int(jsng/2.) ) y_ave = .TRUE.
      ix = int(jweg/2.)
      iy = int(jsng/2.)

! READ ALL DIMS FROM INPUT FILE AND CREATE DIMS FOR OUTPUT FILE
      IF (debug) THEN
        write(6,*) 
        write(6,*) "FILE dimensions:"
      ENDIF
      i_shape_we      = 0
      i_shape_sn      = 0
      i_shape_bt      = 0
      i_shape_we_stag = 0
      i_shape_sn_stag = 0
      i_shape_bt_stag = 0

      do i = 1, ndims
        status = nf_inq_dim(ncid, i, dname(i), dval(i))
        dval2(i) = dval(i)
!       CAUTION -- this stuff is hard-wired
        if (dname(i) .eq. 'west_east_stag') then
          dval2(i) = jweg
          i_shape_we_stag = i
        else if (dname(i) .eq. 'west_east') then
          dval2(i) = jweg-1
          i_shape_we = i
        else if (dname(i) .eq. 'south_north_stag') then
          dval2(i) = jsng
          i_shape_sn_stag = i
        else if (dname(i) .eq. 'south_north') then
          dval2(i) = jsng-1
          i_shape_sn = i
        else if (dname(i) .eq. 'bottom_top_stag') then
          dval2(i) = jbtg
          i_shape_bt_stag = i
        else if (dname(i) .eq. 'bottom_top') then
          dval2(i) = jbtg-1
          i_shape_bt = i
        endif
        if ( dname(i) == "Time" ) then
          status = nf_def_dim(mcid, dname(i), NF_UNLIMITED, i)
        else
          status = nf_def_dim(mcid, dname(i), dval2(i), i)
        end if
        IF (debug) THEN
          write(6,'(i4," : ",A," in = ",i4," (out = ",i4,")")') &
                i,dname(i),dval(i),dval2(i)
        ENDIF
      enddo
      IF (.not. debug) THEN
        write(6,*)
        write(6,*) "Set up file DIMENSIONS"
      ENDIF

! DEALING WITH THE GLOBAL ATTRIBUTES
      IF (debug) THEN
        write(6,*) 
        write(6,*) "FILE attributes:"
      ENDIF
      do i = 1, ngatts
        status = nf_inq_attname(ncid, nf_global, i, name)
        status = nf_inq_atttype(ncid, nf_global, name, itype)
        status = nf_inq_attlen(ncid, nf_global, name, ilen)

        if ( itype .eq. 2 ) then        ! characters
          status = nf_get_att_text (ncid, nf_global, name, cval)
          IF (debug) THEN
            write(6,'(i4," : ",A," in = ",A," (out = ",$)') &
                  i,name,cval(1:ilen)
          ENDIF
          if(name(1:5) .eq. 'TITLE') then
             cval = cval(1:ilen)//" : iowrf"//option
             ilen = len_trim(cval)
          endif
          IF (debug) write(6,'(A,")")') cval(1:ilen)
          status = nf_put_att_text(mcid, nf_global, name, ilen,&
                    cval(1:ilen))

        elseif ( itype .eq. 4 ) then     ! integers
          status = nf_get_att_int (ncid, nf_global, name, ival)
          IF (debug) THEN
            write(6,'(i4," : ",A," in = ",i7," (out = ",$)') &
                  i,name,ival        
          ENDIF
          if(name .eq. 'WEST-EAST_GRID_DIMENSION') ival = jweg
          if(name .eq. 'SOUTH-NORTH_GRID_DIMENSION') ival = jsng
          if(name .eq. 'BOTTOM-TOP_GRID_DIMENSION') ival = jbtg
          IF (debug) write(6,'(i7,")")') ival
          status = nf_put_att_int(mcid, nf_global, name, itype,&
                    ilen, ival)

        elseif ( itype .eq. 5 ) then    ! real
          status = nf_get_att_real (ncid, nf_global, name, rval)
          IF (debug) THEN
            write(6,'(i4," : ",A," in = ",G18.10E2," (out = ",$)') &
                  i,name,rval        
          ENDIF
          if(name(1:2) .eq. 'DX' .or. name(1:2) .eq. 'DY') rval = okm
          IF (debug) write(6,'(G18.10E2,")")') rval
          status = nf_put_att_real(mcid, nf_global, name, itype,&
                    ilen, rval)
        endif
      enddo
      IF ( .not. debug ) THEN
        write(6,*) "Write file ATTRIBUTES"
        write(6,*) 
      ENDIF


! TRAIN FILE
      do i = 1, nvars
        status = nf_inq_var(ncid, i, cval, itype, idm, ishape, natt)
        ishape2 = ishape
        if ( idm .ge. 4 ) then
          do ii=1,idm
            IF     ( option == "-A" .AND. ishape2(ii) == i_shape_bt_stag ) THEN
              ishape2(ii) = i_shape_bt
            ELSEIF ( option == "-A" .AND. ishape2(ii) == i_shape_we_stag ) THEN
              ishape2(ii) = i_shape_we
            ELSEIF ( option == "-A" .AND. ishape2(ii) == i_shape_sn_stag ) THEN
              ishape2(ii) = i_shape_sn
            END IF
          enddo
        end if

        status = nf_def_var(mcid, cval, itype, idm, ishape2, i)
        do na = 1, natt
          status = nf_inq_attname(ncid, i, na, name)
          status = nf_copy_att(ncid, i, name, mcid, i)
        enddo
      enddo
      status = nf_enddef(mcid)

! ########## LOOP THROUGH THE DATA 
      IF (debug) THEN
        write(6,*) 
        write(6,*) 
      ENDIF
      write(6,*) "Write file VARIABLES:"
      start_dims = 1
      do i = 1, nvars
        status = nf_inq_var(ncid, i, cval, itype, idm, ishape, natt)
        ishape2 = ishape
        if ( idm .ge. 4 ) then
          do ii=1,idm
            IF     ( option == "-A" .AND. ishape2(ii) == i_shape_bt_stag ) THEN
              ishape2(ii) = i_shape_bt
            ELSEIF ( option == "-A" .AND. ishape2(ii) == i_shape_we_stag ) THEN
              ishape2(ii) = i_shape_we
            ELSEIF ( option == "-A" .AND. ishape2(ii) == i_shape_sn_stag ) THEN
              ishape2(ii) = i_shape_sn
            END IF
          enddo
        end if
        IF (debug) THEN
          write(6,*) 
        ENDIF
        write(6,*) 'VARIABLE: ',trim(cval)

! GET THE DIMS FOR INPUT AND OUTPUT FROM THE SHAPE
        dims_in  = 1
        dims_out = 1
        do ii = 1,idm
          dims_in(ii)  = dval(ishape(ii))
          dims_out(ii) = dval2(ishape2(ii))
        enddo
        IF (debug) THEN
          write(6,*) '   DIMS  IN: ',dims_in
          write(6,*) '   DIMS OUT: ',dims_out
        ENDIF

        IF ( option == '-box' ) THEN
           !! Get the start and end dimensions of the box in the input file
           firstS  = 1
           firstE  = dims_out(1)
           secondS = 1
           secondE = dims_out(2)
           thirdS  = 1
           thirdE  = dims_out(3)

          if (idm.eq.2 .and. dims_out(1).ge.jbtg-1 .and. box_end(3).ne.0) then
            firstS = box_start(3)
            firstE = box_end(3)
            if (dims_out(3) .eq. jbtg-1) firstE = firstE-1
          endif
          if (idm .ge. 3) then
            if (box_end(1) .ne. 0) then
              firstS = box_start(1)
              firstE = box_end(1)
              if (dims_out(1) .eq. jweg-1) firstE = firstE-1
            endif
            if (box_end(2) .ne. 0) then
              secondS = box_start(2)
              secondE = box_end(2)
              if (dims_out(2) .eq. jsng-1) secondE = secondE-1
            endif
            if (idm == 4 .and. box_end(3).ne.0) then
              thirdS = box_start(3)
              thirdE = box_end(3)
              if (dims_out(3) .eq. jbtg-1) thirdE = thirdE-1
            endif
          endif
        ENDIF

! ALLOCATE THE INPUT AND OUTPUT ARRAYS
! READ THE DATA FROM INPUT FILE
! THIN THE GRID IF NEEDED, OR GET THE CORRECT BOX

        IF     (itype .eq. 2) THEN          ! character
          allocate (text(dims_in(1), dims_in(2), dims_in(3), &
                         dims_in(4)))
          status = nf_get_var_text(ncid, i, text)
          IF (debug) write(6,*) '   SAMPLE VALUE = ',text(:,1,1,1)
          status = nf_put_vara_text (mcid, i, start_dims, dims_in, text)
          deallocate (text)

        ELSEIF (itype .eq. 4) THEN          ! integer
          allocate (idata(dims_in(1), dims_in(2), dims_in(3), &
                          dims_in(4)))
          allocate(idata2(dims_out(1),dims_out(2),dims_out(3),&
                          dims_out(4)))
          status = nf_get_var_int(ncid, i, idata)
          IF (debug) write(6,*) '   SAMPLE VALUE = ',idata(1,1,1,1)
          IF ( option == '-thina' ) THEN   
            if (idm .ge. 3) then
              IF (debug) write(6,*) '   Grid is thinned with a ratio of ',iratio
              allocate(data2(dims_out(1),dims_out(2),dims_out(3),&
                              dims_out(4)))
              call thin_ave (real(idata),data2,dims_in(1),dims_in(2),          &
                             dims_in(3),dims_in(4),dims_out(1),dims_out(2),    &
                             dims_out(3),dims_out(4),iratio)       
              idata2 = int(data2)
              deallocate(data2)
            else
              idata2 = idata
            endif
          ELSEIF ( option == '-thin' ) THEN   
            if (idm .ge. 3) then
              IF (debug) write(6,*) '   Grid is thinned with a ratio of ',iratio
              idata2 = idata(1:dims_in(1):iratio,1:dims_in(2):iratio,:,:)
            else
              idata2 = idata
            endif
          ELSEIF ( option == '-A' ) THEN   
            idata2 = idata
          ELSEIF ( option == '-box') THEN
            IF (debug) write(6,*) '   a BOX is extracted from the input domain '  
            idata2 = idata(firstS:firstE,secondS:secondE,thirdS:thirdE,:)
          ENDIF
          status = nf_put_vara_int (mcid, i, start_dims, dims_out, idata2)
          deallocate (idata)
          deallocate (idata2)

        ELSEIF (itype .eq. 5) THEN          ! real
          allocate (data(dims_in(1), dims_in(2), dims_in(3), &
                         dims_in(4)))
          allocate(data2(dims_out(1),dims_out(2),dims_out(3), &
                         dims_out(4)))
          status = nf_get_var_real(ncid, i, data)
          IF (debug) write(6,*) '   SAMPLE VALUE = ',data(1,1,1,1)
          IF ( option == '-thina' ) THEN    
            if (idm .ge. 3) then
              IF (debug) write(6,*) '   Grid is thinned with a ratio of ',iratio
              call thin_ave (data,data2,dims_in(1),dims_in(2),               &
                             dims_in(3),dims_in(4),dims_out(1),dims_out(2),  &
                             dims_out(3),dims_out(4),iratio)       
            else
              data2 = data
            endif
          ELSEIF ( option == '-thin' ) THEN    
            if (idm .ge. 3) then
              IF (debug) write(6,*) '   Grid is thinned with a ratio of ',iratio
              data2 = data(1:dims_in(1):iratio,1:dims_in(2):iratio,:,:)
            else
              data2 = data
            endif
          ELSEIF ( option == '-A' ) THEN    
            if     (idm .eq. 4 .AND. (dims_in(1) > dims_out(1)) ) then
              IF (debug) write(6,*) '   de-staggering in the X direction'
              data2 = (data(1:dims_in(1)-1,:,:,:)+data(2:dims_in(1),:,:,:))*.5
            elseif (idm .eq. 4 .AND. (dims_in(2) > dims_out(2)) ) then
              IF (debug) write(6,*) '   de-staggering in the Y direction'
              data2 = (data(:,1:dims_in(2)-1,:,:)+data(:,2:dims_in(2),:,:))*.5
            elseif (idm .eq. 4 .AND. (dims_in(3) > dims_out(3)) ) then
              IF (debug) write(6,*) '   de-staggering in the Y direction'
              data2 = (data(:,:,1:dims_in(3)-1,:)+data(:,:,3:dims_in(2),:))*.5
            else
              data2 = data
            endif
          ELSEIF ( option == '-box') THEN
            IF (debug) write(6,*) '   a BOX is extracted from the input domain '  
            data2 = data(firstS:firstE,secondS:secondE,thirdS:thirdE,:)
          ENDIF
          status = nf_put_vara_real (mcid, i, start_dims, dims_out, data2)
          IF ( cval == 'XLAT' .or. cval == 'XLONG' ) THEN
!            We need fix the box's center long and lat
             new_cen = data2(ix,iy,1,1)
                 if ( x_ave .and. y_ave ) then
               new_cen = (data2(ix,  iy,1,1)+data2(ix  ,iy+1,1,1)+  &
                          data2(ix+1,iy,1,1)+data2(ix+1,iy+1,1,1))/4.
             elseif ( x_ave .and. .not. y_ave ) then
               new_cen = (data2(ix,  iy,1,1)+data2(ix+1,iy  ,1,1))/2.
             elseif ( .not. x_ave .and. y_ave ) then
               new_cen = (data2(ix,  iy,1,1)+data2(ix  ,iy+1,1,1))/2.
             endif
          ENDIF
          IF ( cval == 'XLAT' ) THEN
             IF (debug) write(6,*) '   Fix global attribute CEN_LAT: now = ', new_cen
             status = nf_inq_atttype(ncid, nf_global, 'CEN_LAT', itype)
             status = nf_inq_attlen(ncid, nf_global, 'CEN_LAT', ilen)
             status = nf_put_att_real(mcid, nf_global, 'CEN_LAT', itype,&
                       ilen, new_cen)
          ELSEIF ( cval == 'XLONG' ) THEN
             IF (debug) write(6,*) '   Fix global attribute CEN_LON: now = ', new_cen
             status = nf_inq_atttype(ncid, nf_global, 'CEN_LON', itype)
             status = nf_inq_attlen(ncid, nf_global, 'CEN_LON', ilen)
             status = nf_put_att_real(mcid, nf_global, 'CEN_LON', itype,&
                       ilen, new_cen)
          ENDIF
          deallocate (data)
          deallocate (data2)

        ELSEIF (itype .eq. 6) THEN          ! double
          allocate (ddata(dims_in(1), dims_in(2), dims_in(3), &
                          dims_in(4)))
          allocate(ddata2(dims_out(1),dims_out(2),dims_out(3),&
                          dims_out(4)))
          status = nf_get_var_double(ncid, i, ddata)
          IF (debug) write(6,*) '   SAMPLE VALUE = ',ddata(1,1,1,1)
          IF ( option == '-thina' ) THEN    
            if (idm .ge. 3) then
              IF (debug) write(6,*) '   Grid is thinned with a ratio of ',iratio
              allocate(data2(dims_out(1),dims_out(2),dims_out(3),&
                              dims_out(4)))
              call thin_ave (real(ddata),data2,dims_in(1),dims_in(2),               &
                             dims_in(3),dims_in(4),dims_out(1),dims_out(2),    &
                             dims_out(3),dims_out(4),iratio)       
              ddata2 = data2
              deallocate (data2)
            else
              ddata2 = ddata
            endif
          ELSEIF ( option == '-thin' ) THEN 
            if (idm .ge. 3) then
              IF (debug) write(6,*) '   Grid is thinned with a ratio of ',iratio
              ddata2 = ddata(1:dims_in(1):iratio,1:dims_in(2):iratio,:,:)
            else
              ddata2 = ddata
            endif
          ELSEIF ( option == '-A' ) THEN    
            if     (idm .eq. 4 .AND. (dims_in(1) > dims_out(1)) ) then
              IF (debug) write(6,*) '   de-staggering in the X direction'
              ddata2 = (ddata(1:dims_in(1)-1,:,:,:)+ddata(2:dims_in(1),:,:,:))*.5
            elseif (idm .eq. 4 .AND. (dims_in(2) > dims_out(2)) ) then
              IF (debug) write(6,*) '   de-staggering in the Y direction'
              ddata2 = (ddata(:,1:dims_in(2)-1,:,:)+ddata(:,2:dims_in(2),:,:))*.5
            elseif (idm .eq. 4 .AND. (dims_in(3) > dims_out(3)) ) then
              IF (debug) write(6,*) '   de-staggering in the Z direction'
              ddata2 = (ddata(:,:,1:dims_in(3)-1,:)+ddata(:,:,3:dims_in(2),:))*.5
            else
              ddata2 = ddata
            endif
          ELSEIF ( option == '-box') THEN
            IF (debug) write(6,*) '   a BOX is extracted from the input domain '  
            ddata2 = ddata(firstS:firstE,secondS:secondE,thirdS:thirdE,:)
          ENDIF
          status = nf_put_vara_double (mcid, i, start_dims, dims_out, ddata2)
          deallocate (ddata)
          deallocate (ddata2)
        ELSE
            stop 'trouble - do not know the variable type'
        ENDIF

      ENDDO     ! END OF VARIABLE LOOP
      status = nf_close(mcid)

      write(6,*) 
      write(6,*) "SUCCESS - we are out of here"      
      write(6,*) "#########################################"

      end program iowrf
!---------------------------------------------------------------------
      subroutine handle_err(status)
      integer status
      write(6,*) 'Error number ',status
      stop
      end subroutine
!---------------------------------------------------------------------
      subroutine thin_ave (ain, aou, a1, a2, a3, a4, b1, b2, b3, b4, &
             iratio)
! average one array into another in x,y. 
      integer a1, a2, a3, a4, b1, b2, b3, b4,iratio
      real ain(a1,a2,a3,a4), aou(b1,b2,b3,b4)
      !write(6,*) 'begin thin_ave, ratio = ',iratio
      !write(6,*) 'a1 = ',a1,' a2 = ',a2,' a3 = ',a3,' a4 = ',a4
      !write(6,*) 'b1 = ',b1,' b2 = ',b2,' b3 = ',b3,' b4 = ',b4
      do k4 = 1, b4
      do k3 = 1, b3
      do j = 1, b2
        ymx = (((j-1) * iratio) + 1 ) + iratio/2.
        ymn = (((j-1) * iratio) + 1 ) - iratio/2.
        ymx = amin1(float(a2),ymx)
        ymn = amax1(1.,ymn)
        !write(6,*) 'ymn = ',ymn,' ymx = ',ymx
      do i = 1, b1
        !write(6,*) 'i = ',i,' j = ',j
        xmx = (((i-1) * iratio) + 1 ) + iratio/2.
        xmn = (((i-1) * iratio) + 1 ) - iratio/2.
        xmx = amin1(float(a1),xmx)
        xmn = amax1(1.,xmn)
        !write(6,*) 'xmn = ',xmn,' xmx = ',xmx
        nc = 0
        sum = 0.
        nn1 = int(ymn+.5)
        nn2 = int(ymx)
        do n = nn1, nn2
          mm1 = int(xmn+.5)
          mm2 = int(xmx)
          !write(6,*) 'nn1 = ',nn1,' nn2 = ',nn2
          !write(6,*) 'mm1 = ',mm1,' mm2 = ',mm2
          do m = mm1, mm2
            sum = ain(m,n,k3,k4) + sum
            !write(6,*) 'm = ',m,' n = ',n,' ain = ',ain(m,n,k3,k4),&
            ! ' sum = ',sum
            nc = nc + 1
          enddo
        enddo
        aou(i,j,k3,k4) = sum/float(nc)
        !write(6,*) 'i = ',i,' value = ',aou(i,j,k3,k4)
      enddo
      enddo
      enddo
      enddo

      end subroutine thin_ave 
!--------------------------------------------------------

  subroutine read_args(input_file,option,iratio,box_start,box_end,bit64,debug)

  implicit none
  character (len=80)    :: input_file
  character (len=10)    :: option

  integer               :: iratio
  integer               :: box_start(3), box_end(3)
  logical               :: bit64, debug

  integer               :: numarg, i, idummy, idummy1, idummy2
  real                  :: rdummy
  integer, external     :: iargc
  character (len=80)    :: dummy, dir

! set up some defaults first
  input_file = " "
  option = " "
  idummy1 = 0
  idummy2 = 0
  box_start = 0
  box_end   = 0
  bit64 = .FALSE.
  numarg = iargc()
  i = 1

  if (numarg .lt. 1) call help_info

  do while (i <= numarg)
    call getarg(i,dummy)

    if (dummy(1:1) == "-") then    ! We have an option, else it is the filename

      SELECTCASE (trim(dummy))
          CASE ("-help")
               call help_info
          CASE ("-h")
               call help_info
          CASE ("-debug")
               debug = .TRUE.     
          CASE ("-thina")
               option = dummy
               i = i+1
               call getarg(i,dummy)
               read(dummy,'(i3)')idummy
               iratio = idummy
               if ( iratio .lt. 2 ) STOP ' Must supply a ratio of 2 or more ' 
          CASE ("-thin")
               option = dummy
               i = i+1
               call getarg(i,dummy)
               read(dummy,'(i3)')idummy
               iratio = idummy
               if ( iratio .lt. 2 ) STOP ' Must supply a ratio of 2 or more ' 
          CASE ("-A")
               option = dummy
          CASE ("-box")
               option = dummy
               DO 
                 i = i+1
                 call getarg(i,dir)
                 if (dir(1:1) == '-') then
                   i=i-1
                   exit
                 endif
                 if (dir.ne.'x') then
                 if (dir.ne.'y') then
                 if (dir.ne.'z') then
                   i=i-1
                   exit
                 endif
                 endif
                 endif
                 i = i+1
                 call getarg(i,dummy)
                 read(dummy,'(i3)')idummy1
                 i = i+1
                 call getarg(i,dummy)
                 read(dummy,'(i3)')idummy2
                 if (dir.eq.' '.or.idummy1.eq.0.or.idummy2.eq.0) exit
                 if ( dir == 'x' ) then
                   box_start(1) = idummy1
                   box_end(1)   = idummy2
                 endif
                 if ( dir == 'y' ) then
                   box_start(2) = idummy1
                   box_end(2)   = idummy2
                 endif
                 if ( dir == 'z' ) then
                   box_start(3) = idummy1
                   box_end(3)   = idummy2
                 endif
                 idummy1 = 0
                 idummy2 = 0
               ENDDO
          CASE ("-64bit")
               bit64 = .TRUE.
          CASE DEFAULT
               call help_info
      END SELECT
    else
      input_file = dummy
    endif

      i = i+1

  enddo

  if (input_file == " ") call help_info

  end subroutine read_args
!------------------------------------------------------------------------------

  subroutine help_info

  print*," "
  print*," iowrf   wrf_data_file_name  [-options] "
  print*," "
  print*," Current options available are:"
  print*," -help     : Print this information"                           
  print*," -h        : Print this information"                           
  print*," "
  print*," -thina x  : Thin the input grid, with a ratio of x"  
  print*,"             Example:"
  print*,"                -thina 3 " 
  print*,"             Will thin the grid with a ratio of 3, i.e.,   "
  print*,"             a 12km grid will be upscaled to a 36km grid" 
  print*,"             The new grid point will be an average of the surrounding points"
  print*," "
  print*," -thin x   : Thin the input grid, with a ratio of x"  
  print*,"             Example:"
  print*,"                -thin 3 " 
  print*,"             Will thin the grid with a ratio of 3, i.e.,   "
  print*,"             a 12km grid will be upscaled to a 36km grid" 
  print*,"             The new grid point will be the feedback value from the input domain"
  print*," "
  print*," -box [ ]  : Will extract a box out of the input grid"
  print*,"             The box can have values for x/y/z  "
  print*,"             Examples:"
  print*,"                -box x 10 30 y 20 40 z 5 15" 
  print*,"                -box x 10 30 y 20 40 " 
  print*,"                -box x 10 30 " 
  print*,"                -box y 20 40 " 
  print*," "
  print*," -A        : De-stagger output"
  print*," "
  print*," -64bit    : To create large 64bit data files"
  print*," "
  end subroutine help_info

!------------------------------------------------------------------------------

