   program v_interp

!  Program to increase vertical levels in wrfinput and wrfbdy files after ndown
!
!  YS Chen: Feb 25, 2008; WW: May 30, 2008
!
!  Program note: When adding eta levels, try to add new levels between
!    original ones - those are the second and second last full eta levels. 
!    Problem may occur when levels are added outside the
!    first and last half levels. 
!  Use of namelist.v_interp:
!    nvert:   number of new full vertical levels
!    nlevels: new full eta levels
!
!===========================================================================
!
!  To make executable:
!
!    DEC Alpha
!      f90 v_interp.f -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -free  -o v_interp
!
!   linux flags
!      pgf90 v_interp.f -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -Mfree  -o v_interp
!
!   Sun flags
!      f90 v_interp.f -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -free  -o v_interp
!
!   SGI flags
!      f90 v_interp.f -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -freeform  -o v_interp
!
!   IBM flags (NCAR bluevista/blueice)   
!      xlf v_interp.f -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -qfree=f90  -o v_interp
!      xlf v_interp.f -L/usr/local/netcdf/lib -lnetcdf -lm -I/usr/local/netcdf/include  -qfree=f90  -o v_interp
!
!   Mac flags (with xlf compiler)
!      xlf v_interp.f -L/usr/local/netcdf-xlf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf-xlf/include  -qfree=f90  -o v_interp
!
!   Mac flags (with g95 compiler)
!	g95 v_interp.f -L/usr/local/netcdf/lib -lnetcdf \
!	-I/usr/local/netcdf/include -ffree-form -o v_interp
!
!===========================================================================
!
!   To run:
!      v_interp wrfinput_d01 wrfinput_d01_new
!   or v_interp wrfbdy_d01 wrfbdy_d01_new
!
!   Note that the program will key on the input file name for wrfbdy_d0*, so
!      please keep the input file name for wrfbdy_d0*, if it is a wrfbdy file
!      Please also keep the companion wrfinput_d0* file in the same directory,
!      since the old eta levels need to come from the wrfinput_d0* file.
!      (Thanks to Steven Decker of Rutgers University for the fix.)
!

      implicit none
      INCLUDE 'netcdf.inc'
      integer  :: jdim
      parameter (jdim=6)
      integer ncid, status, ncid2
      integer ishape(jdim)
      integer ishape2(jdim)
      character cval*50
      character name*31
      character (len=31), allocatable, dimension(:)      :: dname
      integer,            allocatable, dimension(:)       :: dval, dval2
      real,               allocatable, dimension(:)       :: znw, znw2, znu, znu2
      real,               allocatable, dimension(:)       :: dnw2,rdnw2,dn2,rdn2,fnp2,fnm2
      real,               allocatable, dimension(:,:,:,:) :: data, data2
      double precision,   allocatable, dimension(:,:,:,:) :: ddata, ddata2
      integer,            allocatable, dimension(:,:,:,:) :: idata, idata2
      character,          allocatable, dimension(:,:,:,:) :: text
      character omit(10)*80
      integer             :: start_dims(4)
      integer             :: dims_in(4), dims_out(4), box_start(3), box_end(3)
      integer             :: firstS,firstE, secondS,secondE, thirdS,thirdE
      integer             :: idm, ndims, nvars, natt, ngatts, nunlimdimid, ratio, neta, neta_old
      integer             :: i, ii, j, iweg, jweg, isng, jsng, ibtg, jbtg, ix, iy, it, k
      integer             :: ilen, itype, ival, na
      integer             :: mcid
      integer             :: varid, varid2
      real                :: dx, rval
      real                :: new_cen
      real                :: okm
      character (len=80)  :: input_file, output_file, input_file2
      character (len=10)  :: option
      logical             :: debug=.TRUE.
      logical             :: bit64=.FALSE.
      logical             :: bdyfile=.FALSE.
      integer             :: isvdim=0

      integer, external   :: iargc
      integer             :: numarg
      integer             :: funit, nvert
      real,               dimension(100)  :: nlevels

      namelist /newlevels/   nlevels, nvert

      numarg = iargc()

      if (numarg .lt. 2) call help_info

      call getarg(1,input_file)
      call getarg(2,output_file)

