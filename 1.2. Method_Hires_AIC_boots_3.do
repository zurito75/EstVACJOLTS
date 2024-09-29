/*
Method for estimating vacancies fro agregated Hires
Leonardo+Raquel
+Lags using AIC and BIC from Hires equation H_t=f(V_t, V_t-1, V_t,... )
*/

/*Window with
forval A=4/7{
global Rep=100
global YI=0    /*0-10*/
global YF=10   /*0-10*/
global W= `A'    /*best window 4/5 years*/
clear all
set maxvar  10000
set matsize 10000
*use  "\\wmedesrv\GrupoMercadoLaboral\LeonardoMorales\JOLTS\Panel.dta", clear
global rutabox "$DROPBOX\JOLTS\"
global rutabox "C:\Users\zurit\Dropbox\JOLTS\" 
global rutabox "C:\Users\lmoralzu\Dropbox\JOLTS\"
global abs "i.idN i.T i.trim i.idN##i.year  i.idN##c.trend i.idN##c.trend2 i.idN##c.trend3 i.idN##c.trend4"
*/
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
 * * * * * * * * * Window Loop * * * * * * * * * * *

dis("$Rep")
dis("$YI")
dis("$YF") 
dis("$W")
dis("$imp")
 
/* * * * * * * * * loop bootstrap * * * * * * * * * * * */ 
forval Y=$YI/$YF{
display("`Y' `Y' `Y' `Y' `Y' `Y' `Y' `Y' `Y' `Y' `Y' `Y' `Y'")
use  "${rutabox}\Panel2.dta", clear
gen H=HIL${S}
capture drop Window
gen Window=`Y'
local yearini=${start}-${W}-`Y'    /*4y windows*/
local yearfin=${start}-`Y'    /*4y windows*/
keep if (period>=ym(`yearini',1) & period<ym(`yearfin',1)) 

/*Merge with best specification*/
merge m:1 Window  using "${rutabox}\Resultados\Bestlag.dta", keep(3) nogen
qui sum bestlag
global BL=r(mean)
di("${BL}")

 * * * * * * * * * Lag Loop * * * * * * * * * * *
global L=$BL	

*Regression text
global intsect  ""
global intsecte ""
global mean     ""
global meanef   ""
global frd      ""
xtset 
forval i=1/$L{
		/*Constuyendo el texto de las interacciones con sector*/
		*local a "i.year##i.idN##c.f`i'H "
		*local a "i.D14##i.idN##c.f`i'H "
		local a "i.idN#c.f`i'H "
        local m "f`i'H"                                  /*para la media*/
		global intsect "${intsect} `a'"	
		global mean    "${mean} `m'"	
}

*dis("${intsect}")
*dis("${mean}")

* * * 
*1. Hiring regression heterogenous effects
/*boostraped standard error of the ef component only for the best AIC*/

mkmat idN T Window, matrix(Res)
forvalues b=1/$Rep{
display("`b' `b' `b' `b' `b' `b' `b' `b' `b' `b' `b' `b' `b'")

preserve
/*********************Random Sample ****************/
bsample , /*strata(T)*/ cluster(idN) idcluster(idN2)
qui replace idN=idN2
xtset idN T

*Trends   /*In or Out?*/
capture drop trend*
qui sum T
qui gen trend=T-r(min)+1
forvalues k=2/5{
qui gen trend`k'=(trend^`k')/(100^`k')
}
*Genrating forwards & lags   /*In or Out?*/
xtset 
forval i=1/5{
		qui gen   f`i'H=f`i'.H	
}
/*Homogeneous sample*/
gen sample=(H!=.  & f1H!=. & f2H!=. & f3H!=. & f4H!=. & f5H!=.) /*& l5H!=.*/  


qui reghdfe  H        ${intsect} if sample==1 [aw=${weigths}], absorb (${abs}, savefe) resid nocons
predict ef`b', d
qui replace ef=0 if ef<   ${imp}
*sum ef`b' JOLU
mkmat ef`b', matrix(ef`b')
matrix Res=[Res, ef`b']

restore
                    } /*loop   lag   */
clear
svmat Res, names(matcol)
save "${rutabox}\Resultados\BootAICRestW_`Y'.dta", replace
}                     /*loop   Window*/
clear
set obs 0

forval Y=$YI/$YF{
append using  "${rutabox}\Resultados\BootAICRestW_`Y'.dta"
}

egen ef_mean=rmean(Resef*)
forvalues b=1/$Rep{
gen d_Resef`b'=(Resef`b'-ef_mean)^2
}
egen    ef_std=  rmean(d_Resef*)
qui replace ef_std=(ef_std/${Rep})^0.5
qui sum ef_mean ef_std
rename (ResidN ResT ResWindow) (idN T Window)
keep idN T Window  ef_mean ef_std

merge m:1 Window  using "${rutabox}\Resultados\Bestlag.dta", keep(3) nogen
rename bestlag Lag
save  "${rutabox}\Resultados\BootAICRest.dta", replace
