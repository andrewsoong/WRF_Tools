   PROGRAM wrf_interp
!  Program to read wrfout data and interpolate.
!  The program reads namelist.vinterp
!  November 2007 - Cindy Bruyere
!  November 2014 - Modified by Sherrie Fredrick
!  Version 1.1

      IMPLICIT NONE
      
      INCLUDE './netcdf.inc'


      REAL, PARAMETER                                    :: Rd = 287.04
      REAL, PARAMETER                                    :: Cp = 7.*Rd/2.
      REAL, PARAMETER                                    :: RCP = Rd/Cp
      REAL, PARAMETER                                    :: p0 = 100000.

!Variables read in from the namelist.vinterp in subroutine read_namelist
      CHARACTER (LEN=300),ALLOCATABLE, DIMENSION(:)      :: input_file_names
      CHARACTER (LEN=250)                                :: path_to_input
      CHARACTER (LEN=250)                                :: path_to_output
      CHARACTER (LEN=250)                                :: root_name
      REAL, DIMENSION(99)                                :: interp_levels
      INTEGER                                            :: num_interp_levels
      INTEGER                                            :: number_of_input_files
      integer                                            :: grid_id
      integer                                            :: logp
      INTEGER                                            :: extrapolate=0
      integer                                            :: start_date,vcor
      logical                                            :: leap_year
      logical                                            :: unstagger_grid
      LOGICAL                                            :: debug=.FALSE.




!Variables used for input and output file names
      CHARACTER (LEN=100)                                :: input_file, output_file
      CHARACTER (LEN=300)                                :: output_name, tmp_name
      CHARACTER (LEN=300),ALLOCATABLE, DIMENSION(:)      :: output_file_names


!Variables loaded in subroutine def_outfile_dims
      INTEGER                                            :: times_in_file,nsoil
      integer                                            :: time_ivar,level_ivar


!Variables read in from the input file loaded in subroutine basic_fileinfo
      integer                                            :: ndims,nvars,ngatts,iweg,isng,ibtg
      real                                               :: dx,dy


!Netcdf file ids 
      INTEGER                                            :: ncid !Input file id
      integer                                            :: mcid !output file id


!Netcdf return value
      integer                                            :: rcode



!Basic fields calculated in the main part of the program 
      REAL,              ALLOCATABLE, DIMENSION(:,:,:,:) :: pres_field
      REAL,              ALLOCATABLE, DIMENSION(:,:,:,:) :: ght, qv, tk, rh
      REAL,              ALLOCATABLE, DIMENSION(:,:,:,:) :: pvo,vert_pottmps
      REAL,              ALLOCATABLE, DIMENSION(:,:,:)   :: slp,sfp,sfpsm
      REAL,              ALLOCATABLE, DIMENSION(:,:)     :: surface_data,terrain


!Variables for keeping track of the number of netcdf variables read in and wrtten out
      integer                                            :: ivar,jvar


!Variables used for hold netcdf variable and attached names
      CHARACTER (LEN=80)                                 :: cval,att_text
      CHARACTER (LEN=31)                                 :: cname, test_dim_name
      CHARACTER,         ALLOCATABLE, DIMENSION(:,:,:,:) :: text
      LOGICAL                                            :: fix_meta_stag=.FALSE.
      


!Arrays to hold the fields when they are read in from the wrf netcdf file
      REAL,              ALLOCATABLE, DIMENSION(:,:,:,:) :: data1, data2, data3, flipp



!Variables used to store dimension values for input and output of variables
      INTEGER,           ALLOCATABLE, DIMENSION(:)       :: dvali, dvalj
      INTEGER,           ALLOCATABLE, DIMENSION(:,:,:,:) :: idata1, idata2
      INTEGER,                        DIMENSION(4)       :: start_dims = 1
      INTEGER,                        DIMENSION(4)       :: dims_in, dims_out
      INTEGER,                        DIMENSION(6)       :: ishape, jshape
      INTEGER                                            :: new_dim
      INTEGER                                            :: idm, natt, ndims_out
      INTEGER                                            :: nunlimdimid,morpl,mabpl,mmax,mkzh,kvalue
      CHARACTER (LEN=31),ALLOCATABLE, DIMENSION(:)       :: dnamei, dnamej



!Variables used for loop controls
      INTEGER                                            :: i, ii, j, jj, ix, iy ,k,loop


!Variables used in the interpolation 
      integer                                            :: icase
      CHARACTER (LEN=7)                                  :: cstag
      LOGICAL                                            :: interpolate=.FALSE.



      CHARACTER (LEN=10)                                 :: option
      CHARACTER (LEN=132)                                :: command
      REAL                                               :: MISSING=1.e36
      INTEGER                                            :: wanted
      INTEGER                                            :: u_ivar,v_ivar
      INTEGER                                            :: ilen, itype, na, funit, ios
      INTEGER                                            :: ierr, lent
      LOGICAL                                            :: bit64=.FALSE.
      LOGICAL                                            :: first=.TRUE.


!Initialize variables used by the read_namelist routine      
      path_to_input     = './'
      path_to_output    = './'
      output_name       = ' '
      interp_levels     = -99999.
      unstagger_grid    = .FALSE.
      num_interp_levels = 0
      vcor              = 0
      leap_year         = .TRUE.
      logp              = 0

!Read the namelist.vinterp
      call read_namelist(path_to_input,path_to_output,interp_levels,extrapolate, &
                         unstagger_grid,vcor,num_interp_levels,number_of_input_files, &
                         leap_year,debug,logp)


!Allocate space for the number of input files
       ALLOCATE ( input_file_names(number_of_input_files)  , STAT=ierr )
       ALLOCATE ( output_file_names(number_of_input_files) , STAT=ierr )
       if(ierr .ne. 0) then
           print*, ' tried to allocate ', number_of_input_files, ' input files, (look at ./foo)'
           STOP
        END IF

!  Initialize all of the file names to blank.
       input_file_names(number_of_input_files)(1:300) = ' '
       output_file_names(number_of_input_files)(1:300) = ' '

!  Open the file that has the list of filenames.
!  The list of filenames was loaded in the subroutine read_namelist.
        OPEN (FILE   = '.foo'        , &
              UNIT   = 111           , &
              STATUS = 'OLD'         , &
              ACCESS = 'SEQUENTIAL'  , &
              FORM   = 'FORMATTED'     )
  
!  Read all of the file names and store them.
        DO loop = 1 , number_of_input_files
           READ ( 111 , FMT='(A)' ) input_file_names(loop)
           IF ( output_name == ' ' ) THEN
              ilen = INDEX(TRIM(input_file_names(loop)),'/',.TRUE.) 
              output_file_names(loop) = TRIM(path_to_output)//input_file_names(loop)(ilen+1:)
              ilen =  len_trim(output_file_names(loop)) + 1
              output_file_names(loop)(ilen:ilen+6) = "_INTRP"
           ELSE
              IF ( number_of_input_files == 1 ) THEN
                 output_file_names(loop) = TRIM(path_to_output)//TRIM(output_name)
              ELSE
                 write(tmp_name,'(A,A,"_",I4.4)') TRIM(path_to_output), TRIM(output_name), loop
                 output_file_names(loop) = tmp_name
              ENDIF
           ENDIF
        END DO
        CLOSE ( 112 )
        print*, " " 

!   We clean up our own messes.
        CALL SYSTEM ( '/bin/rm -f .foo'  )
        CALL SYSTEM ( '/bin/rm -f .foo1' )


      write(6,*) 
      write(6,*) "##############################################################"
      write(6,'(A,i4,A)') " RUNNING wrf_interp V1.1 on ", number_of_input_files, " file(s)."


      
!!!!!MAIN LOOP OVER NUMBER OF FILES
     do loop = 1, number_of_input_files
         input_file  = input_file_names(loop)
         output_file = output_file_names(loop)
         print *,"Output will be written to: ",trim(output_file)


         rcode = nf_open(input_file, 0, ncid)
         if (rcode .ne. nf_noerr) call handle_err(rcode)

         rcode = nf_create(output_file, 0, mcid)
         if (rcode .ne. nf_noerr) call handle_err(rcode)

         call basic_fileinfo(ncid,ndims,nvars,ngatts,iweg,isng,ibtg,dx,dy)
         call outfile_attributes(ncid,mcid,debug,ngatts,num_interp_levels)


! ALLOCATE SOME VARIABLES
         IF (ALLOCATED(dnamei)) deallocate(dnamei)
            ALLOCATE (dnamei(20))
         IF (ALLOCATED(dnamej)) deallocate(dnamej)
            ALLOCATE (dnamej(20))
         IF (ALLOCATED(dvali)) deallocate(dvali)
             ALLOCATE (dvali(20))
         IF (ALLOCATED(dvalj)) deallocate(dvalj)
            ALLOCATE (dvalj(20))


!Define the output file dimensions.  This includes Time, grid and level information
         ndims_out = 0
         times_in_file = 0
         call def_outfile_dims(ncid,mcid,num_interp_levels,nsoil,ndims,time_ivar,level_ivar, &
                               ndims_out,times_in_file,dnamei,dnamej,dvali,dvalj,unstagger_grid)
         
!         print *,"times in file",times_in_file
         if(times_in_file .eq. 0) then
            print *,"Unable to get time variable from input file"
            stop
         end if
         call def_time_level_vars(ncid,mcid,time_ivar,level_ivar,interp_levels, &
                                  num_interp_levels,times_in_file,leap_year,vcor)
        

! WE NEED SOME BASIC FIELDS
         IF (ALLOCATED(data1)) deallocate(data1)
         allocate (data1(times_in_file,1,1,1))
         rcode = nf_inq_varid    ( ncid, "P_TOP", i )
         rcode = nf_get_var_real ( ncid, i, data1 )
         IF ( first ) THEN
            IF ( extrapolate == 1 .AND. &
                 (data1(1,1,1,1)-interp_levels(num_interp_levels)) > 0.0 ) THEN
               write(6,*)
               write(6,*) "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
               write(6,*) " WARNING: Highest requested pressure level is above PTOP."
               write(6,'(A,F7.2,A)') "      Use all pressure level data above", data1(1,1,1,1)*.01, " mb"
               write(6,*) "          with caution."
               write(6,*) "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
            ENDIF
            first = .FALSE.
         ENDIF
         deallocate (data1)

 
!Pressure
         IF (ALLOCATED(pres_field)) deallocate(pres_field)
         allocate (pres_field(iweg-1, isng-1, ibtg-1, times_in_file ))
         call getpres(ncid,iweg-1,isng-1,ibtg-1,times_in_file,pres_field)
          

!Terrain (HGT field on the wrfout files).
         IF (ALLOCATED(terrain)) deallocate(terrain)
         allocate (terrain(iweg-1,isng-1))
         call getterrain(ncid,iweg,isng,times_in_file,terrain)



!Geopotential height. Geopotential height is interpolated to mass levels
!using the interpolation located in ripdp_wrfarw.f
         if(ALLOCATED(ght)) deallocate(ght)
         allocate (ght(iweg,isng,ibtg-1,times_in_file ))
         call calcght(ncid,iweg,isng,ibtg-1,ibtg,times_in_file,ght)
!Temperature degrees K
         IF (ALLOCATED(tk)) deallocate(tk)
         allocate (tk(iweg,isng,ibtg-1, times_in_file ))
         call calctk(ncid,iweg,isng,ibtg-1,times_in_file,pres_field,tk)


!Relative Humidity and qvapor
         IF (ALLOCATED(qv)) deallocate(qv)
         allocate (qv(iweg-1,isng-1,ibtg-1, times_in_file ))
         rcode = nf_inq_varid    ( ncid, "QVAPOR", ivar )
         rcode = nf_get_var_real ( ncid, ivar, qv )  
         IF (ALLOCATED(rh)) deallocate(rh)
         allocate (rh(iweg,isng,ibtg-1, times_in_file ))
         call calcrh(iweg,isng,ibtg-1,times_in_file,pres_field,rh,qv,tk)


!SFP calculation is done for extrapolation below the ground using RIP's
!calculation of sfp in ripdp_wrfarw.f. If no extrapolation is requested
!the values are just set to 0.0.  The sfp is passed into the 
!interpolation and extrapolation routines.

         IF (ALLOCATED(sfp)) deallocate(sfp)
         allocate (sfp(isng,iweg,times_in_file ))
         IF (ALLOCATED(sfpsm)) deallocate(sfpsm)
         allocate (sfpsm(isng,iweg,times_in_file ))
         if(extrapolate .eq. 0) then
            sfp(:,:,:)     = 0.0
            sfpsm(:,:,:)   = 0.0
         else
            call calcsfp(ncid,iweg,isng,ibtg-1,times_in_file,pres_field, &
                         tk,ght,terrain,sfp,sfpsm)
            print *,"Calculated sfp for extrapolation of temperature"
         end if


!Calculate Equivalent potential temperature or potential temperature
!if asked for as a vertical coordinate.  The array that hold either
!the potential temperature or equivalent potential temperature is 
!vert_pottemp.  The vert_pottmps is passed into special_intrp.
        IF (ALLOCATED(vert_pottmps)) deallocate(vert_pottmps)
        allocate(vert_pottmps(iweg, isng, ibtg-1, times_in_file))
        vert_pottmps(:,:,:,:) = 0.0
        if(vcor .eq. 4) then
           call calcpot(ncid,iweg,isng,ibtg-1,times_in_file, &
                        tk,pres_field,qv,vert_pottmps)
        endif

        if(vcor .eq. 5) then
           call calceqpot(ncid,iweg,isng,ibtg-1,times_in_file, &
                          tk,pres_field,qv,vert_pottmps)
        endif


!Indicies used by the RIP part of the code in interpolation and extrapolation.
         mmax=max(iweg,isng)
         mabpl=max(mmax,min(2*mmax-1,401))
         morpl=max(max(iweg,isng),ibtg)+1
         mkzh = ibtg-1
         print *,"After calculating basic fields from input file"

!-----------------------------------------------------------------------------
!START PROCESSING FILE VARIABLES
        jvar = 3
        loop_variables : DO ivar = 1, nvars        
           rcode = nf_inq_var(ncid, ivar, cval, itype, idm, ishape, natt)
           if(rcode .ne. 0) then
              print *,"Error reading variable ",ivar," from file"
              stop
           end if
           wanted = 1
           call var_wanted(cval,idm,itype,wanted,unstagger_grid)
           if(wanted .eq. 0)  CYCLE loop_variables

           IF ( trim(cval) == 'U' ) then
               cval = 'UU'
               u_ivar = ivar
           END IF

           IF ( trim(cval) == 'V' ) then
               cval = 'VV'
               v_ivar = ivar
           END IF

           IF ( trim(cval) == 'TSK' ) cval = 'SKINTEMP'      
     
!!! OK - we want this - lets continue
           jvar = jvar + 1
           jshape = 0
           
           fix_meta_stag = .FALSE.
           rcode = nf_redef(mcid)
           interpolate = .FALSE.
           DO ii = 1, idm
              test_dim_name = dnamei(ishape(ii))
              new_dim = 0
              IF ( test_dim_name == 'bottom_top') THEN
                   test_dim_name = 'lev'
                   interpolate = .TRUE.
              ENDIF
              if(test_dim_name == 'bottom_top_stag') then
                   test_dim_name = 'lev'
                   interpolate = .TRUE.
                   fix_meta_stag = .TRUE.
              end if               
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
              DO jj = 1,ndims_out
                 IF ( test_dim_name == dnamej(jj) ) THEN
                    jshape(ii) = jj
                 ENDIF
              ENDDO

            ENDDO !end the idm loop


            rcode = nf_def_var(mcid, cval, itype, idm, jshape, jvar)
            if(rcode .ne. 0) then
               print *,"ERROR: Unable to write variable ",cval,"to output file"
               stop
            end if   

      
          DO na = 1, natt
             rcode = nf_inq_attname(ncid, ivar, na, cname)
             IF ( fix_meta_stag .AND. trim(cname) == 'stagger' ) THEN
                att_text = "-"
                ilen = len_trim(att_text)
                rcode = nf_put_att_text(mcid, jvar, cname, ilen, att_text(1:ilen) )
             ELSEIF ( fix_meta_stag .AND. trim(cname) == 'coordinates' ) THEN
                att_text = "XLONG XLAT"
                ilen = len_trim(att_text)
                rcode = nf_put_att_text(mcid, jvar, cname, ilen, att_text(1:ilen) )
             ELSE
                rcode = nf_copy_att(ncid, ivar, cname, mcid, jvar)
             ENDIF
          ENDDO
          rcode = nf_put_att_real(mcid, jvar, 'missing_value', NF_FLOAT, 1, MISSING )
          rcode = nf_enddef(mcid)


