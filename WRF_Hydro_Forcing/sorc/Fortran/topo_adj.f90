!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! program topo_adj.f90
! to do the topo adjustment
! email: lpan@ucar.edu
! 07/20/2015
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	subroutine topo_adj(hgt,xlat,xlong,dx,dy,nx,ny,cosa, sina, xtime, julian,swdown_in, swdown_out)	
	real,    intent (in)  :: hgt(nx,ny)
	real,    intent (in)  :: xlat(nx,ny)
	real,    intent (in)  :: xlong(nx,ny)
	real,    intent (in)  :: cosa(nx,ny)
	real,    intent (in)  :: sina(nx,ny)
	real,    intent (in)  :: dx, dy
	real,    intent (in)  :: xtime, julian
	real,    intent (in)  :: swdown_in(nx,ny)
	real,    intent (out) :: swdown_out(nx,ny)
	real                  :: slope(nx,ny)
	real                  :: swdown(nx,ny)
	real                  :: SWNORM(nx,ny)
	real                  :: GSWSAVE(nx,ny)
	real                  :: slp_azi(nx,ny)
	integer                  :: shadowmask(nx,ny)
	real                  :: coszen_loc(nx,ny), hrang_loc(nx,ny)
	real                  :: pi, DEGRAD, DPD
	real                  :: SOLCON, DECLIN
	real	              :: gmt
	real	              :: diffuse_frac(nx,ny)
	real	              :: GSW(nx,ny)
	integer, intent (in)  :: nx, ny
	write(*,*)'topo_adj'
	call cal_slope( hgt, 1, ny, 1, nx, dx, dy, cosa, sina, slope, slp_azi)
	pi = 4. *atan (1.)
	DEGRAD = pi / 180.
	DPD = 360./365.
	gmt = 0. 
        CALL radconst(XTIME,DECLIN,SOLCON,JULIAN,                 &
                       DEGRAD,DPD             )
        call calc_coszen(1,nx,1,ny,                               &
                          julian,xtime,gmt,declin,degrad,         &
                          xlong,xlat,coszen_loc,hrang_loc)
	SWDOWN= swdown_in
	SWNORM= swdown_in
	GSWSAVE = swdown_in
	GSW = swdown_in
	shadowmask=0.
	diffuse_frac=0.
	call TOPO_RAD_ADJ_DRVR (XLAT,XLONG,coszen_loc,            &
                    shadowmask, diffuse_frac,                     &
                    declin,                                       &
                    SWDOWN,GSW,SWNORM,GSWSAVE,solcon,hrang_loc,     &
                    slope,slp_azi,                                &
                    1, nx, 1, ny                       )
	 swdown_out=SWDOWN


	
	end subroutine topo_adj

	subroutine cal_slope( ht, jts, jte, its, ite, dx, dy, cosa, sina, slope, slp_azi)
	! set up slope-radiation constant arrays based on topography
	integer, intent (in) :: its, ite, jts, jte
	real,    intent (in) :: dx, dy            
	real,    intent (in) :: ht(ite,jte)
	real,    intent (in) :: cosa(ite,jte)
	real,    intent (in) :: sina(ite,jte)
	real,    intent (out) :: slope(ite,jte)
	real,    intent (out) :: slp_azi(ite,jte)
	real                 :: msftx(ite,jte)
	real                 :: msfty(ite,jte)
	real                 :: toposlpx(ite,jte)
	real                 :: toposlpy(ite,jte)
	real                 :: rdx,rdy
	real                 :: hx, hy, pi
	integer              :: i, j, im1, ip1, jm1, jp1
	rdx=1./dx
	rdy=1./dy
	msftx=1.
	msfty=1.
!
       DO j = jts,jte
       DO i = its, ite
          im1 = i-1
          ip1 = i+1
          jm1 = j-1
          jp1 = j+1
	  if(im1.le.1) im1=1
	  if(jm1.le.1) jm1=1
	  if(ip1.ge.ite) ip1=ite
	  if(jp1.ge.jte) jp1=jte
          toposlpx(i,j)=(ht(ip1,j)-ht(im1,j))*msftx(i,j)*rdx/(ip1-im1)
          toposlpy(i,j)=(ht(i,jp1)-ht(i,jm1))*msfty(i,j)*rdy/(jp1-jm1)
             hx = toposlpx(i,j)
             hy = toposlpy(i,j)
             pi = 4.*atan(1.)
             slope(i,j) = atan((hx**2+hy**2)**.5)
             if (slope(i,j).lt.1.e-4) then
               slope(i,j) = 0.
               slp_azi(i,j) = 0.
             else
               slp_azi(i,j) = atan2(hx,hy)+pi

! Rotate slope azimuth to lat-lon grid
               if (cosa(i,j).ge.0) then
                 slp_azi(i,j) = slp_azi(i,j) - asin(sina(i,j))
               else
                 slp_azi(i,j) = slp_azi(i,j) - (pi - asin(sina(i,j)))
               endif
            endif
       ENDDO
       ENDDO
	write(*,*)'subroutine cal_slope'
	end subroutine cal_slope	
