/*
Method for estimating vacancies fro agregated Hires
Leonardo+Raquel
+Lags using AIC and BIC from Hires equation H_t=f(V_t, V_t-1, V_t,... )
*/

global rutabox "C:\Users\zurit\Dropbox\JOLTS\OpenCode" /*Here the path where you placed the folder "OpenCode"*/

clear all
set matsize 11000
global imp=0   /*0   -1000000*/
global weigths "weigthE"  /*unos weigthE weigthH AweigthE AweigthH  */
global IC      "best_BIC_Hh"

global start=2020
global poly = 1     /**/

global YI=0
global YF=14   /*0-15*/
global W= 4   /*best window 4/5 years*/
global L= 5
global S "U" /*U UM3 S */
global Rep=100

*set maxvar 10000

if ${poly}==1{
global abs "i.idN i.mes  i.idN##i.year i.idN#c.trend "  /*i.T i.trim i.idN#i.year i.idN#c.trend */
}         /*i.idN i.mes i.idN#i.year i.idN#c.trend */
if ${poly}==2{
global abs "i.idN i.T i.trim i.idN#i.year  i.idN#c.trend i.idN#c.trend2"
}
if ${poly}==3{
global abs "i.idN i.T i.trim i.idN#i.year  i.idN#c.trend i.idN#c.trend2 i.idN#c.trend3"
}




cap log close
log using "${rutabox}\Resultados\JOLTS_prediction.smcl", replace

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
 * * * * * * * * * Window Loop * * * * * * * * * * *
 
/* * * * * * * * * loop bootstrap * * * * * * * * * * * */ 
 
forval Y=$YI/$YF{
display("`Y' `Y' `Y' `Y' `Y' `Y' `Y' `Y' `Y' `Y' `Y' `Y' `Y'")
use "${rutabox}\Panel2.dta", clear
keep if year<2021
gen H=HIL${S}
xtset idN T
gen unos=1
gen Window=`Y'
local yearini=${start}-${W}-`Y'    /*4y windows*/
local yearfin=${start}-`Y'    /*4y windows*/
keep if (period>=ym(`yearini',1) & period<ym(`yearfin',1)) 

*Trends
qui sum T
qui gen trend=T-r(min)+1
forvalues k=2/5{
qui gen trend`k'=(trend^`k')/(100^`k')
}


*Genrating forwards & lags
forval i=1/5{
		qui gen   f`i'H=f`i'.H	
		qui gen   l`i'H=l`i'.H	
}

/*Homogeneous sample*/
gen sample=(H!=. & f1H!=. & f2H!=. & f3H!=. & f4H!=. & f5H!=.) /*& l5H!=.*/  


 * * * * * * * * * Lag Loop * * * * * * * * * * *
forval l=5(-1)1{
global L=`l'	

*Regression text
global intsect  ""
global intsecte ""
global mean     ""
global meanef   ""
global frd      ""

forval i=1/$L{
		/*Constuyendo el texto de las interacciones con sector*/
		*local a "i.year##i.idN##c.f`i'H "
		*local a "i.D14##i.idN##c.f`i'H "
		local a "i.idN#c.f`i'H "
        local m "f`i'H"                                  /*para la media*/
		global intsect "${intsect} `a'"	
		global mean    "${mean} `m'"	
}

dis("${intsect}")
dis("${mean}")

* * * 
*1. Hiring regression heterogenous effects
qui reghdfe  H        ${intsect} if sample==1 [aw=${weigths}], absorb (${abs}, savefe) resid nocons
qui estat ic
matrix IC=r(S) 
capture drop AIC_Ho BIC_Ho
gen AIC_Ho=IC[1,5]
gen BIC_Ho=IC[1,6]
* * * 

*delta
capture drop ef
predict ef, d
qui replace ef=0 if ef<   ${imp}
qui sum ef JOLU

*qui reg  H        ${intsect} ${abs} if sample==1 [aw=${weigths}], nocons
*capture drop H_h
*predict H_h, xb


*Regresiones auxiliares*
capture drop l*ef
forval i=1/$L{
		qui gen   l`i'ef=l`i'.ef
		/*Constuyendo el texto de las interacciones con sector*/
		
		local ae "i.idN#c.l`i'ef "
		global intsecte "${intsecte} `ae'"	
		
        local  me "l`i'ef"                                  /*para la media*/
		global meanef    "${meanef} `me'"	
}

