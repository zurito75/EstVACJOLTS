/*
Method for estimating vacancies fro agregated Hires
Leonardo+Raquel
+Lags using AIC and BIC from Hires equation H_t=f(V_t, V_t-1, V_t,... )
*/

global rutabox "C:\Users\zurit\Dropbox\JOLTS\OpenCode" /*Here the path where you placed the folder "OpenCode"*/


use  "${rutabox}\Panel.dta", clear
*tab T, g(T_)
destring código_industria, replace
qui gen idN=código_industria
qui gen T=periodo
extrdate year     year=period
extrdate quarter  trim=period
extrdate month    mes  =period
extrdate halfyear sems=period

qui gen Tq=yq(year, trim)
format Tq %tq

xtset idN T

foreach v of varlist HILU JOLU HILS JOLS QULU LDLU OSLU {
*replace `v'=`v'/100
qui tssmooth ma `v'M3=`v', window(2 1 0)
}

*Hirings variable: HILS HILU
global S "U" /*U UM3 S */
*gen H=HIL${S}
global P=1
global L=5
global abs "i.idN i.T i.trim i.idN##i.year  i.idN##c.trend i.idN##c.trend2 i.idN##c.trend3 i.idN##c.trend4"


/*Weights*/
xtset idN T
*Contrataciones
tssmooth ma HILU_MA = l3.HILU, window(0 1 0)
gen one=1
bys one: egen THILU=total(HILU_MA)
gen weigthH=HILU_MA/THILU
bys idN : egen AweigthH=mean(weigthH)
bys idN : egen AweigthH_aux=mean(weigthH) if periodo<ym(2010,01)
bys idN : egen AweigthH2=max(AweigthH_aux)

*br idN T periodo weigthH AweigthH

*Empleo
xtset idN T
tssmooth ma EMLU_MA = EMLU, window(0 1 0)
replace     EMLU    =l1.EMLU_MA


bys one: egen TEMLU=total(EMLU)
gen weigthE=EMLU/TEMLU
bys idN : egen AweigthE=mean(weigthE)
bys idN : egen AweigthE_aux=mean(weigthE) if periodo<ym(2010,01)
bys idN : egen AweigthE2=max(AweigthE_aux)


* * * 
save  "${rutabox}\Panel2.dta", replace
* * *
