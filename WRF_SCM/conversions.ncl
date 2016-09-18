undef("get_qv")
undef("get_theta")
undef("get_w_from_ww")


function get_qv(f:list,fList:string,rh:numeric)

; computes qv from rh.  rh in %, qv in kg/kg.  P must be Pa and T must be K in
; files in list

local Lv, Rv, Rd, e0, T0, eps, es, T, e

begin

; some constants, borrowed from the WRF constants
Lv = 2.5e6
Rv = 461.6
Rd = 287.0
e0 = 0.6112
T0 = 273.15
eps = Rd/Rv

T = addfiles_GetVar(f,fList,"TT")

es = e0*1000.0*exp(Lv/Rv*(1/T0 - 1/T))
delete(T)

e = rh/100.0 * es

P = addfiles_GetVar(f,fList,"PRES")

qv = eps*e/(P-e)
delete(P)

return(qv)

end

;----------------------------------------------------------------

function get_theta(f:list,fList:string,t:numeric)

; computes theta from t.  P must be Pa and T must be K in
; files in list

local P0, P

begin

; only one constant
P0 = 100000.0

P = addfiles_GetVar(f,fList,"PRES")

theta = t*(P0/P)^(2.0/7.0)
delete(P)

return(theta)

end

;----------------------------------------------------------------

function get_w_from_ww(f:list,fList:string,ww:numeric)

; computes w from omega (ww).  ww in Pa/s, w in m/s.  P must be Pa and T must be K in
; files in list

local Rd, T, P, g

begin

; some constants, borrowed from the WRF constants
Rd = 287.0
g = 9.81

T = addfiles_GetVar(f,fList,"TT")
P = addfiles_GetVar(f,fList,"PRES")

w = -ww*Rd*T/(P*g)

delete(P)
delete(T)

return(w)

end


