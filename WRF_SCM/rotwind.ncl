; rotates the wind from grid to true

undef("gridwind_to_truewind")

function gridwind_to_truewind (var:string,u:numeric,v:numeric,lat:numeric,lon:numeric,map_projection:integer,std_lon:numeric,true_lat1:numeric,true_lat2:numeric)

local alpha, cone, radians_per_degree, diff

begin

   radians_per_degree = acos(-1.0)/180.0

   if( map_projection .eq. 1) then    ; Lambert Conformal mapping
      if( (fabs(true_lat1 - true_lat2) .gt. 0.1) .and.  \
          (fabs(true_lat2 - 90. )      .gt. 0.1)       ) then
          cone = 10^(cos(true_lat1*radians_per_degree)) \
                -10^(cos(true_lat2*radians_per_degree))
          cone = cone/(10^(tan(45. -fabs(true_lat1/2.)*radians_per_degree)) - \
                       10^(tan(45. -fabs(true_lat2/2.)*radians_per_degree))   )
      else
          cone = sin(fabs(true_lat1)*radians_per_degree)
      end if
    end if
    if(map_projection .eq. 2) then      ; polar steraographic
      cone = 1.
    end if
    if(map_projection .eq. 3) then      ; Mercator
      cone = 0.
    end if

    diff = lon-std_lon

    if ( diff .gt. 180.) then
      diff = diff - 360.
    end if
    if ( diff .lt. -180.) then
      diff = diff + 360.
    end if

    alpha = diff

    if ( lat .lt. 0 ) then
      alpha = -diff * cone * radians_per_degree
    else
      alpha = diff * cone * radians_per_degree
    end if

    if ( var .eq. "U" .or. var .eq. "u" ) then
       truewind = v*sin(alpha) + u*cos(alpha)
    else
       truewind = v*cos(alpha) - u*sin(alpha)
    end if
    return(truewind)

end