! Is this a wrfbdy file?
      if ( input_file(1:6) .eq. 'wrfbdy' ) bdyfile = .true.
      if ( debug )print *, 'bdyfile ', bdyfile
 
      nlevels = 999.
      funit = 11
      OPEN (funit, file='namelist.v_interp',status='old',form='formatted',err=1000)
      go to 100
 1000 stop 'Error opening file namelist.v_interp'
  100 continue
      READ (funit, newlevels)
      CLOSE(funit)
      print *, nvert, nlevels

!stop
      neta=nvert
      allocate(znw2(neta))
      do k = 1,nvert
         znw2(k)=nlevels(k)
      end do

      allocate(dnw2(neta-1))
      allocate(rdnw2(neta-1))
      allocate(znu2(neta-1))
      allocate(dn2(neta-1))
      allocate(rdn2(neta-1))
      allocate(fnp2(neta-1))
      allocate(fnm2(neta-1))

      do k=1,neta-1
         dnw2(k)=znw2(k+1)-znw2(k)
         rdnw2(k)=1.0/dnw2(k)
         znu2(k)=0.5*(znw2(k+1)+znw2(k))
      enddo

      dn2(1)=0.0
      rdn2(1)=0.0
      fnp2(1)=0.0
      fnm2(1)=0.0

      do k=2,neta-1
         dn2(k)=0.5*(dnw2(k)+dnw2(k-1))
         rdn2(k)=1.0/dn2(k)
         fnp2(k)=0.5*dnw2(k)/dn2(k)
         fnm2(k)=0.5*dnw2(k-1)/dn2(k)
      enddo

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
        write(6,*) 'ndims = ',ndims,' nvars = ',nvars,' ngatts = ',ngatts, &
                   ' nunlimdimid =',nunlimdimid
      ENDIF

! ALLOCATE SOME VARIABLES
      allocate (dval(ndims))
      allocate(dval2(ndims))
      allocate(dname(ndims))

! READ ALL DIMS FROM INPUT FILE AND CREATE DIMS FOR OUTPUT FILE
      do i = 1, ndims
        status = nf_inq_dim(ncid, i, dname(i), dval(i))
	dval2(i) = dval(i)
	if (dname(i) .eq. 'bottom_top_stag') then
	  dval2(i) = neta
          neta_old=dval(i)
        else if (dname(i) .eq. 'bottom_top') then
	  dval2(i) = neta-1
        endif
        if ( dname(i) == "Time" ) then
          status = nf_def_dim(mcid, dname(i), NF_UNLIMITED, i)
        else
          status = nf_def_dim(mcid, dname(i), dval2(i), i)
        end if
        IF (debug) THEN
	  write(6,'(" i = ",i2," : ",A," in = ",i4," (out = ",i4,")")') &
                i,dname(i),dval(i),dval2(i)
        ENDIF
      enddo

! DEALING WITH THE GLOBAL ATTRIBUTES
      IF (debug) THEN
        write(6,*) 
        write(6,*) "FILE attributes:"
      ENDIF
      do i = 1, ngatts
        status = nf_inq_attname(ncid, nf_global, i, name)
        status = nf_inq_atttype(ncid, nf_global, name, itype)
        status = nf_inq_attlen(ncid, nf_global, name, ilen)

	if ( itype .eq. NF_CHAR ) then        ! characters
	  status = nf_get_att_text (ncid, nf_global, name, cval)
          IF (debug) THEN
	    write(6,'(" i = ",i2," : ",A," in = ",A," (out = ",$)') &
                  i,name,cval(1:ilen)
          ENDIF
	  if(name(1:5) .eq. 'TITLE') then