*Homogenous sample
if `l'==5{
*Muestra rezago mayor*
capture drop sample2
gen sample2=(H!=. & ef!=. & l1ef!=. & l2ef!=. & l3ef!=. & l4ef!=. & l5ef!=.) /*& l5H!=.*/  
}
*5. Hiring regression YES heterogenous effects
qui reg H i.idN#c.ef ${intsecte} [aw=${weigths}] if sample2==1, nocons
capture drop H_h
predict H_h, xb
qui estat ic
matrix IC=r(S) 
capture drop AIC_Hh BIC_Hh
gen AIC_Hh=IC[1,5]
gen BIC_Hh=IC[1,6]

preserve
gen Lag=`l'
keep idN T Window Lag ef JOL${S} HIL${S} AIC_* BIC_*  *weigth* H_h
save "${rutabox}\Resultados\AICPanelResultW_`Y'L_`l'.dta", replace
restore

* * * * * * * * * * * *
}
** Variables para identificar el modelo **

}
log close



/*Here we have: 
+Ten windows with 5 years each
+For each window 5 different specification using different forward polynomials
*/

** Append to select best model predictions across window **
clear
set obs 0
forval Y=$YI/$YF{

	forval l=1/5{
	append using "${rutabox}\Resultados\AICPanelResultW_`Y'L_`l'.dta"
	}
}

format T %tm


save "${rutabox}\Resultados\AICPanelResults.dta", replace


use "${rutabox}\Resultados\AICPanelResults.dta", clear
*br idN T Window Lag JOL${S} ef AIC_* BIC_*
/*MSE*/
gen unos=1
bys Window Lag: egen Tot =total(unos)
gen err2=((JOL${S}-ef)^2)   
bys Window Lag: egen Terr2=total(err2)
gen mse=Terr2/Tot

*By block*
bys Window : egen min_mseb=min(mse)
gen best_mseb=(min_mseb==mse) 

/*Best AIC y BIC for each block*/
global modelo "_Hh"
capture drop min_AIC* min_BIC*
foreach m of global modelo {
    
	* * * Por Bloque  * * * in each window the best specification (lag)
	*Valor mínimo
	bys Window: egen min_AIC`m'=min(AIC`m')
	bys Window: egen min_BIC`m'=min(BIC`m')
	*Dummy
	gen best_AIC`m' =(min_AIC`m'==AIC`m')
	gen best_BIC`m' =(min_BIC`m'==BIC`m')

}

    *Refinements within best BIC
	*Lag Mode within best BIC
	gen LagB=Lag if ${IC}==1
    bys idN T: egen mod_lag=mode(LagB), minmode
    gen best_mod=(best_BIC==1) & (Lag==mod_lag)
	*Lag Min within best BIC
    bys idN T: egen min_lag=min(LagB)
    gen best_min=(best_BIC==1) & (Lag==min_lag)
	
	*Windows with mode lag* *Here there can be more that one best_lag per window need to choose the mode again
	bys Window: egen mod_lagW=mode(mod_lag), minmode /*the most frecuent in the group of the frecuent*/
	bys Window: egen min_lagW=mode(min_lag), minmode /*the most frecuent in the group of the most parsimonious*/

	gen best_modWa=1 if (Lag==mod_lagW)
	gen best_minWa=1 if (Lag==min_lagW)
	
	tab Window mod_lagW     if best_modWa==1
	tab Window min_lagW     if best_minWa==1

	*sort idN T Lag Window 
	*br idN T Lag Window  ef JOL${S} HIL${S} H_h best_mseb ${IC} mod_lag best_mod if best_modWa==1 & Window==3
	
	*Best prediction in Aux Regression within best BIC & mode Lag
	gen err=abs(HIL${S}-H_h) if best_BIC==1 & best_mod==1
	bys idN T: egen min_errA=min(err)
    gen best_err=(min_errA==err)

/*File of best specification in each window*/
  preserve
  gen bestlag= mod_lagW
  collapse (min) bestlag, by(Window)
  keep Window bestlag
  save "${rutabox}\Resultados\Bestlag.dta", replace
  restore

*tab T Lag if best_mseb==1
*tab T Lag if best_AIC_Hh==1


/*Best prediction for each window*/
*sort idN T Lag Window 
*br idN T Lag Window  ef JOL${S} HIL${S} H_h best_mseb ${IC} mod_lag best_mod if best_mod==1