! GET THE DIMS FOR INPUT AND OUTPUT FROM THE SHAPE
          dims_in  = 1
          dims_out = 1
          DO ii = 1,idm
            dims_in(ii)  = dvali(ishape(ii))
            dims_out(ii) = dvalj(jshape(ii))
          ENDDO
          IF (debug) THEN
            write(6,*) 'VAR: ',trim(cval)
            write(6,*) '     DIMS  IN: ',dims_in
            write(6,*) '     DIMS OUT: ',dims_out
            write(6,*) '     JSHAPE  : ',jshape
          ENDIF
  

! ALLOCATE THE INPUT AND OUTPUT ARRAYS
! READ THE DATA FROM INPUT FILE
	  IF(itype == 2) THEN          ! character
            if(cval .ne. "Times") then
               allocate (text(dims_in(1), dims_in(2), dims_in(3), dims_in(4)))
	       rcode = nf_get_var_text(ncid, ivar, text)
	       rcode = nf_put_vara_text (mcid, jvar, start_dims, dims_in, text)
               IF (debug) write(6,*) '     SAMPLE VALUE = ',text(:,1,1,1)
               deallocate (text)
            end if
  
	  ELSEIF (itype == 4) THEN          ! integer
            allocate (idata1(dims_in(1), dims_in(2), dims_in(3), dims_in(4)))
	    rcode = nf_get_var_int(ncid, ivar, idata1)
	    rcode = nf_put_vara_int (mcid, jvar, start_dims, dims_in, idata1)
            deallocate (idata1)
  
  
	  ELSEIF (itype == 5) THEN          ! real
            if (allocated(data2)) deallocate(data2)
            if (allocated(data1)) deallocate(data1)
            allocate (data2(dims_out(1),dims_out(2),dims_out(3),dims_out(4)))
            allocate (data1(dims_in(1), dims_in(2), dims_in(3), dims_in(4)))
            rcode = nf_get_var_real(ncid, ivar, data1)



            IF (idm >= 4 .AND. interpolate) THEN  
               IF (debug) write(6,*) '     THIS IS A FIELD WE NEED TO INTERPOLATE'
               icase = 0
               IF ( dims_in(1) == iweg .AND. .not. unstagger_grid )  then
                   if (debug) then
                       print *,"UU staggered"
                   end if
                   allocate (flipp(dims_in(1), dims_in(2), dims_in(3), dims_in(4)))
                   cstag = "stagU  "
                   flipp = 0.0
                   do k=1,mkzh
                      flipp(:,:,k,:) = data1(:,:,mkzh-k+1,:)
                   end do
                   CALL special_intrp (data2,flipp,pres_field,tk,ght,qv,terrain,sfp,sfpsm,      &
                                       vert_pottmps,interp_levels,num_interp_levels,dims_in,     &
                                       dims_out,iweg,isng,ibtg-1,icase,mabpl,morpl,extrapolate, &
                                       MISSING,ncid,vcor,logp,cstag,times_in_file)
                   deallocate(flipp)
                   rcode = nf_put_vara_real (mcid, jvar, start_dims, dims_out, data2)
                   deallocate (data1)
                   deallocate (data2)

               ELSEIF ( dims_in(2) == isng .AND. .not. unstagger_grid )  then
                   if(debug) then
                     print *,"VV staggered"
                   end if
                   allocate (flipp(dims_in(1), dims_in(2), dims_in(3), dims_in(4)))
                   cstag = "stagV  "
                   flipp = 0.0
                   do k=1,mkzh
                      flipp(:,:,k,:) = data1(:,:,mkzh-k+1,:)
                   end do
                   CALL special_intrp (data2,flipp,pres_field,tk,ght,qv,terrain,sfp,sfpsm,      &
                                       vert_pottmps,interp_levels,num_interp_levels,dims_in,     &
                                       dims_out,iweg,isng,ibtg-1,icase,mabpl,morpl,extrapolate, &
                                       MISSING,ncid,vcor,logp,cstag,times_in_file)
                   deallocate(flipp)
                   rcode = nf_put_vara_real (mcid, jvar, start_dims, dims_out, data2)
                   deallocate (data1)
                   deallocate (data2)


               ELSEIF ( dims_in(1) == iweg .AND. unstagger_grid ) THEN
                   allocate (data3(iweg-1, isng-1, ibtg-1, dims_in(4)))
                   allocate (flipp(iweg-1, isng-1, dims_in(3), dims_in(4)))
                   dims_in(1) = iweg-1
                   dims_in(2) = isng-1
                   data3(1:iweg-1,:,:,:) = (data1(1:iweg-1,:,:,:) + data1(2:iweg,:,:,:)) * .5
                   cstag = "unstagU"
                   flipp = 0.0
                   do k=1,mkzh
                      flipp(:,:,k,:) = data3(:,:,mkzh-k+1,:)
                   end do
                   CALL special_intrp (data2,flipp,pres_field,tk,ght,qv,terrain,sfp,sfpsm,      &
                                       vert_pottmps,interp_levels,num_interp_levels,dims_in,     &
                                       dims_out,iweg,isng,ibtg-1,icase,mabpl,morpl,extrapolate, &
                                       MISSING,ncid,vcor,logp,cstag,times_in_file)
                   deallocate(flipp)
                   rcode = nf_put_vara_real (mcid, jvar, start_dims, dims_out, data2)
                   deallocate (data1)
                   deallocate(data3)

               ELSEIF ( dims_in(2) == isng .AND. unstagger_grid ) THEN 
                   cstag = "unstagV"
                   allocate (data3(iweg-1, isng-1, ibtg-1, dims_in(4)))
                   allocate (flipp(iweg-1, isng-1, dims_in(3), dims_in(4)))
                   dims_in(1) = iweg-1
                   dims_in(2) = isng-1                   
                   data3(:,1:isng-1,:,:) = (data1(:,1:isng-1,:,:) + data1(:,2:isng,:,:)) * .5
                   flipp = 0.0
                   do k=1,mkzh
                      flipp(:,:,k,:) = data3(:,:,mkzh-k+1,:)
                   end do
                   CALL special_intrp (data2,flipp,pres_field,tk,ght,qv,terrain,sfp,sfpsm,       &
                                       vert_pottmps,interp_levels,num_interp_levels,dims_in,     &
                                       dims_out,iweg,isng,ibtg-1,icase,mabpl,morpl,extrapolate,  &
                                       MISSING,ncid,vcor,logp,cstag,times_in_file)
                   deallocate(flipp)
                   rcode = nf_put_vara_real (mcid, jvar, start_dims, dims_out, data2)
                   deallocate (data1)
                   deallocate(data3)

               ELSEIF ( dims_in(3) == ibtg ) THEN
                   cstag = "unstag "
                   if (debug) then
                      print *,"Processing variable ",cval
                   end if
                   allocate (flipp(iweg-1, isng-1, ibtg-1, dims_in(4)))
                   allocate (data3(iweg-1, isng-1, ibtg-1, dims_in(4)))
                   dims_in(3) = ibtg-1
                   data3(:,:,1:ibtg-1,:) = (data1(:,:,1:ibtg-1,:) + data1(:,:,2:ibtg,:)) * .5
                   cstag = "unstag "
                   flipp = 0.0
                   do k=1,mkzh
                      flipp(:,:,k,:) = data3(:,:,mkzh-k+1,:)
                   end do
                   CALL special_intrp (data2,flipp,pres_field,tk,ght,qv,terrain,sfp,sfpsm,      &
                                       vert_pottmps,interp_levels,num_interp_levels,dims_in,    &
                                       dims_out,iweg,isng,ibtg-1,icase,mabpl,morpl,extrapolate, &
                                       MISSING,ncid,vcor,logp,cstag,times_in_file)
                   deallocate(flipp)
                   rcode = nf_put_vara_real (mcid, jvar, start_dims, dims_out, data2)
                   deallocate (data1)
                   deallocate(data3)

               ELSE
                  cstag = "unstag "
                  if(debug) then
                    print *,"Processing variable ",cval
                  end if
                  allocate (flipp(iweg-1, isng-1, dims_in(3), dims_in(4)))
                  flipp = 0.0
                  do k=1,mkzh
                      flipp(:,:,k,:) = data1(:,:,mkzh-k+1,:)
                  end do
                  CALL special_intrp (data2,flipp,pres_field,tk,ght,qv,terrain,sfp,sfpsm,        &
                                       vert_pottmps,interp_levels,num_interp_levels,dims_in,     &
                                       dims_out,iweg,isng,ibtg-1,icase,mabpl,morpl,extrapolate,  &
                                       MISSING,ncid,vcor,logp,cstag,times_in_file)
                 deallocate(flipp)
                 rcode = nf_put_vara_real (mcid, jvar, start_dims, dims_out, data2)
                 deallocate (data1)
                 deallocate (data2)
              END IF !This ends the if for idm greater than or equal to 4

            ELSEIF (idm == 3 .AND. unstagger_grid ) THEN
               IF ( dims_in(1) == iweg ) THEN
                  data2(1:iweg-1,:,:,:) = (data1(1:iweg-1,:,:,:) + data1(2:iweg,:,:,:)) * .5
                  rcode = nf_put_vara_real (mcid, jvar, start_dims, dims_out, data2)
               ELSEIF ( dims_in(2) == isng ) THEN
                  data2(:,1:isng-1,:,:) = (data1(:,1:isng-1,:,:) + data1(:,2:isng,:,:)) * .5
               ELSE
                  data2 = data1
               ENDIF
               rcode = nf_put_vara_real (mcid, jvar, start_dims, dims_out, data2)
               deallocate (data1)
               deallocate (data2)

	    ELSE
               data2 = data1
               rcode = nf_put_vara_real (mcid, jvar, start_dims, dims_out, data2)
               deallocate (data1)
               deallocate (data2)
	    ENDIF

          ENDIF
  
        ENDDO loop_variables 