!            cval = cval(1:ilen)//" : v_interp"//option
!            ilen = len_trim(cval)
          endif
          IF (debug) write(6,'(A,")")') cval(1:ilen)
	  status = nf_put_att_text(mcid, nf_global, name, ilen,&
                    cval(1:ilen))

	elseif ( itype .eq. NF_INT ) then     ! integers
	  status = nf_get_att_int (ncid, nf_global, name, ival)
          IF (debug) THEN
	    write(6,'(" i = ",i2," : ",A," in = ",i7," (out = ",$)') &
                  i,name,ival        
          ENDIF
	  if(trim(name) .eq. 'BOTTOM-TOP_GRID_DIMENSION') ival = neta
	  if(trim(name) .eq. 'BOTTOM-TOP_PATCH_END_UNSTAG') ival = neta-1
	  if(trim(name) .eq. 'BOTTOM-TOP_PATCH_END_STAG') ival = neta
          IF (debug) write(6,'(i7,")")') ival
          status = nf_put_att_int(mcid, nf_global, name, itype,&
                    ilen, ival)

	elseif ( itype .eq. NF_FLOAT ) then    ! real
	  status = nf_get_att_real (ncid, nf_global, name, rval)
          IF (debug) THEN
	    write(6,'(" i = ",i2," : ",A," in = ",G18.10E2," (out = ",$)') &
                  i,name,rval        
          ENDIF
          IF (debug) write(6,'(G18.10E2,")")') rval
	  status = nf_put_att_real(mcid, nf_global, name, itype,&
                    ilen, rval)
	endif
      enddo

      IF (debug) THEN
        write(6,*) 
        write(6,*) 
        write(6,*) "FILE variables:"
      ENDIF
      do i = 1, nvars
        status = nf_inq_var(ncid, i, cval, itype, idm, ishape, natt)
	if (idm .gt. jdim) stop
	status = nf_def_var(mcid, cval, itype, idm, ishape, j)
	do na = 1, natt
          status = nf_inq_attname(ncid, i, na, name)
          status = nf_copy_att(ncid, i, name, mcid, i)
	enddo
      enddo
      status = nf_enddef(mcid)

! GET old vertical eta levels
      if (bdyfile) then
          input_file2 = "wrfinput_d" // input_file(len_trim(input_file)-1:)
          status = nf_open(input_file2, 0, ncid2)
          if ( debug ) print *, ' status reading wrfinput file = ', status
      else
          ncid2 = ncid
      end if

      allocate(znw(neta_old))
      status = nf_inq_varid(ncid2,'ZNW',varid2)
      status = nf_get_var_real(ncid2,varid2,znw)
      if ( debug ) print *, ' status for znw = ', status
      if (status .ne. 0) stop "Not finding ZNW"
      allocate(znu(neta_old))
      status = nf_inq_varid(ncid2,'ZNU',varid2)
      status = nf_get_var_real(ncid2,varid2,znu)
      if ( debug ) print *, ' status for znu = ', status
      if (status .ne. 0) stop "Not finding ZNU"
     
! ########## LOOP THROUGH THE DATA 
      start_dims = 1
      do i = 1, nvars
        status = nf_inq_var(ncid, i, cval, itype, idm, ishape, natt)
        IF (debug) THEN
          write(6,*) 
	  write(6,*) 'VARIABLE: ',trim(cval)
        ENDIF

! GET THE DIMS FOR INPUT AND OUTPUT FROM THE SHAPE
        dims_in  = 1
        dims_out = 1
        isvdim = 0
        do ii = 1,idm
          dims_in(ii)  = dval(ishape(ii))
          dims_out(ii) = dval2(ishape(ii))
	  if (trim(dname(ishape(ii))) .eq. 'bottom_top_stag' .or. &
              trim(dname(ishape(ii))) .eq. 'bottom_top' ) isvdim=ii
        enddo
        IF (debug) THEN
          write(6,*) '   DIMS  IN: ',dims_in
          write(6,*) '   DIMS OUT: ',dims_out
        ENDIF

