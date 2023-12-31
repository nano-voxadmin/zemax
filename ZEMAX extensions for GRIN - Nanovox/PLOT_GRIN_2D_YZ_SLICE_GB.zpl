! PLOT_GRIN_2D_YZ_SLICE_GB.zpl
! Written by Guy Beadie, Nov. 30, 2018

! Modified from a macro originally developed at Voxtel.
! Original author almost certainly Don Conkey, date unknown

! Original macro meant to depict flat-flat lenses, so
! surface curvatures and plotting index values out in air
! were irrelevant.

! This macro assumes that the **surfaces** are rotationally symmetric, though not the GRIN

INPUT "Enter GRIN surface:", S
INPUT "Flip background color? (y or Y)", Ans$

IF (Ans$ $== "y") | (Ans$ $== "Y")
	Flip_Back = 1
ELSE
	Flip_Back = 0
ENDIF

Nh = 150			# Dicates plot density - 2*Nh points along vertical direction, scaled thickness

tc = THIC(S)		# Lens thickness
sd1 = SDIA(S)	# Semi-diameter of the front surface
sd2 = SDIA(S+1)	# Semi-diameter of the back surface

IF (sd1 == sd2)
	radius = sd1
	min_sd = sd1
ELSE	
	DrawFlag = SPRO(S, 96)	# Read "Draw Edge As" value
	IF (sd1 < sd2)
		min_sd = sd1
		radius = sd2
		zcorner1 = sagg(0,sd1,S)
		zcorner2 = sagg(0,sd2,S+1) + tc
	ELSE
		min_sd = sd2
		radius = sd1
		zcorner1 = sagg(0,sd1,S)
		zcorner2 = sagg(0,sd2,S+1) + tc
	ENDIF
ENDIF

! Scan acroos the lens to define the lens surfaces
DECLARE Surfs, DOUBLE, 2, 2, Nh
minz1 = 1000000
maxz2 = -1000000
FOR ir, 0, Nh-1, 1
	r = ir*(radius/(Nh-1))
	
	! Get the front surface z value (including cases where the front surface is smaller than the back surface)
	IF r <= sd1
		z1 = sagg(0,r,S)
	ELSE	
		IF DrawFlag == 1
			! Zemax draws a straight taper from the edge of surface 1 to the edge of surface 2
			f = (r - sd1) / (sd2 - sd1)
			z1 = zcorner1 + f * (zcorner2 - zcorner1)
		ELSE
			! Zemax squares off the smaller surface to the sag at the edge of the clear aperture
			z1 = zcorner1
		ENDIF
	ENDIF
	
	! Store the back surface z value (including cases where the back surface is smaller than the front surface)
	IF r <= sd2
		z2 = tc + sagg(0,r,S+1)
	ELSE
		IF DrawFlag == 1
			! Zemax draws a straight taper from the edge of surface 1 to the edge of surface 2
			f = (r - sd2) / (sd1 - sd2)
			z2 = zcorner2 + f * (zcorner1 - zcorner2)
		ELSE
			! Zemax squares off the smaller surface to the sag at the edge of the clear aperture
			z2 = zcorner2
		ENDIF
	ENDIF
	
	IF z1 < minz1 THEN minz1 = z1
	IF z2 > maxz2 THEN maxz2 = z2
	Surfs(1,ir+1) = z1
	Surfs(2,ir+1) = z2
NEXT

t = maxz2 - minz1
AR = 2*radius/t
Nz = INTE(Nh*2/AR)
rhomax = Nh-1
zmax = Nz-1

waven = PWAV()	# Uses primary wavelength
DECLARE nval, DOUBLE, 2, Nz, 2*Nh-1

max = -100000
min = 100000
nsum = 0
npts_in = 0
npts_out = 0

drho = radius/rhomax
dz = t/zmax

nbck = -10	# Background "index" value to assign to points outside the lens volume
			#  where nbck < (any index value expected inside the lens)
FOR ir, 0 , rhomax, 1
	FOR iz, 0, zmax, 1
	    rho = ir*drho
	    zed = minz1 + iz*dz
		IF ((Surfs(1,ir+1) <= zed) & (zed <= Surfs(2,ir+1)))
			! Point inside lens
			nplusrho = GRIN(S,waven,0,rho,zed)
			nminusrho = GRIN(S,waven,0,-rho,zed)

			nval(iz+1,Nh-ir) = nminusrho
			nval(iz+1,Nh+ir) = nplusrho

			nsum = nsum + nplusrho + nminusrho
			npts_in = npts_in + 2
			
			IF (nplusrho >= nminusrho)
				nbig = nplusrho
				nsmall = nminusrho
			ELSE
				nbig = nminusrho
				nsmall = nplusrho
			ENDIF
	    
			! Update max and min values
			IF nbig > max
				max = nbig
			ENDIF
			IF nsmall < min
				min = nsmall
			ENDIF
		ELSE
			! Point not inside lens
			nval(iz+1,Nh-ir) = nbck
			nval(iz+1,Nh+ir) = nbck
			npts_out = npts_out + 2
		ENDIF
	NEXT
NEXT

IF (npts_out > 0)
	! Some points are plotted in air, so need to pick a background value and tweak the plot ranges to increase
	! the color contrast of inside versus outside data points.
	IF (npts_in > 0)
		navg = nsum / npts_in
	ELSE	
		navg = max
	ENDIF
	
	! My hack to defeat default background assignment - if Flip_Back set to 1, change navg
	IF (Flip_Back == 1) THEN navg = max - (navg-min)

	IF ( (navg-min) <= (max-navg) )
		! Average index of the lens is closer to nmin than nmax ... 
		! reset the background level to a high number to increase color contrast
		nbck_new = max*2
		plotmin = min
		plotmax = max + (max-min)*0.05	# Set it up so no point in the lens has the same color as the background
		FOR ir, 0 , rhomax, 1
			FOR iz, 0, zmax, 1			
				IF (nval(iz+1,Nh-ir) == nbck)
					! Point outside lens
					nval(iz+1,Nh-ir) = nbck_new
					nval(iz+1,Nh+ir) = nbck_new
				ENDIF
			NEXT
		NEXT
	ELSE	
		plotmin = min - (max-min)*0.05	 # Set it up so no point in the lens has the same color as the background
		plotmax = max
	ENDIF
ELSE	 # Lens does not have curved surfaces - all points are inside the data mesh
	plotmin = min
	plotmax = max
ENDIF

IF UNIT() == 0 THEN theunit$ = "mm"
IF UNIT() == 1 THEN theunit$ = "cm"
IF UNIT() == 2 THEN theunit$ = "in"
IF UNIT() == 3 THEN theunit$ = "m"


! PLOT2D NEW
! PLOT2D COMM1, "Gradient Index Profile"
! PLOT2D ASPECT, 
! PLOT2D RANGE, min, max
! PLOT2D CONTOURINTERVAL, 0.01
! PLOT2D DISPLAYTYPE, 2
! PLOT2D DATA, nval
! PLOT2D GO

FORMAT 1.4
PLOT2D NEW
PLOT2D COMM1, "Gradient Index Profile"
PLOT2D COMM2, "Lens min index = " + $STR(min)
PLOT2D COMM3, "Lens max index = " + $STR(max)
PLOT2D COMM4, "Plotted height = " + $STR(2*radius) + theunit$
PLOT2D COMM4, "Plotted width = " + $STR(t) + theunit$
PLOT2D RANGE, plotmin, plotmax
PLOT2D DISPLAYTYPE, 5
PLOT2D DATA, nval
PLOT2D GO