!---------------------------------------------------------------------
!BOP
! !IROUTINE: radconst - compute radiation terms
! !INTERFAC:
   SUBROUTINE radconst(XTIME,DECLIN,SOLCON,JULIAN,                   &
                       DEGRAD,DPD                                    )
!---------------------------------------------------------------------
!   USE module_wrf_error
   IMPLICIT NONE
!---------------------------------------------------------------------

! !ARGUMENTS:
   REAL, INTENT(IN   )      ::       DEGRAD,DPD,XTIME,JULIAN
   REAL, INTENT(OUT  )      ::       DECLIN,SOLCON
   REAL                     ::       OBECL,SINOB,SXLONG,ARG,  &
                                     DECDEG,DJUL,RJUL,ECCFAC
!
! !DESCRIPTION:
! Compute terms used in radiation physics
!EOP

! for short wave radiation

   DECLIN=0.
   SOLCON=0.

!-----OBECL : OBLIQUITY = 23.5 DEGREE.

   OBECL=23.5*DEGRAD
   SINOB=SIN(OBECL)

!-----CALCULATE LONGITUDE OF THE SUN FROM VERNAL EQUINOX:

   IF(JULIAN.GE.80.)SXLONG=DPD*(JULIAN-80.)
   IF(JULIAN.LT.80.)SXLONG=DPD*(JULIAN+285.)
   SXLONG=SXLONG*DEGRAD
   ARG=SINOB*SIN(SXLONG)
   DECLIN=ASIN(ARG)
   DECDEG=DECLIN/DEGRAD
!----SOLAR CONSTANT ECCENTRICITY FACTOR (PALTRIDGE AND PLATT 1976)
   DJUL=JULIAN*360./365.
   RJUL=DJUL*DEGRAD
   ECCFAC=1.000110+0.034221*COS(RJUL)+0.001280*SIN(RJUL)+0.000719*  &
          COS(2*RJUL)+0.000077*SIN(2*RJUL)
   SOLCON=1370.*ECCFAC

   END SUBROUTINE radconst

   SUBROUTINE calc_coszen(its,ite,jts,jte,  &
                          julian,xtime,gmt, &
                          declin,degrad,xlon,xlat,coszen,hrang)
       ! Added Equation of Time correction : jararias, 2013/08/10
       implicit none
       integer, intent(in) :: its,ite,jts,jte
       real, intent(in)    :: julian,declin,xtime,gmt,degrad
       real, dimension(its:ite,jts:jte), intent(in)    :: xlat,xlon
       real, dimension(its:ite,jts:jte), intent(inout) :: coszen,hrang

       integer :: i,j
       real    :: da,eot,xt24,tloctm,xxlat

       da=6.2831853071795862*(julian-1)/365.
       eot=(0.000075+0.001868*cos(da)-0.032077*sin(da) &
            -0.014615*cos(2*da)-0.04089*sin(2*da))*(229.18)
       xt24=mod(xtime,1440.)+eot
       do j=jts,jte
          do i=its,ite
             tloctm=gmt+xt24/60.+xlon(i,j)/15.
             hrang(i,j)=15.*(tloctm-12.)*degrad
             xxlat=xlat(i,j)*degrad
             coszen(i,j)=sin(xxlat)*sin(declin) &
                        +cos(xxlat)*cos(declin) *cos(hrang(i,j))
          enddo
       enddo
   END SUBROUTINE calc_coszen

!------------------------------------------------------------------
!------------------------------------------------------------------
   SUBROUTINE TOPO_RAD_ADJ (XLAT1,XLONG1,COSZEN,                 &
                    diffuse_frac_in,DECLIN,DEGRAD,               &
                    SWDOWN_IN,solcon,hrang,SWDOWN_teradj,        &
                    slope,slp_azi,                               &
                    shadow                                       &
                    ,i,j)

!------------------------------------------------------------------
   IMPLICIT NONE
!------------------------------------------------------------------
  REAL, INTENT(IN)          :: COSZEN,DECLIN,              &
                               XLAT1,XLONG1,DEGRAD
  REAL, INTENT(IN)          :: SWDOWN_IN,solcon,hrang
  INTEGER, INTENT(IN)       :: shadow
  REAL, INTENT(IN)          :: slp_azi,slope
  REAL, INTENT(IN)          :: diffuse_frac_in

  REAL, INTENT(OUT)         :: SWDOWN_teradj

! LOCAL VARS
   REAL            :: XT24,TLOCTM,CSZA,XXLAT
   REAL            :: diffuse_frac,corr_fac,csza_slp
   integer         :: i,j


!------------------------------------------------------------------

     SWDOWN_teradj=SWDOWN_IN

     CSZA=COSZEN
     XXLAT=XLAT1*DEGRAD