! ALLOCATE THE INPUT AND OUTPUT ARRAYS
! READ THE DATA FROM INPUT FILE
! THIN THE GRID IF NEEDED, OR GET THE CORRECT BOX

	IF     (itype .eq. NF_CHAR ) THEN          ! character
          allocate (text(dims_in(1), dims_in(2), dims_in(3), &
                         dims_in(4)))
	  status = nf_get_var_text(ncid, i, text)
          IF (debug) write(6,*) '   SAMPLE VALUE = ',text(:,1,1,1)
	  status = nf_put_vara_text (mcid, i, start_dims, dims_in, text)
          deallocate (text)

	ELSEIF (itype .eq. NF_INT ) THEN          ! integer
          allocate (idata(dims_in(1), dims_in(2), dims_in(3), &
                          dims_in(4)))
          allocate(idata2(dims_out(1),dims_out(2),dims_out(3),&
                          dims_out(4)))
	  status = nf_get_var_int(ncid, i, idata)
          IF (debug) write(6,*) '   SAMPLE VALUE = ',idata(1,1,1,1)
	  idata2 = idata
	  status = nf_put_vara_int (mcid, i, start_dims, dims_out, idata2)
          deallocate (idata)
          deallocate (idata2)

	ELSEIF (itype .eq. NF_FLOAT) THEN          ! real
          allocate (data(dims_in(1), dims_in(2), dims_in(3), &
                         dims_in(4)))
          allocate(data2(dims_out(1),dims_out(2),dims_out(3), &
                         dims_out(4)))
	  status = nf_get_var_real(ncid, i, data)
          IF (debug) write(6,*) '   SAMPLE VALUE = ',data(1,1,1,1)
          IF ( isvdim .ne. 0 ) THEN    
            if (idm .ge. 3) then
              IF (debug) write(6,*) '   Vertical interpolate 3D variable, isvdim= ',isvdim
              if ( .not. bdyfile .and. isvdim.ne.3) then
                 write(6,*) ' Dimension order is not x,y,z,t, stop! '
                 stop
              endif
              if ( bdyfile .and. isvdim.ne.2) then
                 write(6,*) ' Dimension order is not x,z,w,t for bdy, stop! '
                 stop
              endif
              if(trim(dname(ishape(isvdim))) .eq. 'bottom_top_stag') then
!print *, ' znw ', znw
!print *, 'znw2 ', znw2
!print *, 'dims ', dims_in, dims_out
                 if ( bdyfile ) then
                   call vint3b(data,dims_in, data2, dims_out, znw, znw2)
                 else
                   call vint3(data,dims_in, data2, dims_out, znw, znw2)
                 endif
              else
!print *, 'dims ', dims_in, dims_out
                 if ( bdyfile ) then
                   call vint3b(data,dims_in, data2, dims_out, znu, znu2)
                 else
                   call vint3(data,dims_in, data2, dims_out, znu, znu2)
                 endif
              endif
	    else 
              IF (debug) write(6,*) '   Vertical interpolate 1D variable, isvdim= ',isvdim
              if (isvdim.ne.1) then
                 write(6,*) ' First dimension order is not z, stop! '
                 stop
              endif
              select case (trim(cval))
                case ('ZNW')
	          data2(:,1,1,1)=znw2
                case ('DNW')
                  data2(:,1,1,1)=dnw2
                case ('RDNW')
                  data2(:,1,1,1)=rdnw2
                case ('ZNU')
                  data2(:,1,1,1)=znu2
                case ('DN')
                  data2(:,1,1,1)=dn2
                case ('RDN')
                  data2(:,1,1,1)=rdn2
                case ('FNP')
                  data2(:,1,1,1)=fnp2
                case ('FNM')
                  data2(:,1,1,1)=fnm2
                case default
                  if(trim(dname(ishape(isvdim))) .eq. 'bottom_top_stag') then
                     call vint1(data,dims_in(1), data2, dims_out(1), znw,znw2)
                  else
                     call vint1(data,dims_in(1), data2, dims_out(1), znu,znu2)
                  endif
              end select
	    endif
          ELSE  ! isvdim=0, no vertical dim
            data2 = data
          ENDIF
	  status = nf_put_vara_real (mcid, i, start_dims, dims_out, data2)
          deallocate (data)
          deallocate (data2)

        ENDIF

      ENDDO     ! END OF VARIABLE LOOP
      status = nf_close(mcid)

      write(6,*) 
      write(6,*) " Success - we are out of here"      
      write(6,*) "#########################################"

      end program v_interp