** Graph with models with best MSE y and IC **
sort T
foreach v of varlist /*best_mseb best_mod*/ best_modWa /*best_min best_minWa*/ { /* best_mseb   best_BIC*  best_mod best_err  */
preserve
keep if `v'==1          /*best_mseb best_BIC_Hh best_BIC_Hn best_BIC_Hn*/
*keep if best_AIC_Hh==1  /*best_mseb best_BIC_Hh best_BIC_Hn best_BIC_Hn*/

*Averaging the predictions*
collapse (mean) JOL${S} ef ${weigths},   by(idN T)
*bys idN: corr(JOL${S} ef)
corr(JOL${S} ef)

*Chossing the min CI

*Adding up the predictions*
 collapse (sum)  JOL${S} ef , by(T)

tw  (line JOL${S} T  if T<ym(2019,6), lc(black) lw(medthick)) ///
    (line ef T   )   if T<ym(2019,6), ///
    legend(label(1 "JOLU") label(2 "`v'"))  ///
	xtitle("") title("2006 - 2020") graphregion(fcolor(white)) name(`v', replace)
restore
}


/* * * *  Bostraped Standard Errors * * * * */
do "${rutabox}\1.2. Method_Hires_AIC_boots_3.do"

/* * * *  Bostraped Standard Errors * * * * */

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
/*Estimation with Confidence Intervals*/
cls

use "${rutabox}\Resultados\AICPanelResults.dta", clear
duplicates report Window Lag idN T 
merge 1:1 Window Lag idN T  using "${rutabox}\Resultados\BootAICRest.dta", keep(3)
*confidence intervals
qui sum ef ef_std ef_mean

gen ef_CIS=ef + 1.97*ef_std
gen ef_CII=ef - 1.97*ef_std

*Averaging the predictions*
collapse (mean) JOL${S} HIL${S} ef ef_mean ef_CIS ef_CII, by(idN T)
*bys idN: corr(JOL${S} ef)
corr(JOL${S} ef)
*Adding up the predictions*
collapse (sum)  JOL${S} HIL${S} ef ef_mean ef_CIS ef_CII, by(T)


/*min-min*/
*collapse (mean) JOL${S} ef *_BIC* *_AIC* best_mseb min_mseb, by(T Window)
*local m =ustrregexra("`v'","best_" , "min_") /*min(min)*/
*bys T: egen min_`m'=min(`m')
*keep if     min_`m'==`m'

label var ef      "Estimated vacancies"
label var ef_mean "Estimated vacancies mean boots" 
label var ef_CIS  "Upper CI"
label var ef_CII  "Lower CI"
label var JOL${S} "JOLU"

* * * * * 
save "${rutabox}\Resultados\AICSeriesResults.dta", replace
* * * * * 

* * * * * * GRAPHS  GRAPHS  GRAPHS  GRAPHS  GRAPHS  GRAPHS * * * * * * 

* * * * * 
use "${rutabox}\Resultados\AICSeriesResults.dta", replace
* * * * * 

tw  (line JOL${S} T if T<ym(2019,6), lc(black) lw(medthick)) ///
    (line ef      T if T<ym(2019,6), lc(gray)   )    ///
	/*(line ef_mean T if T<ym(2019,6), lc(black)   )*/    ///
    ,/*legend(label(1 "JOLU") label(2 "`v'")) */ ///
	xtitle("") xlabel(504(24)696, labsize(small) angle(h)) ylabel(, labsize(small) angle(h)) ///
	title("2002 - 2019") graphregion(fcolor(white)) name(pointestimate, replace)
graph export "${rutabox}\Resultados\PointEst_S${start}YF_${YF}W_${W}P_${poly}.png", as(png)  replace

tw  (line ef      T if T<ym(2019,6), lc(black)  lw(medthick)) ///
    (line ef_CIS  T if T<ym(2019,6), lc(gray) lp(dash) )    ///
	(line ef_CII  T if T<ym(2019,6), lc(gray) lp(dash)  )    ///
    ,/*legend(label(1 "JOLU") label(2 "`v'"))*/  ///
	xtitle("") xlabel(504(24)696, labsize(small) angle(h)) ylabel(, labsize(small) angle(h)) ///
	title("2002 - 2019") graphregion(fcolor(white)) name(CI, replace)
graph export "${rutabox}\Resultados\CI_S${start}YF_${YF}W_${W}P_${poly}.png", as(png)  replace

tw  (line JOL${S} T if T<ym(2019,6), lc(black) lw(medthick)) ///
    (line ef_CIS  T if T<ym(2019,6), lc(gray) lp(dash) )    ///
	(line ef_CII  T if T<ym(2019,6), lc(gray) lp(dash)  )    ///
    ,/*legend(label(1 "JOLU") label(2 "`v'"))*/  ///
	xtitle("") xlabel(504(24)696, labsize(small) angle(h)) ylabel(, labsize(small) angle(h)) ///
	title("2002 - 2019") graphregion(fcolor(white)) name(CI2, replace)
graph export "${rutabox}\Resultados\CI_S${start}YF_${YF}W_${W}P_${poly}.png", as(png)  replace

graph combine pointestimate CI, graphregion(fcolor(white)) rows(2)
graph export "${rutabox}\Resultados\PointEst_CI_S${start}YF_${YF}W_${W}P_${poly}.png", as(png) name("Graph") replace
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

/*============================================================================*/
/*Seasonal Adjustment*/
capture drop _SA*
keep if T<ym(2019,6)

cd "C:\ado\plus\s"
adopath + "C:\ado\plus\s"
foreach x of varlist ef ef_CIS ef_CII JOLU {
                tsset T, monthly
                sax12  `x', satype(dta)  comptype(mult) transfunc(auto) outauto(all) outlsrun(3) ammaxlag(3 1) ammaxdiff(2 1) ammaxlead(3) ammaxback(3) priormode(diff) ///
                               x11seas(x11default) sliding history noview
  
  
                sax12im "`x'.out", ext(d10 d11 d12 d13)
                sax12im "`x'.out", ext(sp2) noftvar

                gen        `x'_SA=`x'_d11 
                drop `x'_d10 `x'_d11 `x'_d12 `x'_d13
                sax12del `x' 
}      

tsline  ef ef_SA       

tw  (line JOLU_SA T  if T<ym(2019,6), lc(black) lw(medthick)) ///
    (line ef_SA      T if T<ym(2019,6), lc(gray)   )    ///
	/*(line ef_mean T if T<ym(2019,6), lc(black)   )*/    ///
    ,/*legend(label(1 "JOLU") label(2 "`v'")) */ ///
	xtitle("") xlabel(504(24)696, labsize(small) angle(h)) ylabel(, labsize(small) angle(h)) ///
	title("2002 - 2019") graphregion(fcolor(white)) name(pointestimate, replace)
graph export "${rutabox}\Resultados\PointEst_SA.png", as(png)  replace

tw  (line ef_SA      T if T<ym(2019,6), lc(black)  lw(medthick)) ///
    (line ef_CIS_SA  T if T<ym(2019,6), lc(gray) lp(dash) )    ///
	(line ef_CII_SA  T if T<ym(2019,6), lc(gray) lp(dash)  )    ///
    ,/*legend(label(1 "JOLU") label(2 "`v'"))*/  ///
	xtitle("") xlabel(504(24)696, labsize(small) angle(h)) ylabel(, labsize(small) angle(h)) ///
	title("2002 - 2019") graphregion(fcolor(white)) name(CI, replace)
graph export "${rutabox}\Resultados\CIE_SA.png", as(png)  replace

tw  (line JOLU_SA    T if T<ym(2019,6), lc(gray)  lp(shortdash)   lw(thick)) ///
    (line ef_SA      T if T<ym(2019,6), lc(black)  lw(medthick)) ///
    (line ef_CIS_SA  T if T<ym(2019,6), lc(gray)   lp(dash) )    ///
	(line ef_CII_SA  T if T<ym(2019,6), lc(gray)   lp(dash)  )    ///
    ,/*legend(label(1 "JOLU") label(2 "`v'"))*/  ///
	xtitle("") xlabel(504(24)696, labsize(small) angle(h)) ylabel(, labsize(small) angle(h)) ///
	title("2002 - 2019") graphregion(fcolor(white)) name(CI2, replace)
graph export "${rutabox}\Resultados\CIJOLU_SA.png", as(png)  replace

graph combine pointestimate CI, graphregion(fcolor(white)) rows(2)
graph export "${rutabox}\Resultados\PointEst_CI_S${start}YF_${YF}W_${W}P_${poly}.png", as(png) name("Graph") replace
/*============================================================================*/