!--------------------END PROCESSING OF FILE VARIABLES--------------`
!--------------------------------------------------------------------
!!! We have some special variables we are interested in: 
        IF ( debug ) print*," "
        IF ( debug ) print*,"Calculatng some diagnostics"
           
        jshape = 0
        DO ii = 1, 4
          IF ( ii == 1 ) test_dim_name = 'west_east'
          IF ( ii == 2 ) test_dim_name = 'south_north'
          IF ( ii == 3 ) test_dim_name = 'lev'
          IF ( ii == 4 ) test_dim_name = 'Time'
          DO jj = 1,ndims_out
            IF ( test_dim_name == dnamej(jj) ) THEN
              jshape(ii) = jj
            ENDIF
          ENDDO

          IF ( jshape(ii) == 0 ) THEN
            j = j + 1
            jshape(ii) = j
            dnamej(j) = dnamei(ishape(ii))
            dvalj(j) = dvali(ishape(ii))
            rcode = nf_def_dim(mcid, dnamej(j), dvalj(j), j)
          ENDIF
        ENDDO
        dims_in  = 1
        dims_out = 1
        DO ii = 1,4
          dims_out(ii) = dvalj(jshape(ii))
        ENDDO

!------------------------PRESSURE----------------------------------------
        if(vcor .ne. 1) then 
	   jvar = jvar + 1
           cval = "PRES"
           CALL def_var (mcid, jvar, cval, 5, 4, jshape, "XZY", "Pressure           ", "Pa", "-","XLONG XLAT")
           rcode = nf_redef(mcid)
           rcode = NF_PUT_ATT_REAL(mcid,jvar,'missing_value',NF_FLOAT,1,MISSING)
           rcode = nf_enddef(mcid)           

           IF (debug) THEN
                  write(6,*) 'VAR: PRES'
	          write(6,*) '     DIMS OUT: ',dims_out
           ENDIF

           allocate (data2(dims_out(1),dims_out(2),dims_out(3),dims_out(4)))
           icase = 0
           if((vcor .eq. 2) .and. (extrapolate .eq. 1)) then 
              print *,"interpolating pressure to height"
              icase = 5  
           end if

           dims_in(1) = iweg-1
           dims_in(2) = isng-1
           dims_in(3) = ibtg-1
           dims_in(4) = times_in_file             
           allocate (flipp(dims_in(1), dims_in(2), dims_in(3), dims_in(4)))
           flipp = 0.0
           do k=1,mkzh
              flipp(:,:,k,:) = pres_field(:,:,mkzh-k+1,:) * 0.01
           end do

           CALL special_intrp (data2,flipp,pres_field,tk,ght,qv,terrain,sfp,sfpsm,vert_pottmps,     &
                               interp_levels,num_interp_levels,dims_in,dims_out,iweg, isng,        &
                               ibtg-1,icase,mabpl,morpl,extrapolate,MISSING,ncid,vcor,logp,cstag,  &
                               times_in_file) 

           deallocate(flipp)       
           WHERE ( data2 < MISSING )
                     data2 = data2 * 100.  !Convert to Pa from hPa
           ENDWHERE
           rcode = nf_put_vara_real (mcid, jvar, start_dims, dims_out, data2)
           deallocate(data2)
        end if   !end if for vcor ne to 1   
  !-----------------------Relative Humidity----------------------------------------------------------
           jvar = jvar + 1
           cval = "RH"
           CALL def_var (mcid, jvar,cval, 5, 4, jshape, "XZY", "Relative Humidity  ", "% ", "-","XLONG XLAT")
           rcode = nf_redef(mcid)
           rcode = NF_PUT_ATT_REAL(mcid,jvar,'missing_value',NF_FLOAT,1,MISSING)
           rcode = nf_enddef(mcid)  
           IF (debug) THEN
             write(6,*) 'VAR: RH'
             write(6,*) '     DIMS OUT: ',dims_out
           ENDIF
           allocate (data2(dims_out(1),dims_out(2),dims_out(3),dims_out(4)))
           icase = 0
           dims_in(1) = iweg
           dims_in(2) = isng
           dims_in(3) = ibtg-1
           dims_in(4) = times_in_file


           CALL special_intrp (data2,rh,pres_field,tk,ght,qv,terrain,sfp,sfpsm,vert_pottmps,    &
                               interp_levels,num_interp_levels, dims_in,dims_out,iweg,isng,     &
                               ibtg-1,icase,mabpl,morpl,extrapolate,MISSING,ncid,vcor,logp,     &
                               cstag,times_in_file)

           WHERE ( data2 > 100.0 .and. data2 < 1000. )
              data2 = 100.0
           ENDWHERE
           rcode = nf_put_vara_real (mcid, jvar, start_dims, dims_out, data2)
           IF (debug) then
               write(6,*) "Wrote out Relative Humidity"
           end if 
           deallocate(data2)
!!------------------------TEMPERATURE----------------------------------------------
        jvar = jvar + 1
        cval = "TT"
        CALL def_var (mcid, jvar, cval, 5, 4, jshape, "XZY", "Temperature        ", "K ","-","XLONG XLAT")
        rcode = nf_redef(mcid)
        rcode = NF_PUT_ATT_REAL(mcid,jvar,'missing_value',NF_FLOAT,1,MISSING)
        rcode = nf_enddef(mcid)
        IF (debug) THEN
           write(6,*) 'VAR: TT'
           write(6,*) '     DIMS OUT: ',dims_out
        ENDIF
        allocate (data2(dims_out(1),dims_out(2),dims_out(3),dims_out(4)))
        icase = 1
        dims_in(1) = iweg
        dims_in(2) = isng
        dims_in(3) = ibtg-1
        dims_in(4) = times_in_file
        CALL special_intrp (data2,tk,pres_field,tk,ght,qv,terrain,sfp,sfpsm,vert_pottmps,   &
                            interp_levels,num_interp_levels, dims_in,dims_out,iweg, isng,   &
                            ibtg-1,icase,mabpl,morpl,extrapolate,MISSING,ncid,vcor,logp,    &
                            cstag,times_in_file)

        rcode = nf_put_vara_real (mcid, jvar, start_dims, dims_out, data2)
        if (rcode .ne. nf_noerr) call handle_err(rcode,"unable to put TT variable to out file")
!       IF (debug) write(6,*) "Wrote out temperature TT"
        deallocate(data2)


!----------------------Geopotential height-------------------------------------------------
        if((vcor .ne. 2) .and. (vcor .ne. 3)) then
            IF (debug) THEN
               write(6,*) 'VAR: GHT'
               write(6,*) '     DIMS OUT: ',dims_out
            ENDIF
           cval = "GHT"
           jvar = jvar + 1

           CALL def_var (mcid, jvar, cval, 5, 4, jshape, "XZY", "Geopotential Height","M ","-","XLONG XLAT")
  
           rcode = nf_redef(mcid)
           rcode = NF_PUT_ATT_REAL(mcid,jvar,'missing_value',NF_FLOAT,1,MISSING)
           rcode = nf_enddef(mcid)           

           dims_in(1) = iweg
           dims_in(2) = isng
           dims_in(3) = ibtg-1
           dims_in(4) = times_in_file
           allocate (data2(dims_out(1),dims_out(2),dims_out(3),dims_out(4)))
           icase = 2
           CALL special_intrp (data2,ght,pres_field,tk,ght,qv,terrain,sfp,sfpsm,vert_pottmps,     &
                               interp_levels,num_interp_levels,dims_in,dims_out,iweg,isng,       &
                               ibtg-1,icase,mabpl,morpl,extrapolate,MISSING,ncid,vcor,logp,        &
                               cstag,times_in_file)

           rcode = nf_put_vara_real (mcid, jvar, start_dims, dims_out, data2)
           IF (debug) THEN
               write(6,*) "Wrote out Geopotential Height"
           ENDIF
           deallocate(data2)           
           end if


!----------------Potential vorticity-------------------------------------------------------
          IF (debug) THEN
               write(6,*) 'VAR: Potential Vorticity'
               write(6,*) '     DIMS OUT: ',dims_out
          ENDIF
         allocate (pvo(iweg, isng, ibtg-1, times_in_file ))
         CALL calcpvo(pvo,pres_field,ncid,nvars,ibtg-1,isng,iweg,times_in_file, &
                     u_ivar, v_ivar,dx,dy)
        
        allocate (data2(dims_out(1),dims_out(2),dims_out(3),dims_out(4)))
        jvar = jvar + 1
        cval = "PVO"
        CALL def_var (mcid, jvar,cval, 5, 4, jshape, "XZY", "Potenial Vorticity  ", "PVU", "-","XLONG XLAT")
        rcode = nf_redef(mcid)
        rcode = NF_PUT_ATT_REAL(mcid,jvar,'missing_value',NF_FLOAT,1,MISSING)
        rcode = nf_enddef(mcid)  
        icase = 0
        dims_in(1) = iweg
        dims_in(2) = isng
        dims_in(3) = ibtg-1
        dims_in(4) = times_in_file        
        CALL special_intrp (data2,pvo,pres_field,tk,ght,qv,terrain,sfp,sfpsm,vert_pottmps,    &
                            interp_levels,num_interp_levels, dims_in,dims_out,iweg,isng,      &
                            ibtg-1,icase,mabpl,morpl,extrapolate,MISSING,ncid,vcor,logp,      &
                            cstag,times_in_file)

        rcode = nf_put_vara_real (mcid, jvar, start_dims, dims_out, data2)
        IF (debug) then
            write(6,*) "Wrote out Potential Voriticty"
        end if         
        deallocate(pvo)
        deallocate(data2)

!!-------------------DONE WITH SPECIAL VARIABLES-----------------------

        rcode = nf_close(ncid)
        rcode = nf_close(mcid)
      end do  !end of main loop over number of files
      


      deallocate(input_file_names)
      deallocate(output_file_names)
      print *,"-------------SUCCESS----------------"

 END PROGRAM wrf_interp
!---------------------------------------------------------------------
!---------------------------------------------------------------------
!---------------------------------------------------------------------
 SUBROUTINE read_namelist(path_to_input,path_to_output,interp_levels,extrapolate, &
                          unstagger_grid,vcor,num_interp_levels,number_of_input_files, &
                          leap_year,debug,logp)


      implicit none
      integer                           :: startl,rootl,negindex,addinc,tempindex
      integer                           :: funit,grid_id,ios,loslen,itemp,lent
      integer                           :: extrapolate,vcor,number_of_input_files
      integer                           :: numchar,year,mo,day,hr,done,index
      integer                           :: num_interp_levels,logp
      real, dimension(99)               :: interp_levels,temp_level
      real                              :: begv,endv,inc
      character (len=250)               :: path_to_input,format_string
      character (len=250)               :: path_to_output
      character (len=250)               :: root_name,input_name
      character (len=8)                 :: vert_coordinate
      character (len=132)               :: command
      character (len=4)                 :: cyear
      character (len=2)                 :: twocs
      character (len=19)                :: start_date     !Dates are 19 characters long
      logical                           :: leap_year
      logical                           :: unstagger_grid
      logical                           :: is_used,debug

      NAMELIST /io/ path_to_input,path_to_output,root_name,grid_id,start_date,leap_year,debug
      NAMELIST /interp_in/ interp_levels,extrapolate,unstagger_grid,vert_coordinate


      ! Read parameters from Fortran namelist
        DO funit=10,100
           INQUIRE(unit=funit, opened=is_used)
           IF (.not. is_used) EXIT
        END DO
        OPEN(funit,file='namelist.vinterp',status='old',form='formatted',iostat=ios)
        IF ( ios /= 0 ) STOP "ERROR opening namelist.vinterp"
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

      ! Find the levels to interpolate to
      if(vert_coordinate .eq. "pressure")then
         write(6,*)
         write(6,*) "INTERPOLATING TO PRESSURE LEVELS: "
         vcor = 1
      end if

      if(vert_coordinate .eq. "pres")then
         write(6,*)
         write(6,*) "INTERPOLATING TO PRESSURE LEVELS: "
         vcor = 1
      end if

      if(vert_coordinate .eq. "log_pres")then
         write(6,*)
         write(6,*) "INTERPOLATING TO LOG OF PRESSURE LEVELS: "
         vcor = 1
         logp = 1
      end if

      if(vert_coordinate(1:7) .eq. "ght_msl") then
         write(6,*)
         write(6,*) "INTERPOLATING TO HEIGHT: "
         vcor = 2
      end if 

      if(vert_coordinate(1:7) .eq. "ght_agl") then
         write(6,*)
         write(6,*) "INTERPOLATING TO HEIGHT: "
         vcor = 3
      end if 


      if(vert_coordinate(1:5) .eq. "theta") then
          if(vert_coordinate(1:7) .eq. "theta-e") then
             write(6,*)
             write(6,*) "INTERPOLATING TO EQUIVALENT POTENTIAL TEMPERATURE: "
             vcor = 5
          else
             write(6,*)
             write(6,*) "INTERPOLATING TO POTENTIAL TEMPERATURE: "
             vcor = 4             
          end if              
      end if 


      if(vcor .eq. 0) then
         print *,"Undefined vertical coordinate"
         print *,"Choices are:"
         print *,"             pressure(hPa)"
         print *,"             log_pres(hPa)"
         print *,"             ght_msl (km)"
         print *,"             ght_agl (km)"
         print *,"             theta(K)"
         print *,"             theta-e(K)"
         stop
      end if

!Get the intrepolation levels.
!First see if we have any negative values which would mean
!we need to calculate the interpolation levels from a 
!beginning value an ending value and an increment.
         index = 1
         done = 0
         negindex = 0
         do while( done .eq. 0)
             if( interp_levels(index) .eq.  -99999.) then
                 done = 1
             else
                 if(interp_levels(index) .lt. 0.0) then
                    negindex = index
                 end if
                 index = index + 1
             end if
         end do

         if(index .eq. 0) then
            print *,"Error reading interpolation level information"
            stop
         end if

         if(negindex .eq. 0) then
            num_interp_levels = index - 1
         else
            addinc = 1
            begv = interp_levels(negindex - 1)
            endv = -interp_levels(negindex)
            inc  = interp_levels(negindex+1)
            print *,begv,endv,inc
            if(begv .gt. endv) addinc = -1
            done = 0
            index = 2
            num_interp_levels = negindex 
            temp_level(1) = begv
            do while (done .eq. 0)
               if(addinc .eq. -1) then
                  temp_level(index) = temp_level(index-1) - inc
                  if(temp_level(index) .lt. endv) then
                      done = 1
                  else
                      interp_levels(num_interp_levels) = temp_level(index)
                      num_interp_levels = num_interp_levels + 1
                      index = index + 1
                  end if
               else
                  temp_level(index) = temp_level(index-1) + inc
                  if(temp_level(index) .gt. endv) then
                     done = 1
                  else
                     interp_levels(num_interp_levels) = temp_level(index)
                     num_interp_levels = num_interp_levels + 1
                     index = index + 1
                  end if
               end if
            end do
            num_interp_levels = num_interp_levels - 1

           end if !if for negindex
 
           print *,"---------------------"


         if(num_interp_levels .eq. 1) then
            print *," You need at least two interpolation levels"
            stop
         end if
            
         do index = 1,num_interp_levels
               print *,index,interp_levels(index)
         end do

!Start building the file name from the namelist parameters grid_id and start_date
        root_name = TRIM(path_to_input)//TRIM(root_name)
        rootl  = LEN_TRIM (root_name)
        startl = LEN_TRIM (start_date)
        
        rootl = rootl + 1
        numchar = rootl + 5
        if(grid_id .eq. 1) then
           root_name(rootl:numchar) = "_d01_"
        else if (grid_id .eq. 2) then
           root_name(rootl:numchar) = "_d02_"
        else if (grid_id .eq. 3) then
           root_name(rootl:numchar) = "_d03_"
        else
           print *,"Invlaid grid_id in namelist.vinterp"
           print *,"Valid grid_id's are 1 2 or 3"
           print *,"If you have more than three nests please modify the code in read_namelist"
           stop
        end if
        rootl = rootl + 5
        

       
!Build the date and time
         if(startl .eq. 19) then  !we have the entire date
            root_name(rootl:rootl+19) = start_date(1:19)
         else
            root_name(rootl:rootl+startl) = start_date(1:startl)
            rootl = rootl + startl
            root_name(rootl:rootl) = '*'
         end if

        !  Build a UNIX command, and "ls", of all of the input files 
        loslen = LEN ( command )
        CALL all_spaces ( command , loslen )
        WRITE ( command , FMT='("ls -1 ",A," > .foo")' ) TRIM ( root_name )
           
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
  
        !  If there are zero files, we are toast.
        IF ( number_of_input_files .LE. 0 ) THEN
           print*, ' Oops, we need at least ONE input file for the program to read.'
           print*, '       Make sure you have the path, and name file(s) correct,'
           print*, '       including wild characters if needed.'
           STOP
        END IF
  
 

      write(6,'(A,$)') " INTERPOLATION METHOD: "
      IF (extrapolate == 0) write(6,*)"BELOW GROUND will be set to missing values"
      IF (extrapolate == 0) write(6,*)"ABOVE model top will be set to missing values"
      IF (extrapolate == 1) write(6,*)"BELOW GROUND will be extrapolated"
      IF (extrapolate == 1) write(6,*)"ABOVE model top will be set to values at model top"
      IF (.not. unstagger_grid) write(6,*)"Data will be output on C-grid" 
      IF (unstagger_grid) write(6,*)"Data will be output on unstaggered grid"



 END SUBROUTINE read_namelist


!--------------------------------------------------------------------- 
 SUBROUTINE basic_fileinfo(ncid,ndims,nvars,ngatts,iweg,isng,ibtg,dx,dy)


    implicit none
    integer ncid,ndims,nvars,ngatts,iweg,isng,ibtg
    integer nunlimdimid
    integer rcode
    real    dx,dy
    logical debug


    include './netcdf.inc'

!   ndims:  number of dimensions
!   nvars:  number of variables
!   ngatts: number of global attributes

    debug = .FALSE.
    
    rcode = nf_inq(ncid, ndims, nvars, ngatts, nunlimdimid)
    if (rcode .ne. nf_noerr) call handle_err(rcode)
    IF (debug) THEN
        write(6,*) ' INPUT file has = ',ndims, ' dimensions, '
        write(6,*) '                  ',nvars, ' variables, and '      
        write(6,*) '                  ',ngatts,' global attributes '
        write(6,*) "  "
    ENDIF

    rcode = nf_get_att_int  (ncid, nf_global, 'WEST-EAST_GRID_DIMENSION', iweg)
    if (rcode .ne. nf_noerr) then
        print *,"ERROR: Unable read grid dimensions"
        stop
    endif

    rcode = nf_get_att_int  (ncid, nf_global, 'SOUTH-NORTH_GRID_DIMENSION', isng)
    if (rcode .ne. nf_noerr) then
        print *,"ERROR: Unable read grid dimensions"
        stop
    endif

    rcode = nf_get_att_int  (ncid, nf_global, 'BOTTOM-TOP_GRID_DIMENSION', ibtg)
    if (rcode .ne. nf_noerr) then
        print *,"ERROR: Unable read grid dimensions"
        stop
    endif

    rcode = nf_get_att_real (ncid, nf_global, 'DX', dx)
    if (rcode .ne. nf_noerr) then
        print *,"ERROR: Unable read grid spacing"
        stop
    endif

    rcode = nf_get_att_real (ncid, nf_global, 'DY', dy)
    if (rcode .ne. nf_noerr) then
        print *,"ERROR: Unable read grid spacing"
        stop
    endif            
    
 END SUBROUTINE basic_fileinfo

!------------------------------------------------------------------------------
  SUBROUTINE  outfile_attributes(ncid,mcid,debug,ngatts,num_interp_levels)

     implicit none
     INCLUDE './netcdf.inc'

     integer             :: ncid,mcid,ngatts,rcode,i,ilen,itype
     integer             :: ival,num_interp_levels
     real                :: rval
     logical             :: debug
     character(len=80)   :: cval
     character(len=31)   :: cname


! DEALING WITH THE GLOBAL ATTRIBUTES
        IF (debug) THEN
          write(6,*) 
          write(6,*) " OUTPUT FILE attributes:"
        ENDIF
        do i = 1, ngatts
          rcode = nf_inq_attname(ncid, nf_global, i,    cname)
          rcode = nf_inq_atttype(ncid, nf_global, cname, itype)
          rcode = nf_inq_attlen (ncid, nf_global, cname, ilen)
  
	  if ( itype .eq. 2 ) then        ! characters
	    rcode = nf_get_att_text (ncid, nf_global, cname, cval)
	    if(cname(1:5) .eq. 'TITLE') then
               cval = cval(1:ilen)//" - ON PRES LEVELS"
               ilen = len_trim(cval)
            endif
            IF (debug) &
	      write(6,'("     i = ",i2," : ",A," = ",A)') &
                    i,cname,cval(1:ilen)
	    rcode = nf_put_att_text(mcid, nf_global, cname, ilen,&
                      cval(1:ilen))
  
	  elseif ( itype .eq. 4 ) then     ! integers
	    rcode = nf_get_att_int (ncid, nf_global, cname, ival)
            IF ( INDEX(cname,'BOTTOM-TOP_PATCH') == 0 ) THEN
	       IF (cname .eq. 'BOTTOM-TOP_GRID_DIMENSION') ival = num_interp_levels
               IF (debug) &
	         write(6,'("     i = ",i2," : ",A," = ",i7)') &
                       i,cname,ival        
               rcode = nf_put_att_int(mcid, nf_global, cname, itype,&
                         ilen, ival)
             ENDIF
  
	  elseif ( itype .eq. 5 ) then    ! real
	    rcode = nf_get_att_real (ncid, nf_global, cname, rval)
            IF (debug) &
	      write(6,'("     i = ",i2," : ",A," = ",G18.10E2)') &
                    i,cname,rval
	    rcode = nf_put_att_real(mcid, nf_global, cname, itype,&
                      ilen, rval)
	  end if
        enddo


 END SUBROUTINE outfile_attributes
!--------------------------------------------------------------------- 
 SUBROUTINE var_wanted(cval,idm,itype,wanted,unstagger_grid)

   implicit none
   character (len=80)  :: cval
   integer             :: itype,idm,wanted
   logical             :: unstagger_grid

!!! Do we want this variable
    IF ( trim(cval) == 'P'  .OR. trim(cval) == 'PB' ) then
         wanted = 0
         return
    end if
    IF ( trim(cval) == 'PH' .OR. trim(cval) == 'PHB' )  then
         wanted = 0
         return
    end if
    IF ( trim(cval) == 'T' ) then
         wanted = 0
         return
    end if
    IF ( unstagger_grid .AND. (INDEX(cval,'_U') /= 0) ) then
         wanted = 0
         return
    end if

    IF ( unstagger_grid .AND. (INDEX(cval,'_V') /= 0) ) then
         wanted = 0
         return
    end if

!We don't need the eta value variables anymore.  The geopotential height is
!interpolated to mass points in calcght.
     if((cval(1:2) == 'ZN') .or.  (cval(1:2) == 'DN')) then
         wanted = 0 
         return
     end if
      

!We have already taken care of the Times variable
     if(cval(1:5) == 'Times') then
        wanted = 0  
        return
     end if

     if(cval(1:5) == 'time')  then
        wanted = 0
        return
     end if

     IF ( idm >= 4 .AND. itype == 4 ) THEN
            print*,"NOTE: We cannot deal with 3D integers - maybe later"
            wanted = 0
            return
     ENDIF

     IF ( itype == 6 ) THEN
            print*,"NOTE: We cannot deal with double precision data - maybe later"
            wanted = 0
            return
     ENDIF


     IF ( itype == 2 .OR. itype == 4 .OR. itype == 5 ) THEN
          wanted = 1
          return
     ELSE
          print*,"NOTE: Do not understand this data type ", itype, " skip field."
          wanted = 0
          return
     ENDIF  

 END SUBROUTINE var_wanted
 
!--------------------------------------------------------------------- 
 SUBROUTINE handle_err(rcode)
    INTEGER rcode
    write(6,*) 'Error number ',rcode
    stop
 END SUBROUTINE


!------------------------------------------------------------------------------
 FUNCTION virtual (tmp,rmix)
!      This function returns virtual temperature in K, given temperature
!      in K and mixing ratio in kg/kg.

     real                              :: tmp, rmix, virtual

     virtual=tmp*(0.622+rmix)/(0.622*(1.+rmix))

 END FUNCTION virtual
!------------------------------------------------------------------------------
 FUNCTION bes(x)

     real rint,bes,x,u
     integer i
     rint=0.
      do i=1,1000
         u=i*.001-.0005
         rint=rint+sqrt(1.-u*u)*cos(x*u)*.001
      enddo
      bes=2.*x*rint/(4.*atan(1.))
      return
  END FUNCTION bes

!------------------------------------------------------------------------------
!
!This subroutine was taken from the RIP code. 
  SUBROUTINE monotonic(out,in,lvprs,coriolis,idir,delta,iweg,isng,nz,it, &
                       times_in_file,icorsw)

      implicit none

      integer idir,iweg,isng,nz,k300,it,icorsw,ripk,times_in_file
      real, DIMENSION(iweg-1,isng-1,nz)                  :: lvprs,in
      real, DIMENSION(iweg,isng,nz,times_in_file)        :: out
      real, DIMENSION(iweg-1,isng-1)                     :: coriolis     
      real  delta

      integer i,j,k

      do j=1,isng-1
      do i=1,iweg-1
          if (icorsw.eq.1.and.coriolis(i,j).lt.0.) then
             do k=1,nz
                in(i,j,k)=-in(i,j,k)
              enddo
          endif

!
!   First find k index that is at or below (height-wise) the 300 hPa
!      level.
!
      do k = 1,nz
         ripk =  nz-k+1
         if (lvprs(i,j,ripk).ge.300.) then
            k300=k
            goto 40
         endif
      enddo
!
 40   continue

      out(i,j,k300,it) = in(i,j,k300)

      do k = k300-1, 1,-1
         if (idir.eq.1) then
            out(i,j,k,it)=max(in(i,j,k),in(i,j,k+1)+delta)
         elseif (idir.eq.-1) then
            out(i,j,k,it)=min(in(i,j,k),in(i,j,k+1)-delta)
         endif
      enddo

      do k = k300+1, nz
         if (idir.eq.1) then
            out(i,j,k,it)=min(in(i,j,k),in(i,j,k-1)-delta)
         elseif (idir.eq.-1) then
            out(i,j,k,it)=max(in(i,j,k),in(i,j,k-1)+delta)
         endif
      enddo
!
      
      enddo
      enddo
      return

  END SUBROUTINE monotonic
!-----------------------------------------------------------------------------
  SUBROUTINE vcord_array(prs,ght,pot_temps,vcarray,iweg,isng,nz, &
                         times_in_file,ncid,cstag,vcor)
!
!prs     - original pressure from the WRF input file
!ripght  - This is geopotential height.  It has been interpolated to
!        - to mass levels and flipped in calcght.  Units are in meters.
!vcarray - This is the output vertical coordinate array which will
!          be have either intpolated pressure of height depending 
!          on what the user has requested.


      implicit none  

      integer                                               :: isng,iweg,nz,it,vcor,ncid
      integer                                               :: times_in_file
      real, DIMENSION(iweg-1, isng-1, nz, times_in_file )   :: prs   
      real, DIMENSION(iweg,isng,nz,times_in_file)           :: ght
      real, DIMENSION(iweg-1,isng-1)                        :: terrain
      real, DIMENSION(iweg,isng,nz,times_in_file)           :: vcarray,pot_temps
      real, ALLOCATABLE,DIMENSION(:,:,:,:)                  :: temp
      real, ALLOCATABLE,DIMENSION(:,:)                      :: stag_ter_hgt
      real                                                  :: rgas,sclht
      CHARACTER (LEN=7)                                     :: cstag       

      integer ripk,mkzh,i,j,k,idir,icorsw,kvalue,height
      real    delta,eps,qmax,tmpk,p,tlclc1,tlclc2,tlclc3,tlclc4
      real    thtecon1,thtecon2,thtecon3,e,tlcl,ghtagl



      rgas     = 287.04     !J/K/kg
      sclht    = rgas*256./9.81

      height = 0
      if (vcor .eq. 2) then
         call getterrain(ncid,iweg,isng,times_in_file,terrain)
         height = 1
      else if (vcor .eq. 3) then
         call getterrain(ncid,iweg,isng,times_in_file,terrain)
         height = 1
      end if


      vcarray(:,:,:,:) = 0.0
      if((cstag .eq. "stagU  ") .and. (vcor .eq. 1)) then
!Interpolate pressure to the staggered U grid. (iweg,isng-1,:,:)
         allocate (temp(iweg, isng-1, nz, times_in_file))
         temp(1,:,:,:)        =  prs(1,:,:,:)    
         temp(iweg,:,:,:)     =  prs(iweg-1,:,:,:) 
         temp(2:iweg-1,:,:,:) = (prs(1:iweg-2,:,:,:) + prs(2:iweg-1,:,:,:))*.5

         do it = 1,times_in_file
            do k=1,nz
               ripk = nz-k+1
               do j=1,isng-1
               do i=1,iweg
                  vcarray(i,j,k,it) = temp(i,j,ripk,it)
               enddo
               enddo
           enddo
         end do
         deallocate(temp)
         return 
      end if       


      if((cstag .eq. "stagV  ") .and. (vcor .eq. 1)) then
!Interpolate pressure to the staggered V grid. (iweg-1,isng,:,:)
         allocate (temp(iweg-1, isng, nz, times_in_file))
         temp(:,1,:,:)        =  prs(:,1,:,:)    
         temp(:,isng,:,:)     =  prs(:,isng-1,:,:) 
         temp(:,2:isng-1,:,:) = (prs(:,1:isng-2,:,:) + prs(:,2:isng-1,:,:))*.5  

         do it = 1,times_in_file
            do k=1,nz
               ripk = nz-k+1
               do j=1,isng
               do i=1,iweg-1
                  vcarray(i,j,k,it) = temp(i,j,ripk,it)
               enddo
               enddo
            end do
         enddo 
         deallocate(temp)
         return
      end if
    

      if((cstag .eq. "stagU  ") .and. (height .eq. 1)) then
!Interpolate grid point height to the staggered U grid. (iweg,isng-1,:,:)
         allocate (temp(iweg, isng-1, nz, times_in_file))
         temp(1,:,:,:)        =  ght(1,:,:,:)    
         temp(iweg,:,:,:)     =  ght(iweg-1,:,:,:) 
         temp(2:iweg-1,:,:,:) = (ght(1:iweg-2,:,:,:) + ght(2:iweg-1,:,:,:))*.5   

         allocate (stag_ter_hgt(iweg, isng-1))
         stag_ter_hgt(1,:)    = terrain(1,:)
         stag_ter_hgt(iweg,:) = terrain(iweg-1,:)
         stag_ter_hgt(2:iweg-1,:) = (terrain(1:iweg-2,:) + terrain(2:iweg-1,:))*.5 

      
         do it = 1,times_in_file
            do k=1,nz
               do j=1,isng-1
                do i=1,iweg
                   if(vcor .eq. 2) then 
                      vcarray(i,j,k,it) = exp(-temp(i,j,k,it)/sclht)
                   else
                      ghtagl = temp(i,j,k,it) - stag_ter_hgt(i,j)
                      vcarray(i,j,k,it) = exp(-ghtagl/sclht) 
                  end if
               enddo
             enddo
           enddo  
         end do
         deallocate(temp)
         deallocate(stag_ter_hgt)
         return        
      end if       



      if((cstag .eq. "stagV  ") .and. (height .eq. 1)) then
!Interpolate grid point height to the staggered V grid. (iweg-1,isng,:,:)
         allocate (temp(iweg-1, isng, nz, times_in_file))
         temp(:,1,:,:)        =  ght(:,1,:,:)
         temp(:,isng,:,:)     =  ght(:,isng-1,:,:) 
         temp(:,2:isng-1,:,:) =  (ght(:,1:isng-2,:,:) + ght(:,2:isng-1,:,:))*.5   

         allocate (stag_ter_hgt(iweg-1, isng))
         stag_ter_hgt(:,1)    = terrain(:,1)
         stag_ter_hgt(:,isng) = terrain(:,isng-1)
         stag_ter_hgt(:,2:isng-1) = (terrain(:,1:isng-2) + terrain(:,2:isng-1))*.5 

         do it = 1,times_in_file
            do k=1,nz
               do j=1,isng
                  do i=1,iweg-1
                     if(vcor .eq. 2) then 
                        vcarray(i,j,k,it) = exp(-temp(i,j,k,it)/sclht)
                     else
                        ghtagl = temp(i,j,k,it) - stag_ter_hgt(i,j) 
                        vcarray(i,j,k,it) = exp(-ghtagl/sclht)
                     end if
                 enddo
              enddo
             enddo  
          enddo
          deallocate(temp)
          deallocate(stag_ter_hgt)
          
          return
      end if
    

      if((cstag .eq. "stagU  ") .and. ( vcor .gt. 3)) then
!Interpolate potential temperature  to the staggered U grid. (iweg,isng-1,:,:)
         pot_temps(:,1:isng,:,:)      =  pot_temps(:,1:isng-1,:,:)
         vcarray(1,:,:,:)           =  pot_temps(1,:,:,:) 
         vcarray(iweg,:,:,:)        =  pot_temps(iweg-1,:,:,:) 
         vcarray(2:iweg-1,:,:,:)    = (pot_temps(1:iweg-2,:,:,:) + pot_temps(2:iweg-1,:,:,:))*.5 
         return        
      end if       


      if((cstag .eq. "stagV  ") .and. (vcor .gt. 3)) then
!Interpolate potential temperature  to the staggered V grid. (iweg,isng-1,:,:)
         pot_temps(iweg,:,:,:)   =  pot_temps(iweg-1,:,:,:)
         vcarray(:,1,:,:)        =  pot_temps(:,1,:,:)
         vcarray(:,isng,:,:)     =  pot_temps(:,isng-1,:,:) 
         vcarray(:,2:isng-1,:,:) =  (pot_temps(:,1:isng-2,:,:) + pot_temps(:,2:isng-1,:,:))*.5  
         return        
      end if       



      if(cstag(1:6) .eq. "unstag") then
         if (vcor .eq. 1) then
           do it = 1,times_in_file
              do k=1,nz
                 ripk = nz-k+1
                 do j=1,isng-1
                 do i=1,iweg-1
                    vcarray(i,j,k,it) =  prs(i,j,ripk,it)
                 enddo
                 enddo
              enddo
           enddo  
           return          
        else if (vcor .eq. 2) then
          do it = 1,times_in_file
             do k=1,nz
                do j=1,isng-1
                 do i=1,iweg-1
                    vcarray(i,j,k,it) = exp(-ght(i,j,k,it)/sclht)
                 enddo
                  enddo
              enddo 
          end do
          return    
        else if (vcor .eq. 3) then
          do it = 1,times_in_file
             do k=1,nz
                do j=1,isng-1
                do i=1,iweg-1
                   ghtagl  =  ght(i,j,k,it) - terrain(i,j)
                   vcarray(i,j,k,it) = exp(-ghtagl/sclht)
                enddo
               enddo
            enddo
          enddo 
          return
       else if (vcor .gt. 3) then
          vcarray(:,:,:,:) = pot_temps(:,:,:,:)
          return
       end if
     end if !unstag if


  END SUBROUTINE vcord_array
!
!------------------------------------------------------------------------------
  FUNCTION intrp_value (wvalp0,wvalp1,vlev,vcp0,vcp1,icase,ixjs)

      real    wvalp0,wvalp1,vlev,vcp0,vcp1,intrp_value
      real    valp0,valp1,rvalue,rgas,ussalr,sclht
      integer icase,ixjs,logp


      rgas    = 287.04     !J/K/kg
      ussalr  = .0065      ! deg C per m
      sclht   = rgas*256./9.81

      valp0 = wvalp0
      valp1 = wvalp1
      if ( icase .eq. 2) then  !GHT
           valp0=exp(-wvalp0/sclht)
           valp1=exp(-wvalp1/sclht)
      end if


      rvalue = (vlev-vcp0)*(valp1-valp0)/(vcp1-vcp0)+valp0
      if (icase .eq. 2) then  !GHT
          ixjs = 1
          intrp_value = -sclht*log(rvalue)
      else 
          intrp_value = rvalue
      endif
     
      return
      END FUNCTION intrp_value

!------------------------------------------------------------------------------
!all of this subroutine was taken from RIP's vinterp.f
!
 SUBROUTINE special_extrapolation(prs,ght,tk,qv,tempout,terrain,sfp,sfpsm,     &
                                  vlev,iweg,isng,nz,it,ii,jj,mabpl,morpl,vcor, &
                                  icase,ncid,rmsg,cvcord)

      implicit none
      integer                              ::iweg,isng,nz,mabpl,morpl
      integer ii,jj,i,j,k,l,mjx,miy,mkzh,vcor,isign,it,ncid,kup,kval,pkup
      integer icase,rcode,ivar,logp
      real, DIMENSION(iweg-1,isng-1,nz,it) :: prs,qv
      real, DIMENSION(iweg,isng,nz,it)     :: ght,tk
      real                                 :: tempout(mabpl,morpl)
      real, DIMENSION(isng,iweg,it)        :: sfpsm,sfp
      real, DIMENSION(iweg-1,isng-1)       :: terrain
      real                                 :: virtual,tv
      real diff,rgas,sclht,height,beszero
      real rint,ripbes,rarg,ezsurf,psurfsm,zsurf 
      real pbot,zbot,tbotextrap,tvbotextrap
      real ussalr,expon,exponi,ptarget,dp,dpmin
      real plhsl,zlhsl,ezlhsl,tlhsl,psurf,rmsg
      real ezlev,plev,zlev,maxqvp,eps,tlev,qvlev,rhone,rhtwo
      real vlev,qvapor
      character cvcord*1


      include  './netcdf.inc'
     
      rgas    = 287.04     !J/K/kg
      ussalr  = .0065      ! deg C per m
      sclht   = rgas*256./9.81
      expon=rgas*ussalr/9.81
      exponi=1./expon
      mjx  = iweg
      miy  = isng
      mkzh = nz

!------------------------------------------------------------------------------
!Code taken from RIP vinterp.f
!
      plhsl   = prs(jj,ii,1,it)
      zlhsl   = ght(jj,ii,mkzh,it)
      ezlhsl  = exp(-zlhsl/sclht)
      tlhsl   = tk(jj,ii,mkzh,it)
      
      psurf   = sfp(ii,jj,it)
      psurfsm = sfpsm(ii,jj,it)
      zsurf   = terrain(jj,ii)
      ezsurf  =exp(-zsurf/sclht)
!      print *,"ght tmp ter ",zlhsl,tlhsl,zsurf


      if ((cvcord.eq.'p'.and.vlev.lt.psurf) .or. (cvcord.eq.'z'.and.vlev.lt.ezsurf)) then

!      
!      We are below the lowest data level but above the ground.
!      Use linear interpolation (linear in prs and exp-height).
!
        if(cvcord .eq. 'p') then 
            plev = vlev 
            ezlev=((plev-plhsl)*ezsurf+(psurf-plev)*ezlhsl)/(psurf-plhsl)
            zlev=-sclht*log(ezlev)
            if (icase .eq. 2) then
               tempout(jj,ii) = zlev
               return
            endif
        elseif(cvcord .eq. 'z') then
            ezlev=vlev
            zlev=-sclht*log(ezlev)
            plev=((ezlev-ezlhsl)*psurf+(ezsurf-ezlev)*plhsl)/(ezsurf-ezlhsl)  
            if(icase .eq. 5) then
               tempout(jj,ii) = plev
               return
            endif
         end if           
!
     else

!
!      We are below both the ground and the lowest data level.
!
!     First, find the model level that is closest to a "target" pressure
!     level, where the "target" pressure is delta-p less that the local
!     value of a horizontally smoothed surface pressure field.  We use
!     delta-p = 150 hPa here. A standard lapse rate temperature profile
!     passing through the temperature at this model level will be used
!     to define the temperature profile below ground.  This is similar
!     to the Benjamin and Miller (1990) method, except that for
!     simplicity, they used 700 hPa everywhere for the "target" pressure.
!
         ptarget=psurfsm-150.
         dpmin=1.e4
         do k=1,mkzh
            kval = mkzh-k+1
            dp=abs(prs(jj,ii,kval,it)-ptarget)
            if (dp .gt. dpmin) then
                goto 100
            end if
            dpmin=min(dpmin,dp)
         enddo
 100     kup = k-1
!        
         pkup  =  mkzh-kup+1
         pbot=max(plhsl,psurf)
         zbot=min(zlhsl,zsurf)
         tbotextrap=tk(jj,ii,kup,it)*(pbot/prs(jj,ii,pkup,it))**expon
         qvapor = qv(jj,ii,1,it)
         tvbotextrap=virtual(tbotextrap,max(qvapor,1.e-15))
         if (cvcord .eq. 'p') then
             plev=vlev
             zlev=zbot+tvbotextrap/ussalr*(1.-(vlev/pbot)**expon)
             if(icase .eq. 2) then
                tempout(jj,ii)=zlev
                return
             end if
         elseif (cvcord .eq. 'z') then
            zlev=-sclht*log(vlev)
            plev=pbot*(1.+ussalr/tvbotextrap*(zbot-zlev))**exponi 
            if(icase .eq. 5) then
               tempout(jj,ii) = plev
               return
            end if   
         end if

       end if !for the else below ground and lowest

       if (icase .eq. 1) then
!
!      One of the temperature fields was requested.  Extrapolate from
!      T at the lowest model level using US standard lapse rate.
!      Assume qv at the requested level is the same as at the lowest
!      model level.
!
         tlev=tlhsl+(zlhsl-zlev)*ussalr
         qvlev= max(qv(jj,ii,1,it),1.e-15)
         tempout(jj,ii)=tlev
       end if !icase = 2 or temperature


 END SUBROUTINE special_extrapolation

!----------------------------------------------------------------------------------
 SUBROUTINE special_intrp(dataout,datain,prs,tk,ght,qv,terrain,sfp,sfpsm,vert_pottmps, &
                          interp_levels,numlevels,dims_in,dims_out,iweg,isng,nz,       &
                          icase,mabpl,morpl,extrapolate,rmsg,ncid,vcor,logp,cstag,     &
                          times_in_file)


      implicit none
      integer                                                          :: iweg,isng,nz
      integer                                                          :: mabpl,morpl,vcor
      integer                                                          :: numlevels,extrapolate
      integer                                                          :: ncid,logp,times_in_file
      integer                                                          :: dims_in(4),dims_out(4)
      real, DIMENSION(dims_out(1),dims_out(2),dims_out(3),dims_out(4)) :: dataout
      real, DIMENSION(dims_in(1),dims_in(2),dims_in(3),dims_in(4))     :: datain
      real, DIMENSION(iweg-1, isng-1, nz,dims_out(4) )                 :: prs,qv,prshpa
      real, DIMENSION(iweg, isng, nz,dims_out(4) )                     :: tk,ght,vert_pottmps
      real, DIMENSION(isng,iweg,dims_in(4))                            :: sfp,sfpsm
      real, DIMENSION(iweg-1,isng-1)                                   :: terrain
      real, DIMENSION(numlevels)                                       :: interp_levels
      real                                                             :: vlev,rmsg
      CHARACTER (LEN=7)                                                :: cstag
      
      
      integer i,j,k,l,mjx,miy,mkzh,isign
      integer njx,niy,jj,ii,ixjs,jjph,jjmh,rcode
      integer ifound,icase,numpas,idist,nfp,dist
      integer iiph,iimh,iyis,smloop
      integer kup,nreqlvs,it
      integer ivar,kindex,STAT,allocatestatus,itriv
      real, DIMENSION(iweg,isng,nz,dims_out(4))                        :: vcarray
      real, DIMENSION(iweg-1,isng-1,times_in_file)                     :: coriolis
      real opdepth, opdepthu,opdepthd,dp,pminus
      real celkel,prsctt,fac,grav,abscoefi,abscoef
      real qdelta,kminus,vcp1,vcp0
      real valp0,valp1,value,toosmall
      real qvlhsl,ttlhsl,vclhsl,vctophsl
      real plhsl,zlhsl,ezlhsl,tlhsl,psurf
      real diff,rgas,sclht,height,beszero
      real rint,ripbes,rarg,ezsurf,psurfsm,zsurf 
      real ussalr,tmpvlev
      real ezlev,plev,zlev,eps,tlev,qvlev,rhone,rhtwo
      real tempout(mabpl,morpl),virtual,tv
      real themin,themax,rlevel,intrp_value
      character cvcord*1,cvc*1
     


      include  './netcdf.inc'

       
       
       rgas    = 287.04     !J/K/kg
       ussalr  = .0065      ! deg C per m
       sclht   = rgas*256./9.81
       cvc     = cvcord
       mjx  = iweg
       miy  = isng
       mkzh = nz
       it   = 1
       rmsg = 1.e36

      
!Convert pressure to hPa
      prshpa(:,:,:,:) = prs(:,:,:,:) * 0.01
      call vcord_array(prshpa,ght,vert_pottmps,vcarray,iweg,isng,nz, &
                       times_in_file,ncid,cstag,vcor)

      if(vcor .eq. 1) then
         cvcord = 'p'
      else if(vcor .eq. 2) then
         cvcord = 'z'
      else if(vcor .eq. 3) then
         cvcord = 'z'
      else if(vcor .eq. 4) then
         cvcord = 't'
      else if(vcor .eq. 5) then
         cvcord = 't'
      end if


!See if we are on a staggered u or v grid
      njx  = iweg-1
      niy  = isng-1   
      

      if(cstag .eq. "stagU  ") then
          njx  = iweg
      end if

      if(cstag .eq. "stagV  ") then
          niy  = isng
      end if  
!;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
!Now we loop over the number of input interpolation levels requested
!by the user.

!sherrie
      do it = 1,times_in_file
      tempout(:,:) = 0.0

      do nreqlvs = 1,numlevels
         if(cvcord .eq. 'z') then
!Convert rlevel to meters from km
            rlevel = interp_levels(nreqlvs) * 1000.
            vlev = exp(-rlevel/sclht) 
         else if(cvcord .eq. 'p') then
            vlev = interp_levels(nreqlvs) 
         else if(cvcord .eq. 't') then
            rlevel = interp_levels(nreqlvs)
            vlev   = rlevel
         end if
         ixjs = 1
         iyis = 1

         do j=1,njx
            jj=j+ixjs-1
            jjph=min(jj,mjx-1)
            jjmh=max(jj-1,1)

         do i=1,niy
            ii=i+iyis-1
            iiph=min(ii,miy-1)
            iimh=max(ii-1,1)
           
!----------------------------------------------------
          ifound = 0
          do k = 1,mkzh-1
             vcp1  = vcarray(jj,ii,k+1,it)
             vcp0  = vcarray(jj,ii,k,it)
             valp0 = datain(jj,ii,k,it)
             valp1 = datain(jj,ii,k+1,it)

             
!             print *,i,j,k,vcp0,vcp1
!Try and catch underflow errors.  This can occur in the 
!Q fields where values can be on the order of 10^-40
!Running the program on Yellowstone with the ifort compiler
!will cause underflow erros on very small values.
             toosmall = ABS(valp0)
             if(toosmall .lt. 0.0000001) then
                valp0 = 0.0
             end if
             
             toosmall = ABS(valp1)
             if(toosmall .lt. 0.0000001) then
                valp1 = 0.0
             end if

             if ((vlev.ge.vcp0.and.vlev.le.vcp1) .or. &
                (vlev.le.vcp0.and.vlev.ge.vcp1)     ) then
                 if(logp .eq. 1) then
                      vcp1  = log(vcp1)
                      vcp0  = log(vcp0)
                      if(vlev .eq. 0.0) then
                         print *,"Pressure value = 0"
                         print *,"Unable to take log of 0"
                         stop
                     end if
                     tmpvlev  = log(vlev)
                 else
                     tmpvlev  = vlev
                 endif
                  tempout(j,i) = intrp_value(valp0,valp1,tmpvlev,vcp0,vcp1,icase,ixjs)

  105            ifound=1
 
                goto 115
             end if  
          end do  !end for the k loop

 115  continue
      if (ifound.eq.1) goto 333

      if(extrapolate .eq. 0) then
            tempout(j,i) = rmsg
            goto 333
      end if



!
!   Grid point is outside (above or below) model domain
    vclhsl   = vcarray(jj,ii,mkzh,it)
    vctophsl = vcarray(jj,ii,1,it)
    diff=vctophsl-vclhsl
    isign=nint(diff/abs(diff))
!
    if (isign*vlev.ge.isign*vctophsl) then
         tempout(j,i)=datain(jj,ii,1,it)
!          print *,"at warn",tempout(j,i),j,i
         goto 333
      endif

!
!   For the special cases of pressure on height levels or height on
!   pressure levels, or temperature-related variables on pressure or
!   height levels, perform a special extrapolation based on
!   US Standard Atmosphere.
!   
      if ((icase.gt.0) .and. (extrapolate .eq. 1) .and. (vcor .lt. 4)) then
           call special_extrapolation(prshpa,ght,tk,qv,tempout,terrain,sfp,sfpsm,vlev, &
                                      iweg,isng,nz,it,ii,jj,mabpl,morpl,  &
                                      vcor,icase,ncid,rmsg,cvcord)
!           print *,tempout(jj,ii),jj,ii
      else
          tempout(j,i) = datain(jj,ii,mkzh,it) 
!          print *,"tmpout2 ",tempout(j,i),j,i
      end if !for icase gt 0 special extrapolation
!
 333  continue
!
       end do
       end do
 335    continue
     
!        print *,"----done----",interp_levels(nreqlvs)
        do i = 1,njx
           do j = 1,niy
              dataout(i,j,nreqlvs,it) = tempout(i,j)
           end do
        end do
        tempout(:,:) = 0.0 
        end do  !for loop over number of user requested interp levels
        end do  !for loop over number of times in the file

       return
       end  SUBROUTINE special_intrp
!------------------------------------------------------------------------------
 SUBROUTINE calcpvo(pvo,pres,ncid,nvars,nz,ns,ew,times_in_file,u_ivar,v_ivar,dx,dy)
      IMPLICIT NONE

      integer                             :: ncid,nvars,nz,ns,ew,it,u_ivar,v_ivar
      integer                             :: times_in_file
      integer                             :: rcode
      integer                             :: imapm,imapu,imapv,t_ivar,cor_ivar
      integer                             :: i,j,k,kp1,km1,jp1,jm1,ip1,im1,ny,nx
      real, DIMENSION(ew,ns,nz,times_in_file)        :: pvo,temp_pvo
      real, DIMENSION(ew-1,ns-1,nz,times_in_file)    :: tt
      real, DIMENSION(ew-1, ns-1, nz,times_in_file)  :: pres
      real, DIMENSION(ew,ns-1,nz,times_in_file)      :: uu
      real, DIMENSION(ew-1,ns,nz,times_in_file)      :: vv
      real, DIMENSION(ew,ns-1,times_in_file)         :: mapu
      real, DIMENSION(ew-1,ns,times_in_file)         :: mapv     
      real, DIMENSION(ew-1,ns-1,times_in_file)       :: mapm,cor
      real                                :: dx,dy
      real                                :: dsx,dsy,mm,dudy,dvdx,avort,dp
      real                                :: dudp,dvdp,dthdp,dthdx,dthdy,value
      real                                :: themin,themax
      
      include  './netcdf.inc'


      pvo(:,:,:,:) = 0.0
      rcode =  nf_inq_varid(ncid,"MAPFAC_M",imapm)
      rcode =  nf_inq_varid(ncid,"MAPFAC_U",imapu)
      rcode =  nf_inq_varid(ncid,"MAPFAC_V",imapv)
      rcode =  nf_inq_varid(ncid,"T",t_ivar)
      rcode =  nf_inq_varid(ncid,"F",cor_ivar)

      rcode = nf_get_var_real ( ncid, u_ivar, uu )
      rcode = nf_get_var_real ( ncid, v_ivar, vv )
      rcode = nf_get_var_real ( ncid, t_ivar, tt )
      rcode = nf_get_var_real ( ncid, imapu, mapu )
      rcode = nf_get_var_real ( ncid, imapv, mapv )
      rcode = nf_get_var_real ( ncid, imapm, mapm )
      rcode = nf_get_var_real ( ncid, cor_ivar, cor )
      tt    = tt + 300.  !get Theta

      themin = 999
      themax = -999
      do it = 1,times_in_file
      DO K = 1,NZ
          KP1 = MIN(K+1,NZ)
          KM1 = MAX(K-1,1)
          DO J = 1,ns-1
              JP1 = MIN(J+1,ns-1)
              JM1 = MAX(J-1,1)
              DO I = 1,ew-1
                  IP1 = MIN(I+1,ew-1)
                  IM1 = MAX(I-1,1)
                  DSX = (IP1-IM1)*dx
                  DSY = (JP1-JM1)*dy
                  MM = mapm(I,J,it) * mapm(I,J,it)
                  dudy = 0.5 * (uu(I,JP1,K,it)/mapu(I,JP1,it)+     &
                         uu(I+1,JP1,K,it)/mapu(I+1,JP1,it)-        &
                         uu(I,JM1,K,it)/mapu(I,JM1,it)-            &
                         uu(I+1,JM1,K,it)/mapu(I+1,JM1,it))/DSY*MM 

                  dvdx = 0.5 * (vv(IP1,J,K,it)/mapv(IP1,J,it)+    &
                         vv(IP1,J+1,K,it)/mapv(IP1,J+1,it)-        &
                         vv(IM1,J,K,it)/mapv(IM1,J,it)-            &
                         vv(IM1,J+1,K,it)/mapv(IM1,J+1,it))/DSX*MM

                  avort = dvdx - dudy + cor(I,J,it)
                  dp = pres(I,J,KP1,it) - pres(I,J,KM1,it)
                  DUDP = 0.5 * (uu(I,J,KP1,it)+uu(I+1,J,KP1,it)-uu(I,J,KM1,it)-uu(I+1,J,KM1,it))/DP
                  DVDP = 0.5 * (vv(I,J,KP1,it)+vv(I,J+1,KP1,it)-vv(I,J,KM1,it)-vv(I,J+1,KM1,it))/DP
                  DTHDP = (tt(I,J,KP1,it)-tt(I,J,KM1,it))/DP
                  DTHDX = (tt(IP1,J,K,it)-tt(IM1,J,K,it))/DSX*mapm(I,J,it)
                  DTHDY = (tt(I,JP1,K,it)-tt(I,JM1,K,it))/DSY*mapm(I,J,it)
                  temp_pvo(i,j,k,it) = -9.81 * (DTHDP*AVORT-DVDP*DTHDX+DUDP*DTHDY) * 10000.
                  temp_pvo(i,j,k,it) = temp_pvo(i,j,k,it) * 1.e2
!                  print *,i,j,k,temp_pvo(i,j,k,it)
              END DO
          END DO
      END DO
      end do !times_in_file loop

!Flip the temp_pvo array so we can interpolate it
      do k=1,nz
         pvo(:,:,k,:) = temp_pvo(:,:,nz-k+1,:)
      end do 

      RETURN

 end SUBROUTINE calcpvo

!------------------------------------------------------------------------------
 SUBROUTINE calcslp(slp,pres,ncid,nvars,nz,ns,ew,it)
      IMPLICIT NONE

      integer                           :: ncid,nvars,nz,ns,ew,it
      integer                           :: rcode,ivar,i,j,k,klo,khi
      integer,DIMENSION(ew,ns)          :: level
      real, DIMENSION(ew, ns,it)        :: slp
      real, DIMENSION(ew, ns, nz, it)   :: pres,qv,tk,ght
      real, DIMENSION(ew, ns, nz+1, it) :: ph,phb,data1
      real, DIMENSION(ew, ns)           :: t_sea_level, t_surf
      real                              :: rgas,grav,gamma
      real                              :: plo , phi , tlo, thi , zlo , zhi
      real                              :: p_at_pconst , t_at_pconst , z_at_pconst
      real                              :: z_half_lowest
      real                              :: tc,pconst
      logical                           :: l1 , l2 , l3, found,ridiculous_mm5_test


      include  './netcdf.inc'

      rgas   = 287.04
      grav   = 9.81
      gamma  = 0.0065
      tc     = 273.16+17.5
      pconst = 10000.
      ridiculous_mm5_test = .TRUE.

!Get the geopotential height.  It needs to be destaggered in the vertical
      rcode = nf_inq_varid    ( ncid, "PH", ivar )
      rcode = nf_get_var_real ( ncid, ivar, ph )
      rcode = nf_inq_varid    ( ncid, "PHB", ivar )
      rcode = nf_get_var_real ( ncid, ivar, phb )
      data1 = (ph + phb)/9.8
      ght(:,:,1:nz,:) = ( data1(:,:,1:nz,:) + data1(:,:,2:nz+1,:) )*.5      

      
      rcode = nf_inq_varid    ( ncid, "T", ivar )
      rcode = nf_get_var_real ( ncid, ivar, tk )
      tk    = tk + 300.

      rcode = nf_inq_varid    ( ncid, "QVAPOR", ivar )
      rcode = nf_get_var_real ( ncid, ivar, qv )
      

!     Find least zeta level that is PCONST Pa above the surface.  We later use this
!     level to extrapolate a surface pressure and temperature, which is supposed
!     to reduce the effect of the diurnal heating cycle in the pressure field.

      DO j = 1 , ns
         DO i = 1 , ew
            level(i,j) = -1

            k = 1
            found = .false.
            do while( (.not. found) .and. (k.le.nz))
               IF ( pres(i,j,k,it) .LT. pres(i,j,1,it)-PCONST ) THEN
                  level(i,j) = k
                  found = .true.
               END IF
               k = k+1
            END DO 

            IF ( level(i,j) .EQ. -1 ) THEN
            PRINT '(A,I4,A)','Troubles finding level ',NINT(PCONST)/100,' above ground.'
            PRINT '(A,I4,A,I4,A)','Problems first occur at (',i,',',j,')'
            PRINT '(A,F6.1,A)','Surface pressure = ',pres(i,j,1,it)/100,' hPa.'
            STOP 'Error_in_finding_100_hPa_up'
         END IF


         END DO
      END DO
  
!     Get temperature PCONST Pa above surface.  Use this to extrapolate 
!     the temperature at the surface and down to sea level.

      DO j = 1 , ns
         DO i = 1 , ew

            klo = MAX ( level(i,j) - 1 , 1      )
            khi = MIN ( klo + 1        , nz - 1 )
     
            IF ( klo .EQ. khi ) THEN
               PRINT '(A)','Trapping levels are weird.'
               PRINT '(A,I3,A,I3,A)','klo = ',klo,', khi = ',khi,': and they should not be equal.'
               STOP 'Error_trapping_levels'
            END IF

         plo = pres(i,j,klo,it)
         phi = pres(i,j,khi,it)
         tlo = tk(i,j,klo,it) * (1. + 0.608 * qv(i,j,klo,it) )
         thi = tk(i,j,khi,it) * (1. + 0.608 * qv(i,j,khi,it) )
         zlo = ght(i,j,klo,it)         
         zhi = ght(i,j,khi,it)

         p_at_pconst = pres(i,j,1,it) - pconst
         t_at_pconst = thi-(thi-tlo)*LOG(p_at_pconst/phi)*LOG(plo/phi)
         z_at_pconst = zhi-(zhi-zlo)*LOG(p_at_pconst/phi)*LOG(plo/phi)

         t_surf(i,j) = t_at_pconst*(pres(i,j,1,it)/p_at_pconst)**(gamma*rgas/grav)
         t_sea_level(i,j) = t_at_pconst+gamma*z_at_pconst

         END DO
      END DO

!     If we follow a traditional computation, there is a correction to the sea level 
!     temperature if both the surface and sea level temnperatures are *too* hot.

      IF ( ridiculous_mm5_test ) THEN
         DO j = 1 , ns
            DO i = 1 , ew
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

      DO j = 1 , ns
      DO i = 1 , ew
         z_half_lowest=ght(i,j,1,it)
         slp(i,j,it) = pres(i,j,1,it) *EXP((2.*grav*z_half_lowest)/(rgas*(t_sea_level(i,j)+t_surf(i,j))))
         slp(i,j,it) = slp(i,j,it) * 0.01
      END DO
      END DO

 END SUBROUTINE calcslp


!------------------------------------------------------------------------------
  SUBROUTINE def_outfile_dims(ncid,mcid,num_interp_levels,nsoil,ndims,time_ivar, &
                           level_ivar,ndims_out,times_in_file,dnamei,dnamej, &
                           dvali,dvalj,unstagger_grid)

     implicit none
     INCLUDE './netcdf.inc'
     real          :: missing
     integer       :: ncid,mcid,num_interp_levels,jvar,iweg,isng,ibtg,nsoil,ndims
     integer       :: i,j,var_value,rcode,time_ivar,level_ivar,times_in_file,ilen
     integer       :: dvali(20),dvalj(20),ndims_out,timdim
     character(31) :: var_name,dnamei(20),dnamej(20)
     logical       :: unstagger_grid,wanted

!dnamei holds the dimensions names from the input file.
!dnamej will hold the dimension names for the output file.
!We are changing the name of the bottom_top variable to lev.

      j = 0
      DO i = 1, ndims
          wanted = .TRUE.
          rcode = nf_inq_dim(ncid, i, dnamei(i), dvali(i))
          if(dnamei(i) == 'Time') then
             j = j + 1
             time_ivar = i
             dnamej(j) = dnamei(i)
             dvalj(j) = dvali(i)
             times_in_file = dvali(i)
             rcode = nf_def_dim(mcid, 'time', NF_UNLIMITED, time_ivar)
          else
             if (var_name  == 'soil_layers_stag') nsoil = var_value
             if (dnamei(i) == 'bottom_top_stag') wanted = .FALSE.
             if (dnamei(i) == 'bottom_top')      wanted = .FALSE.  
             if((dnamei(i) == 'west_east_stag') .and. (unstagger_grid .eq. .TRUE.))   wanted = .FALSE.
             if((dnamei(i) == 'south_north_stag') .and. (unstagger_grid .eq. .TRUE.)) wanted = .FALSE.
             if(wanted .eq. .TRUE.) then 
                j = j + 1
                dnamej(j) =  dnamei(i)
                dvalj(j)  =  dvali(i)
                rcode = nf_def_dim(mcid, dnamej(j), dvalj(j), j)
                if(rcode .ne. nf_noerr)  call handle_err(rcode, "Unable to create output file dimensions")
             end if
          end if
     end do 
   
     
!Define a level dimension for the number of requested vertical levels
     j = j + 1
     rcode = nf_def_dim(mcid, 'vlevs', num_interp_levels, j)
     if(rcode .ne. nf_noerr)  call handle_err(rcode, "Unable to create output file dimensions")
     dnamej(j) = 'lev'
     dvalj(j)  = num_interp_levels
     level_ivar = j
     ndims_out = j
  END SUBROUTINE def_outfile_dims


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

     DO yy=1901,yr-1
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
!----------------------------------------------------------------------
 SUBROUTINE def_time_level_vars(ncid,mcid,time_ivar,level_ivar,interp_levels, &
                                num_interp_levels,times_in_file,leap_year,vcor)

     implicit none
     include './netcdf.inc'

     character (LEN=19),ALLOCATABLE, DIMENSION(:)   :: time_strings
     character (len=80)  :: att_text,recname
     character (len=250)  :: temp_name
     integer             :: ncid,mcid,jvar,thedate
     integer             :: ntimes,year,month,day,hour,minute,sec
     integer             :: yy,mm,dd,i,rcode,ilen,times_ivar,level_ivar,start_dims(2)
     integer             :: time_ivar,times_in_file,datestr_ivar
     integer             :: hrs_per_yr,nmo,sumoff,it,type,natts
     integer             :: ndy_leap(12),ndy_noleap(12),dimarray(3),iday, ndy(12)
     integer             :: init_date,ndims
     integer             :: datestringlen,previous_date,num_interp_levels
     integer             :: wrf_times_2udunits_c
     integer             :: vcor
     double precision    :: time,missing,dtime_array(times_in_file),dtime
     real                :: interp_levels(num_interp_levels),plevels(num_interp_levels)
     logical             :: leap_year
     
     

     dimarray = 1

!Define the time variable and values.
     jvar  = 1
     rcode = nf_def_var(mcid, 'time', NF_DOUBLE, 1, 1, jvar)
     if (rcode .ne. nf_noerr) call handle_err(rcode, "Error defining time variable in out file")
     att_text = "Hours since 1901-01-01 00:00:00"
     ilen = len_trim(att_text)
     rcode = nf_put_att_text(mcid, jvar, "description", ilen, att_text(1:ilen) )
     rcode = nf_put_att_text(mcid, jvar, "units", ilen, att_text(1:ilen) )
     ilen = 4
     rcode = nf_put_att_text(mcid, jvar, "standard_name", ilen,"time" )
     missing = 9.96920996838687e+36
     rcode = nf_put_att_double(mcid, jvar, "missing_value", NF_DOUBLE, 1, missing )

     jvar = 2
     ndims = 2
     dimarray(1) = 2  !DateStrLen
     dimarray(2) = 1  !time
     rcode = nf_def_var(mcid, 'Times', NF_CHAR, ndims, dimarray, jvar) 
     ilen  = 20     
     rcode = nf_put_att_text(mcid, jvar, "description", ilen, "YYYY-MM-DD_hh:mm:ss" )
     rcode = nf_put_att_text(mcid, jvar, "missing_value", 1, " " )
     
!Define the vertical coordinate
     jvar = 3
     if(vcor .eq. 1) then
        rcode = nf_def_var(mcid, 'LEV', NF_REAL, 1 ,level_ivar, jvar)
        if(rcode .ne. nf_noerr)  then
           call handle_err(rcode, "Unable to create vertical coordinate level variable")
        end if
        ilen = 15
        rcode = nf_put_att_text(mcid, jvar, "description", ilen, "Pressure Levels" )
        ilen = 3
        rcode = nf_put_att_text(mcid, jvar, "units", ilen, "Pa" )
        missing = 9.96921e+36
        rcode = nf_put_att_real(mcid, jvar, "missing_value", NF_REAL, 1, missing )     
     end if

     if(vcor .eq. 2) then  
        rcode = nf_def_var(mcid, 'LEV', NF_REAL, 1 ,level_ivar, jvar)
        if(rcode .ne. nf_noerr)  then
           call handle_err(rcode, "Unable to create vertical coordinate level variable")
        end if   
        ilen = 17
        rcode = nf_put_att_text(mcid, jvar, "description", ilen, "Height Levels msl" )    
        ilen = 3
        rcode = nf_put_att_text(mcid, jvar, "units", ilen, "km " )
        missing = 9.96921e+36
        rcode = nf_put_att_real(mcid, jvar, "missing_value", NF_REAL, 1, missing )  
     end if      

     if(vcor .eq. 3) then
        rcode = nf_def_var(mcid, 'LEV', NF_REAL, 1 ,level_ivar, jvar)
        if(rcode .ne. nf_noerr)  then
           call handle_err(rcode, "Unable to create vertical coordinate level variable")
        end if   
        ilen = 17
        rcode = nf_put_att_text(mcid, jvar, "description", ilen, "Height Levels agl" )    
        ilen = 3
        rcode = nf_put_att_text(mcid, jvar, "units", ilen, "km " )
        missing = 9.96921e+36
        rcode = nf_put_att_real(mcid, jvar, "missing_value", NF_REAL, 1, missing )  
     end if 

    
     if(vcor .eq. 4) then  
        print *,"Temperature"
        rcode = nf_def_var(mcid, 'LEV', NF_REAL, 1 ,level_ivar, jvar)
        if(rcode .ne. nf_noerr)  then
           call handle_err(rcode, "Unable to create vertical coordinate level variable")
        end if   
        ilen = 28
        rcode = nf_put_att_text(mcid, jvar, "description", ilen, "Potential Temperature Levels" )    
        ilen = 4
        rcode = nf_put_att_text(mcid, jvar, "units", ilen, "degK" )
        missing = 9.96921e+36
        rcode = nf_put_att_real(mcid, jvar, "missing_value", NF_REAL, 1, missing )  
     end if 


     if(vcor .eq. 5) then  
        print *,"Potential Temperature"
        rcode = nf_def_var(mcid, 'LEV', NF_REAL, 1 ,level_ivar, jvar)
        if(rcode .ne. nf_noerr)  then
           call handle_err(rcode, "Unable to create vertical coordinate level variable")
        end if   
        ilen = 39
        rcode = nf_put_att_text(mcid, jvar, "description", ilen, "Equivalent Potential Temperature Levels" )    
        ilen = 4
        rcode = nf_put_att_text(mcid, jvar, "units", ilen, "degK" )
        missing = 9.96921e+36
        rcode = nf_put_att_real(mcid, jvar, "missing_value", NF_REAL, 1, missing )  
     end if 

     ndy(:)=[31,28,31,30,31,30,31,31,30,31,30,31]
     allocate (time_strings(times_in_file))
     rcode = nf_get_var_text (ncid, time_ivar, time_strings )


     ndy_leap(:)   = [1,33,61,92,122,153,183,214,245,275,306,336]
     jvar = 1
     if(times_in_file .eq. 1) then
        read (time_strings(1)(1:4),'(i4)') year
        read (time_strings(1)(6:7),'(i2)') month
        read (time_strings(1)(9:10),'(i2)') day
        read (time_strings(1)(12:13),'(i2)') hour
        read (time_strings(1)(15:16),'(i2)') minute
        read (time_strings(1)(18:19),'(i2)') sec

        if(leap_year) then
           ilen = 8
           rcode = nf_put_att_text(mcid, jvar, "calendar", ilen, "standard" )
           dtime =  wrf_times_2Udunits_c(year,month,day,hour)
        else
           ilen  = 6
           rcode = nf_put_att_text(mcid, jvar, "calendar", ilen, "noleap" )
           ndy_noleap(:) = [1,32,60,91,121,152,182,213,244,274,305,335]
           iday  = ndy_noleap(month)
           hrs_per_yr = 365 * 24
           dtime = (year - 1901) * hrs_per_yr + (iday - 1) * 24 + hour
       end if
     else
         do it = 1,times_in_file
            read (time_strings(it)(1:4),'(i4)') year
            read (time_strings(it)(6:7),'(i2)') month
            read (time_strings(it)(9:10),'(i2)') day
            read (time_strings(it)(12:13),'(i2)') hour
            read (time_strings(it)(15:16),'(i2)') minute
            read (time_strings(it)(18:19),'(i2)') sec
           if(leap_year) then
              ilen = 8
              rcode = nf_put_att_text(mcid, jvar, "calendar", ilen, "standard" )
              dtime_array(it) =  wrf_times_2Udunits_c(year,month,day,hour)
           else
              ilen  = 6
              rcode = nf_put_att_text(mcid, jvar, "calendar", ilen, "noleap" )
              ndy_noleap(:) = [1,32,60,91,121,152,182,213,244,274,305,335]
              iday  = ndy_noleap(month)
              hrs_per_yr = 365 * 24
              dtime_array(it) = (year - 1901) * hrs_per_yr + (iday - 1) * 24 + hour
          end if  
       end do
     end if

     
!Take output file out of define mode so we can put the values of the time and times variables in.
        rcode = nf_enddef(mcid)
        jvar  = 1
        if(times_in_file .eq. 1) then
           rcode = nf_put_vara_double(mcid, jvar, 1, 1, dtime)
           if(rcode .ne. nf_noerr)  call handle_err(rcode, "Error putting values for dtime")
        else
           rcode = nf_put_vara_double(mcid, jvar, 1, times_in_file, dtime_array)
           if(rcode .ne. nf_noerr)  call handle_err(rcode, "Error putting values for dtime")
        end if

        jvar  = 2
        datestringlen = 19
        dimarray(1) =  datestringlen
        dimarray(2) = times_in_file
        start_dims(1) = 1
        start_dims(2) = 1
        rcode = nf_put_vara_text(mcid, jvar, start_dims, dimarray,time_strings )
        if(rcode .ne. nf_noerr)  call handle_err(rcode, "Error putting values for Times")

        jvar = 3
        do i = 1,num_interp_levels
           if(vcor .eq. 1) then  !for pressure levels convert to Pa
              plevels(i) = interp_levels(i) * 100.
           else
              plevels(i) = interp_levels(i)
           end if
        end do

        rcode = nf_put_vara_real(mcid, jvar,1,num_interp_levels, plevels)
        if(rcode .ne. nf_noerr)  call handle_err(rcode, "Error putting values for pressure levels")

        deallocate(time_strings)


 END SUBROUTINE def_time_level_vars

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
 SUBROUTINE def_var (mcid, jvar, cval, itype, idm, jshape, order, desc, units, stag, coord )

      IMPLICIT NONE

      INCLUDE './netcdf.inc'

      INTEGER              :: mcid, jvar
      CHARACTER (LEN =  80) :: cval
      INTEGER              :: itype, idm
      REAL, DIMENSION(6)   :: jshape
      CHARACTER (LEN =  3) :: order
      CHARACTER (LEN = 19) :: desc
      CHARACTER (LEN =  2) :: units
      CHARACTER (LEN =  1) :: stag
      CHARACTER (LEN = 10) :: coord

      INTEGER            :: rcode, ilen
      CHARACTER (LEN=30) :: att_text


      IF ( itype == 5 ) THEN
         rcode = nf_redef(mcid)
         rcode = nf_def_var(mcid, trim(cval), NF_REAL, idm, jshape, jvar)
         if (rcode .ne. nf_noerr) then
             print *,"rcode = ",rcode,"Unable to put variable ",cval
             stop
         end if
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
!                                                                     !
      SUBROUTINE smooth(datain,nsmooth,ew,ns,rmsg)
!
!   This is a smoothing routine, with several choices:
!
!   If numpas is between 1 and 99, then a 9-point weighted smoother is
!   applied numpas times.  The smoother follows equation 11-107 in
!   Haltiner and Williams. One pass completely removes 2-delta-x waves
!   on the interior.  On the outer row and column, and near missing
!   data points, smoothing is carried out in a manner that preserves
!   the domain average value of the field.
!
!   If numpas is between 101 and 199, then a smoother-desmoother is
!   applied (numpas-100) times.  One pass removes a large fraction
!   of the 2-delta-x component, but is not as harsh on longer
!   wavelengths as the 9-point smoother
!
!   If numpas is between 201 and 299, then the smoother-desmoother is
!   applied (numpas-200) times, and, after each pass, the data field
!   is forced to be non-negative.
!
!   If numpas is between 301 and 399, then a weighted
!   smoother is applied, in which the smoothed value
!   is given by a weighted average of values at
!   surrounding grid points.  The weighting function
!   is the Cressman weighting function:
!
!               w = ( D**2 - d**2 ) / ( D**2 + d**2 )
!
!   In the above, d is the distance (in grid increments)
!   of the neighboring point to the smoothing point, and
!   D is the radius of influence [in grid increments,
!   given by (numpas-300)].
!
!   If numpas is between 401 and 499, then the smoothing
!   is similar for numpas=301-399, except the weighting
!   function is the circular apperture diffraction function
!   (following a suggestion of Barnes et al. 1996):
!
!               w = bessel(3.8317*d/D)/(3.8317*d/D)
!
!   If numpas is between 501 and 599, then the smoothing
!   is similar for numpas=301-399, except the weighting
!   function is the product of the rectangular
!   apperture diffraction function in the x and y directions
!   (the function used in Barnes et al. 1996):
!
!               w = [sin(pi*x/D)/(pi*x/D)]*[sin(pi*y/D)/(pi*y/D)]
!
!   Note, the first index of datain varies along the abcissa
!   (or x), and the second index varies along the ordinate (or y).
!
      implicit none
      integer                    :: nsmooth,ew,ns,niy,njx
      integer                    :: i,j,ipas,nump,inn,nval
      integer                    :: je,ie,ipass,kp,idist,nfp     
      integer                    :: npsq,is,js,ireg,ifp,jreg,jfp,imsg

      real, DIMENSION(ns,ew) ::datain,work
      real                       :: beszero,xnu(2),fprint(150,150)
      real                       :: rmsg,give,totgive,total,asv
      real                       :: aplus,cell,dist,distsq
      real                       :: bes,xdist,xfac,ydist,yfac,avgval
      real                       :: tot,totwt,pi,arg1



      beszero = 3.8317
      pi      = 3.14159265
      njx     = ns-1
      niy     = ew-1
!      print *,ns,ew,ew-1
!      print *,"niy ",niy
!      print *,"njx ",njx
  
!
!
!
      if (mod(nsmooth,100).eq.0) return
!
      if (nsmooth.le.99) then   ! 9-point smoother
!
      do ipas=1,nsmooth
!
      do i=1,niy
      do j=1,njx
         work(j,i)=0.
      enddo
      enddo
      do i=1,niy
      do j=1,njx
         if (datain(j,i).eq.rmsg) then
            work(j,i)=rmsg
         else
            totgive=0.
            if (i.gt.1) then
               if (datain(j,i-1).ne.rmsg) then 
                  give=.125*datain(j,i)
                  work(j,i-1)=work(j,i-1)+give
                  totgive=totgive+give
               endif
               if (j.gt.1) then
                  if (datain(j-1,i-1).ne.rmsg) then 
                     give=.0625*datain(j,i)
                     work(j-1,i-1)=work(j-1,i-1)+give
                     totgive=totgive+give
                  endif
               endif
               if (j.lt.njx) then
                  if (datain(j+1,i-1).ne.rmsg) then 
                     give=.0625*datain(j,i)
                     work(j+1,i-1)=work(j+1,i-1)+give
                     totgive=totgive+give
                  endif
               endif
            endif
            if (i.lt.niy) then
               if (datain(j,i+1).ne.rmsg) then 
                  give=.125*datain(j,i)
                  work(j,i+1)=work(j,i+1)+give
                  totgive=totgive+give
               endif
               if (j.gt.1) then
                  if (datain(j-1,i+1).ne.rmsg) then 
                     give=.0625*datain(j,i)
                     work(j-1,i+1)=work(j-1,i+1)+give
                     totgive=totgive+give
                  endif
               endif
               if (j.lt.njx) then
                  if (datain(j+1,i+1).ne.rmsg) then 
                     give=.0625*datain(j,i)
                     work(j+1,i+1)=work(j+1,i+1)+give
                     totgive=totgive+give
                  endif
               endif
            endif
            if (j.gt.1) then
               if (datain(j-1,i).ne.rmsg) then 
                  give=.125*datain(j,i)
                  work(j-1,i)=work(j-1,i)+give
                  totgive=totgive+give
               endif
            endif
            if (j.lt.njx) then
               if (datain(j+1,i).ne.rmsg) then 
                  give=.125*datain(j,i)
                  work(j+1,i)=work(j+1,i)+give
                  totgive=totgive+give
               endif
            endif
            work(j,i)=work(j,i)+datain(j,i)-totgive
         endif
      enddo
      enddo

      do i=1,niy
      do j=1,njx
         datain(j,i)=work(j,i)
      enddo
      enddo
!
      enddo
!
      elseif (nsmooth.le.299) then   ! smoother-desmoother
!
      if (nsmooth.ge.200) then
         nump=nsmooth-200
         inn=1
      else
         nump=nsmooth-100
         inn=0
      endif
!
      if (nump.lt.1) return
!
!   Check if any data is missing.
!
      imsg=0
      do i=1,niy
      do j=1,njx
         if (datain(j,i).eq.rmsg) then
            imsg=1
            goto 15
         endif
      enddo
      enddo
 15   continue
!
      if (imsg.eq.1) then
!
!   Get average value of datain.
!
      nval=0
      total=0.
      do 10 i=1,niy
      do 10 j=1,njx
         if (datain(j,i).ne.rmsg) then
            total=total+datain(j,i)
            nval=nval+1
         endif
   10 continue
      if (nval.eq.0) then
         write(*,*)'  All elements of this datain are rmsg.'
         return
      endif
      avgval=total/nval
!
!   Set each element that is currently rmsg to avgval, and
!   keep track of them with work.
!
      do 20 i=1,niy
      do 20 j=1,njx
         if (datain(j,i).eq.rmsg) then
            datain(j,i)=avgval
            work(j,i)=1.
         else
            work(j,i)=0.
         endif
   20 continue
!
      endif
!
!     *** Do calculation and put into datain array.
!
      xnu(1) = 0.50
      xnu(2) = -0.52
      je = njx - 1
      ie = niy - 1
      do 100 ipass = 1,nump*2
         kp=2-mod(ipass,2)          
!     
!        *** First, smooth in the njx direction.
!     
         do 60 j = 2,je
            asv = datain(j,1)
            do 50 i = 2,ie
               aplus = datain(j,i+1)
               cell = datain(j,i)
               datain(j,i)= datain(j,i) + xnu(kp)*((asv + aplus)/2.0 - datain(j,i))
               asv = cell
   50       continue
   60    continue
!     
!        *** Now, smooth in the niy direction.
!     
         do 80 i = 2,ie
            asv = datain(1,i)
            do 70 j = 2,je
               aplus = datain(j+1,i)
               cell = datain(j,i)
               datain(j,i) = datain(j,i) + xnu(kp)*((asv + aplus)/2.0 - datain(j,i))
               asv = cell
   70       continue
   80    continue
!
      if (inn.eq.1) then
!
!      Make non-negative.
!
         do i=1,niy
         do j=1,njx
            datain(j,i)=max(0.,datain(j,i))
         enddo
         enddo
      endif
!
  100 continue
!
      if (imsg.eq.1) then
!
!      Set rmsg elements back to rmsg
!
         do 200 i=1,niy
         do 200 j=1,njx
            datain(j,i)=work(j,i)*rmsg + (1.-work(j,i))*datain(j,i)
  200    continue
      endif
!
      elseif (nsmooth.le.599) then   ! weighted smoother
!
      idist=mod(nsmooth,100)
      if (idist.eq.0) return
      nfp=1+2*idist
      npsq=idist*idist
      if (nsmooth.le.399) then  ! Cressman function
         do i=1,nfp
         do j=1,nfp
            distsq=(i-idist-1.)**2+(j-idist-1.)**2
            fprint(j,i)=max((npsq-distsq)/(npsq+distsq),0.0)
         enddo
         enddo
      elseif (nsmooth.le.499) then   ! Circular diffraction function
         do i=1,nfp
         do j=1,nfp
            dist=beszero/idist*sqrt((i-idist-1.)**2+(j-idist-1.)**2)
            if (i.eq.idist+1.and.j.eq.idist+1) then
                fprint(j,i)=.5
            else
               fprint(j,i)=max(0.,bes(dist)/dist)
            endif
         enddo
         enddo
      elseif (nsmooth.le.599) then   ! Rect. diffraction function
         do i=1,nfp
         do j=1,nfp
            if (j.eq.idist+1) then
               xfac=1.
            else
               xdist=pi/idist*(j-idist-1.)
               xfac=sin(xdist)/xdist
            endif
            if (i.eq.idist+1) then
               yfac=1.
            else
               ydist=pi/idist*(i-idist-1.)
               yfac=sin(ydist)/ydist
            endif
            fprint(j,i)=xfac*yfac
         enddo
         enddo
      endif
!
      
      do i=1,niy
      do j=1,njx
         if (datain(j,i).ne.rmsg) then
            if(datain(j,i) .lt. .0000001) then
               datain(j,i) = 0.0
            end if
            tot=0.
            totwt=0.
            is=max(1,i-idist)
            ie=min(niy,i+idist)
            js=max(1,j-idist)
            je=min(njx,j+idist)
            do ireg=is,ie
               ifp=ireg-i+idist+1
            do jreg=js,je
               jfp=jreg-j+idist+1
               if (datain(jreg,ireg).ne.rmsg) then
                  totwt=totwt+fprint(jfp,ifp)
                  tot=tot+fprint(jfp,ifp)*datain(jreg,ireg)               
               endif
            enddo
            enddo
            work(j,i)=tot/totwt
         else
            work(j,i)=rmsg
         endif
      enddo
      enddo
!
      do i=1,niy
      do j=1,njx
         datain(j,i)=work(j,i)
      enddo
      enddo
!
      endif
!
      return
      end  SUBROUTINE smooth


!-----------------------------------------------------------
      SUBROUTINE getpres(ncid,ew,ns,nz,it,pres_field)

       INCLUDE './netcdf.inc'

       integer ew,ns,nz,it,ncid
       integer ivar,rcode
       real, DIMENSION(ew,ns,nz,it)      :: P,PB
       real, DIMENSION(ew,ns,nz,it)      :: pres_field

              rcode = nf_inq_varid    ( ncid, "P", ivar )
       rcode = nf_get_var_real ( ncid, ivar, P)
       rcode = nf_inq_varid    ( ncid, "PB", ivar )
       rcode = nf_get_var_real ( ncid, ivar, PB )
       pres_field = P + PB
       end  SUBROUTINE getpres

!-----------------------------------------------------------
      SUBROUTINE getterrain(ncid,iweg,isng,times_in_file,terrain)

       INCLUDE './netcdf.inc'

       integer iweg,isng,ncid,times_in_file
       integer ivar,rcode,i,it
       real, DIMENSION(iweg-1,isng-1)               :: terrain
       real, DIMENSION(iweg-1,isng-1,times_in_file) :: hgt


       terrain(:,:) = 0.0
       rcode = nf_inq_varid    ( ncid, "HGT", ivar )
       if(rcode .ne.  nf_noerr) then
          print *,"Unable to get HGT netcdf id"
          call handle_err(rcode)
       endif


       rcode = nf_get_var_real ( ncid, ivar, hgt )
       if(rcode .ne.  nf_noerr) then
          print *,"Unable to get HGT variable"
          call handle_err(rcode)
       endif      

!Terrain or HGT is invariant so we only need the terrain for the first time.
       terrain = hgt(:,:,1)
       end  SUBROUTINE getterrain

!-----------------------------------------------------------
!The code in this subroutine was taken from ripdp_wrfarw.f
!Calculates destaggered geopotential height.  
!Units in Meters.


      SUBROUTINE calcght(ncid,iweg,isng,nz,nzstag,times_in_file,ght)

      INCLUDE './netcdf.inc'


      integer ncid,iweg,isng,nz,nzstag,times_in_file
      REAL, ALLOCATABLE, DIMENSION(:,:)                :: znu,znw
      REAL, ALLOCATABLE, DIMENSION(:,:,:,:)            :: phb,ph
      real, DIMENSION(iweg,isng,nz,times_in_file)      :: ght
      real, DIMENSION(iweg,isng,nzstag,times_in_file)  :: scratch
      real  znfac(nz),ripznw(nzstag),ripznu(nz)
      integer ivar,rcode
      integer mjx,miy,mkzh,i,j,k,kindex,it
      
!Read geopotential from file.  Units are m/sec2 on the WRF file
!Geopotential is staggered in the vertical on the WRF file.
       mjx    = iweg                       
       miy    = isng                      
       mkzh   = nz                         


      ght(:,:,:,:) = 0.0
!PH and PHB are staggered in the vertical.
      allocate(ph(iweg-1,isng-1,nzstag,times_in_file))
      allocate(phb(iweg-1,isng-1,nzstag,times_in_file))

      rcode = nf_inq_varid    ( ncid, "PH", ivar )
      if (rcode .ne. nf_noerr) then
          print *,"Error getting netcdf variable for PH in calcght"
          call handle_err(rcode)
      endif

      rcode = nf_get_var_real ( ncid, ivar, ph )
      if (rcode .ne. nf_noerr) then
          print *,"Error reading in variable PH for input netcdf file"
          call handle_err(rcode)
      endif


      rcode = nf_inq_varid    ( ncid, "PHB", ivar )
      if (rcode .ne. nf_noerr) then
          print *,"Error getting netcdf id for PHB in calcght"
          call handle_err(rcode)
      endif

      rcode = nf_get_var_real ( ncid, ivar, phb )
      if (rcode .ne. nf_noerr) then
          print *,"Error reading in variable PHB for input netcdf file"
          call handle_err(rcode)
      endif


!Convert geopotential to geopotential height.  Units will be Meters.
!Invert the vertical levels so we can use RIP's vinterp routine.
      do it=1,times_in_file
         do k=1,mkzh+1
            do j=1,isng-1
            do i=1,iweg-1
               kindex = mkzh+1-k+1
               scratch(i,j,k,it) = (phb(i,j,kindex,it) + ph(i,j,kindex,it))/9.81
            enddo
            enddo
         enddo
      end do
      deallocate(phb)
      deallocate(ph)

!
!   Now interpolate ght to "mass levels".  This was taken directly from ripdp_wrfarw.f
!
      allocate (znu(nz,times_in_file))
      rcode = nf_inq_varid ( ncid, "ZNU", ivar )
      if (rcode .ne. nf_noerr) then
          print *,"Error reading ZNU netcdf id in calcght"
          call handle_err(rcode)
      endif

      rcode = nf_get_var_real ( ncid, ivar, znu )
      if (rcode .ne. nf_noerr) then
          print *,"Error reading ZNU variable in calcght"
          call handle_err(rcode)
      endif 


      allocate (znw(nzstag,times_in_file))
      rcode = nf_inq_varid ( ncid, "ZNW", ivar )
      rcode = nf_get_var_real ( ncid, ivar, znw )
      if (rcode .ne. nf_noerr) then
          print *,"Error reading ZNW variable in calcght"
          call handle_err(rcode)
      endif 
     

!Sine both znu and znw are both invariant we only need to first time.
      do k=1,mkzh+1
        ripznw(k) = znw(mkzh+1-k+1,1)
      enddo


      do k=1,mkzh
         ripznu(k)  = znu(mkzh-k+1,1)
         znfac(k)   =(ripznw(k)-ripznu(k))/(ripznw(k)-ripznw(k+1))
      enddo
      deallocate(znu)
      deallocate(znw)

   
      do it=1,times_in_file
         do j=1,isng-1
         do i=1,iweg-1
         do k=1,mkzh
            ght(i,j,k,it)=znfac(k)*scratch(i,j,k+1,it) + (1.-znfac(k))*scratch(i,j,k,it)
         enddo
         enddo
         enddo
      enddo

      return
      end   SUBROUTINE calcght
!-----------------------------------------------------------------------

      SUBROUTINE calctk(ncid,iweg,isng,nz,times_in_file,prs,tk)

      INCLUDE './netcdf.inc'


      integer iweg,isng,nz,times_in_file
      REAL, ALLOCATABLE, DIMENSION(:,:,:,:)            :: T
      real, DIMENSION(iweg,isng,nz,times_in_file)      :: tk
      real, DIMENSION(iweg-1,isng-1,nz,times_in_file)  :: prs
      real  pvalue,rd,cp,rcp,tvalue
      integer ncid,ivar,rcode
      integer mjx,miy,mkzh,i,j,k,kindex,it
      integer kvalue
    
       mkzh   = nz                         
       it     = 1  
       rd     = 287.04
       cp     =  1004.0
       rcp    = rd/cp
       
       tk(:,:,:,:) = 0.0
!Read T perturbation potential temperature (theta-t0)
      allocate(T(iweg-1,isng-1,nz,times_in_file))
      rcode = nf_inq_varid    ( ncid, "T", ivar )
      if (rcode .ne. nf_noerr) call handle_err(rcode)      
      rcode = nf_get_var_real ( ncid, ivar, T )
      if (rcode .ne. nf_noerr) call handle_err(rcode)


!We invert the tk array for use with RIP routines.
!
      tk(:,:,:,:) = 0.0
      do it = 1,times_in_file
         do k = 1,mkzh
            do j = 1,isng-1
            do i = 1,iweg-1
                kvalue       = mkzh-k+1
                pvalue       = prs(i,j,kvalue,it)/100. 
                tvalue       = T(i,j,kvalue,it)
                tk(i,j,k,it) = (tvalue+300.) * (pvalue/1000.)**rcp
            enddo
            enddo
         enddo
      enddo

      return
      end  SUBROUTINE calctk

!-----------------------------------------------------
!This subroutine was taken from rhucalc.f in the rip code.

     SUBROUTINE calcrh(iweg,isng,nz,times_in_file,prs,rh,qv,tk)

      INCLUDE './netcdf.inc'

      integer iweg,isng,nz,nzstag,times_in_file
      real, DIMENSION(iweg,isng,nz,times_in_file)       :: rh,tk
      real, DIMENSION(iweg-1,isng-1,nz,times_in_file)   :: prs,qv
      real  pvalue,rd,cp,rcp,q,t,e,celkel
      real  es,eps,qdelta
      integer ncid,ivar,rcode
      integer mjx,miy,mkzh,i,j,k,kindex,it
      integer ripk
    
      mkzh   = nz                         
      rh(:,:,:,:) = 0.0
      eps = 0.622
      do it = 1,times_in_file
         do k = 1,mkzh
            do j = 1,isng-1
            do i = 1,iweg-1
               ripk   = mkzh-k+1
               q      = qv(i,j,ripk,it) 
               t      = tk(i,j,k,it)
               pvalue = prs(i,j,ripk,it) * 0.01
               e  = q*pvalue/(eps+q)
               es =  6.112 * exp( 17.67*(t-273.15)/(t-29.65) )
              rh(i,j,k,it) = 100.*(e*(pvalue-es))/(es*(pvalue-e))
           enddo
           enddo
         enddo
     enddo
     return
     end  SUBROUTINE calcrh

!-----------------------------------------------------------------------------------
      SUBROUTINE  calcsfp(ncid,iweg,isng,nz,times_in_file, &
                        prs,tk,ght,terrain,sfp,sfpsm)

      INCLUDE './netcdf.inc'

      integer nz,nzstag,times_in_file,iweg,isng
      real, DIMENSION(iweg,isng,nz,times_in_file)          :: tk,ght
      real, DIMENSION(iweg-1,isng-1,nz,times_in_file)      :: prs,wrfqv
      real, DIMENSION(iweg-1,isng-1)                       :: terrain
      real, DIMENSION(isng,iweg,times_in_file)             :: sfpsm,sfp
      real, DIMENSION(isng,iweg)                           :: temp
      
      real  pvalue,rd,cp,rcp,q,t,e,celkel,es,eps,MISSING
      real  virtual,tv,rgas,ussalr,tervalue,qdelta,pressure,dx
      real  ter_hgt
      integer ncid,ivar,rcode,nsmooth
      integer mjx,miy,mkzh,i,j,k,kvalue,it
      


!Get grid spacing for the smooth routine
      rcode = nf_get_att_real (ncid, nf_global, 'DX', dx)
      nsmooth = nint(20./(dx/1000.))+400

      rgas    = 287.04     !J/K/kg
      ussalr  = .0065      ! deg C per m
      MISSING=1.e36

      mjx    = iweg                      
      miy    = isng                     
      mkzh   = nz                         

      qdelta =  1.e-15
      rcode = nf_inq_varid    ( ncid, "QVAPOR", ivar )
      rcode = nf_get_var_real ( ncid, ivar, wrfqv )  
      WHERE(wrfqv < qdelta) wrfqv = 0.0
      wrfqv(:,:,:,:)  = wrfqv(:,:,:,:)  * 1000.



     sfp(:,:,:)   = 0.0
     sfpsm(:,:,:) = 0.0
!
!Calculate sfp using the altimeter equation.  Taken from ripdp_wrfarw.f
!NOTE:sfp and sfpsm are defined as (isng,iweg,it) instead of (iweg,isgn,it)
!This is so it can be used in the extrapolation of the temperatures below
!ground.  The extrapolation is done with RIP code.

      if(times_in_file .eq. 1) then 
         it = 1
         do j=1,mjx-1
            do i=1,miy-1
               pressure = prs(j,i,1,it) * 0.01
               ter_hgt  = terrain(j,i)
               tv = virtual(tk(j,i,mkzh,it),.001*wrfqv(j,i,1,it))
               sfp(i,j,it) = pressure*(tv/(tv+ussalr* &
                              (ght(j,i,mkzh,it)-ter_hgt)))**(-9.81/(rgas*ussalr))
               sfpsm(i,j,it) = sfp(i,j,it)
           enddo
         enddo
         call smooth(sfpsm,nsmooth,iweg,isng,MISSING)
         return
      end if

      
      do it = 1,times_in_file
         temp(:,:) = 0.0
         do j=1,mjx-1
            do i=1,miy-1
                temp(i,j) = 0.0
                pressure = prs(j,i,1,it) * 0.01
                ter_hgt  = terrain(j,i)
                tv = virtual(tk(j,i,mkzh,it),.001*wrfqv(j,i,1,it))
                sfp(i,j,it) = pressure*(tv/(tv+ussalr* &
                              (ght(j,i,mkzh,it)-ter_hgt)))**(-9.81/(rgas*ussalr))
                temp(i,j) = sfp(i,j,it)
             enddo
           enddo
          call smooth(temp,nsmooth,iweg,isng,MISSING)
          sfpsm(:,:,it) = temp(:,:)
        enddo
      return

    end SUBROUTINE calcsfp


!------------------------------------------------------------------------------
    SUBROUTINE calcpot(ncid,iweg,isng,nz,times_in_file,tk,prs,qv,vert_pottmps)

      INCLUDE './netcdf.inc'
      integer ncid,nz,times_in_file,iweg,isng,ivar
      integer idir,ripk,mkzh,i,j,k,it,icorsw,kvalue
      integer rcode
      real,   DIMENSION(iweg,isng,nz,times_in_file)             :: tk,vert_pottmps
      real,   DIMENSION(iweg-1,isng-1,times_in_file)            :: coriolis
      real,   DIMENSION(iweg-1,isng-1,nz,times_in_file)         :: prs,qv,hPa_pres
      real,   DIMENSION(iweg-1, isng-1, nz)                     :: temp_array
      real    delta,eps,qmax,tmpk,p,tlclc1,tlclc2,tlclc3,tlclc4
      real    rgas,sclht,rgasmd,cpmd,cp,gamma,gammam,gammamd
    

      rcode =  nf_inq_varid(ncid,"F",ivar)
      rcode = nf_get_var_real ( ncid, ivar, coriolis )


      rgas     = 287.04     !J/K/kg
      cp       = 1004.
      cpmd     = .887
      rgasmd   = .608
      gamma    = rgas/cp
      gammamd  = rgasmd-cpmd


!Convert pressure from Pa to hPa
      hPa_pres =  prs(:,:,:,:) * 0.01


      idir   = 1
      icorsw = 0
      delta  = 0.01

      do it = 1,times_in_file
         temp_array= 0.0
         do k=1,nz
            ripk = nz-k+1
            do j=1,isng-1
            do i=1,iweg-1
               gammam=gamma*(1.+gammamd*qv(i,j,ripk,it))
               temp_array(i,j,k) = tk(i,j,k,it)*(1000./hPa_pres(i,j,ripk,it))**gammam
            enddo
            enddo
         enddo
         icorsw = 0
         call monotonic(vert_pottmps,temp_array,hPa_pres(:,:,:,it),coriolis(:,:,it),idir,delta, &
                        iweg,isng,nz,it,times_in_file,icorsw)
     end do !end for times in file

    end SUBROUTINE calcpot

!------------------------------------------------------------------------------
    SUBROUTINE calceqpot(ncid,iweg,isng,nz,times_in_file,tk,prs,qv,vert_pottmps)

      INCLUDE './netcdf.inc'

      integer ncid,nz,times_in_file,iweg,isng,ivar
      integer idir,ripk,mkzh,i,j,k,it,icorsw,kvalue
      integer rcode
      real,   DIMENSION(iweg,isng,nz,times_in_file)             :: tk,vert_pottmps
      real,   DIMENSION(iweg-1,isng-1,times_in_file)            :: coriolis
      real,   DIMENSION(iweg-1,isng-1,nz,times_in_file)         :: prs,qv,hPa_pres
      real,   DIMENSION(iweg-1, isng-1, nz)                     :: temp_array
      real    delta,eps,qmax,tmpk,p,tlclc1,tlclc2,tlclc3,tlclc4
      real    thtecon1,thtecon2,thtecon3,e,tlcl,ghtagl
      real    rgas,sclht,rgasmd,cpmd,cp,gamma,gammam,gammamd
    

      rgas     = 287.04     !J/K/kg
      rgasmd   = .608
      sclht    = rgas*256./9.81
      cpmd     = .887
      cp       = 1004.
      gamma    = rgas/cp
      gammamd  = rgasmd-cpmd  
      eps      = 0.622
      tlclc1   = 2840.
      tlclc2   = 3.5
      tlclc3   = 4.805
      tlclc4   = 55.
      thtecon1 = 3376. ! K
      thtecon2 = 2.54
      thtecon3 = .81

      rcode =  nf_inq_varid(ncid,"F",ivar)
      rcode = nf_get_var_real ( ncid, ivar, coriolis )


!Convert pressure from Pa to hPa
      hPa_pres =  prs(:,:,:,:) * 0.01

      idir   = 1
      delta  =  0.01
      do it = 1,times_in_file
         temp_array= 0.0
         do k = 1, nz
            ripk =  nz-k+1
            do j = 1, isng-1
            do i = 1, iweg-1
               qmax=max(qv(i,j,ripk,it),1.e-15)
               tmpk=tk(i,j,k,it)
               p=hPa_pres(i,j,ripk,it)
               e=qmax*p/(eps+qmax)
               tlcl=tlclc1/(log(tmpk**tlclc2/e)-tlclc3)+tlclc4
               temp_array(i,j,k) = tmpk*(1000./p)**(gamma*(1.+gammamd*qmax))*  &
                                   exp((thtecon1/tlcl-thtecon2)*qmax*(1.+thtecon3*qmax))
            enddo
            enddo
       enddo
      icorsw = 0
      call monotonic(vert_pottmps,temp_array,hPa_pres(:,:,:,it),coriolis(:,:,it),  &
                     idir,delta,iweg,isng,nz,it,times_in_file,icorsw)
   enddo !end it do loop

   end SUBROUTINE calceqpot



