!---------------------------------------------------------------------
      subroutine handle_err(status)
      integer status
      write(6,*) 'Error number ',status
      stop
      end subroutine

!---------------------------------------------------------------------
      subroutine vint3(vo,dimo,vn,dimn,zo,zn)
        integer :: dimo(4),dimn(4)
        real    :: vo(dimo(1),dimo(2),dimo(3),dimo(4))
        real    :: vn(dimn(1),dimn(2),dimn(3),dimn(4))
        real    :: zo(dimo(3)), zn(dimn(3))
        integer :: i,j,k,m

        do i=1,dimo(1)
        do j=1,dimo(2)
        do m=1,dimo(4)
           call vint1(vo(i,j,1:dimo(3),m),dimo(3),vn(i,j,1:dimn(3),m),dimn(3),zo,zn)
        enddo
        enddo
        enddo
        return
      end subroutine vint3

!------------------------------------------------------------------------------
      subroutine vint3b(vo,dimo,vn,dimn,zo,zn)
        integer :: dimo(4),dimn(4)
        real    :: vo(dimo(1),dimo(2),dimo(3),dimo(4))
        real    :: vn(dimn(1),dimn(2),dimn(3),dimn(4))
        real    :: zo(dimo(2)), zn(dimn(2))
        integer :: i,j,k,m

        do i=1,dimo(1)
        do j=1,dimo(3)
        do m=1,dimo(4)
           call vint1(vo(i,1:dimo(2),j,m),dimo(2),vn(i,1:dimn(2),j,m),dimn(2),zo,zn)
        enddo
        enddo
        enddo
        return
      end subroutine vint3b

!------------------------------------------------------------------------------
      subroutine vint1(v_in, nz_in, v_out, nz_out, z_in, z_out)
      implicit none
      integer nz_in, nz_out
      real    v_in(nz_in), z_in(nz_in)
      real    v_out(nz_out), z_out(nz_out)
      integer kp, k, im, ip
      logical interp, increasing_z
      real    height, w1, w2

! does vertical coordinate increase of decrease with increasing k?
! set offset appropriately

      ip = 0
      im = 1
      if (z_in(1) .gt. z_in(nz_in)) then
        ip = 1
        im = 0
      endif

      do k=1, nz_out

         interp = .false.
         kp = nz_in
         height = z_out(k)

         DO WHILE ( (.not. interp) .and. (kp .ge. 2) )

         IF(   ((z_in(kp-im) .le. height) .and.  &
                (z_in(kp-ip) .gt. height))             )   THEN
!print *, kp, k, z_in(kp-im), z_in(kp-ip), height
           w2 = (height-z_in(kp-im))/(z_in(kp-ip)-z_in(kp-im))
           w1 = 1.-w2
           v_out(k) = w1*v_in(kp-im) + w2*v_in(kp-ip)
           interp = .true.
         END IF
         kp = kp-1

         ENDDO

         if (.not. interp .and. kp .eq. 1) then
            v_out(1)=v_in(1)
         endif

      ENDDO

      RETURN
      END subroutine vint1

!------------------------------------------------------------------------------
  subroutine help_info

  print*," "
  print*," v_interp  wrfinput_filename  new_wrfinput_filename"
  print*," "
  STOP
  end subroutine help_info