! RETURN IF NIGHT
         IF(CSZA.LE.1.E-4) return
!  Parameterize diffuse fraction of global solar radiation as a function of the ratio 
!    between TOA radiation and surface global radiation
!             diffuse_frac = min(1.,1./(max(0.1,2.1-2.8*log(log(csza*solcon/max(SWDOWN_IN,1.e-3))))))
              diffuse_frac = diffuse_frac_in
        if ((slope.eq.0).or.(diffuse_frac.eq.1).or.(csza.le.1.e-4)) then
!  no topographic effects when all radiation diffuse or sun too close to horizon
          corr_fac = 1
          if(shadow.eq.1) corr_fac = diffuse_frac
          goto 140
        endif

! cosine of zenith angle over sloping topography
        csza_slp = ((SIN(XXLAT)*COS(HRANG))*                                          &
                    (-cos(slp_azi)*sin(slope))-SIN(HRANG)*(sin(slp_azi)*sin(slope))+  &
                    (COS(XXLAT)*COS(HRANG))*cos(slope))*                              &
                   COS(DECLIN)+(COS(XXLAT)*(cos(slp_azi)*sin(slope))+                 &
                   SIN(XXLAT)*cos(slope))*SIN(DECLIN)
        IF(csza_slp.LE.1.E-4) csza_slp = 0

! Topographic shading
        if (shadow.eq.1) csza_slp = 0

! Correction factor for sloping topography; the diffuse fraction of solar radiation 
!   is assumed to be unaffected by the slope
        corr_fac = diffuse_frac + (1-diffuse_frac)*csza_slp/csza

 140        continue
	if(csza.le.1.e-4)corr_fac=1.
	if(corr_fac>1.3)then
	  corr_fac=1.3
	end if

      SWDOWN_teradj=(1.)*SWDOWN_IN*corr_fac

   END SUBROUTINE TOPO_RAD_ADJ

!=======================================================================
!-------------------------------------------------------------------------

     SUBROUTINE TOPO_RAD_ADJ_DRVR (XLAT,XLONG,COSZEN,               &
                    shadowmask, diffuse_frac,                     &
                    declin,                                       &
                    SWDOWN,GSW,SWNORM,GSWSAVE,solcon,hrang2d,     &
                    slope_in,slp_azi_in,                          &
                its, ite, jts, jte                       )
!------------------------------------------------------------------
   IMPLICIT NONE
!------------------------------------------------------------------
   INTEGER, INTENT(IN)   ::       its,ite,jts,jte
   INTEGER, DIMENSION( its:ite, jts:jte ),                        &
         INTENT(IN)      ::       shadowmask
   REAL, DIMENSION( its:ite, jts:jte ),                           &
         INTENT(IN)      ::       diffuse_frac
   REAL, DIMENSION( its:ite, jts:jte ),                           &
         INTENT(IN   )   ::       XLAT,XLONG
   REAL, DIMENSION( its:ite, jts:jte ),                           &
         INTENT(INOUT)   ::       SWDOWN,GSW,SWNORM,GSWSAVE
   real,intent(in)  :: solcon
   REAL, DIMENSION( its:ite, jts:jte ), INTENT(IN   ) :: hrang2d,coszen


   REAL, INTENT(IN    )  ::       declin
   REAL, DIMENSION( its:ite, jts:jte ), INTENT(IN   ) :: slope_in,slp_azi_in


! LOCAL VARS
   integer    :: i,j
   real       :: pi,degrad
   integer    :: shadow
   real       :: swdown_teradj,swdown_in,xlat1,xlong1

!------------------------------------------------------------------
     pi = 4.*atan(1.)
     degrad=pi/180.

       DO J=jts,jte
       DO I=its,ite
         SWNORM(i,j) = SWDOWN(i,j)     ! save
         IF(SWDOWN(I,J) .GT. 1.E-3)THEN  ! daytime
             shadow = shadowmask(i,j)

         SWDOWN_IN = SWDOWN(i,j)
         XLAT1 = XLAT(i,j)
         XLONG1 = XLONG(i,j)
         CALL TOPO_RAD_ADJ (XLAT1,XLONG1,COSZEN(i,j),             &
                    diffuse_frac(i,j),DECLIN,DEGRAD,              &
                    SWDOWN_IN,solcon,hrang2d(i,j),SWDOWN_teradj,  &
                    slope_in(i,j),slp_azi_in(i,j),                &
                    shadow , i,j                                  &
                    )

         GSWSAVE(I,J) = GSW(I,J)       ! save
         GSW(I,J) = GSW(I,J)*SWDOWN_teradj/SWDOWN(i,j)
         SWDOWN(i,j) = SWDOWN_teradj

         ENDIF ! daytime
       ENDDO  ! i_loop
       ENDDO  ! j_loop


   END SUBROUTINE TOPO_RAD_ADJ_DRVR
!------------------------------------------------------------------

