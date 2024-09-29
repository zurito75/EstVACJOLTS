/*
Dofile: Datos JOLTS
Author: Leonardo Morales, Raquel Zapata
Updated: Sept/2024
*/

global rutabox "C:\Users\zurit\Dropbox\JOLTS\OpenCode" /*Here the path where you placed the folder "OpenCode"*/


* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
* * * * * * * * * * * *  * * * D A T O S    J O L T S * * * * * * * * * * * * * * * * * 
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

//variable de periodo
import excel "${rutabox}\JOLTS.xlsx", sheet("Original") firstrow clear

gen mes= substr(period, -2,.)
destring mes, replace
gen periodo= ym(year, mes) 
format %tm periodo
// otras variables
gen estacional= substr(series_id, 3,1)
gen código_industria= substr(series_id, 4,6)
gen state_code= substr(series_id, 10,2)
gen sizeclass_code= substr(series_id, 17,2)
gen dataelement_code= substr(series_id, 19,2)
gen ratelevel_code= substr(series_id, 21,1)
drop if periodo==.
drop mes year period series_id 

save "${rutabox}\Data.dta", replace



use "${rutabox}\Data.dta", clear
tab código_industria state_code 

* * * *
drop if código_industria=="000000" | código_industria=="100000"
tab código_industria state_code

* * * * *
tab código_industria sizeclass_code, m

egen var=concat(dataelement_code ratelevel_code estacional)
tab  var
drop state_code sizeclass_code estacional dataelement_code ratelevel_code

*Data bases*
global var "HILS HILU HIRS HIRU JOLS JOLU JORS JORU LDLS LDLU LDRS LDRU OSLS OSLU OSRS OSRU QULS QULU QURS QURU TSLS TSLU TSRS TSRU" 

foreach v of global var {
preserve
keep if var=="`v'"
rename value `v'
drop var
save "${rutabox}\Datos/`v'.dta", replace
restore
}




* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
* * * * * * * * * * * *  * * *  D A T A      C E S  * * * * * * * * * * * * * * * * * 
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

global seasonal "U S" /*S: Seasonally Adjusted, U: Not Seasonally Adjusted*/

foreach s of global seasonal {
import delimited "${rutabox}\Empleo CES\ce.data.0.AllCESSeries.txt", clear
drop footnote_codes
drop if year<2000 | period=="M13"

*Fecha
gen month=substr(period,2,2)
destring month, replace
gen periodo=ym(year, month)
format periodo %tm

*Employment
keep if substr(series_id, 12, 2)=="01"   /*ALL EMPLOYEES, THOUSANDS*/
keep if substr(series_id, 3, 1) =="`s'"

* Para parear con JOLTS
gen idN2=substr(series_id, 4, 8)
gen idN=.
tostring idN, replace
replace idN="110099" if idN2=="10000000" 					/*(L2) Mining and logging*/
replace idN="230000" if idN2=="20000000" 					/*(L2) Construction*/
replace idN="320000" if idN2=="31000000" 					/*(L3) Durable goods (manufacturing)*/
replace idN="340000" if idN2=="32000000" 					/*(L3) Nondurable goods (manufacturing)*/
replace idN="420000" if idN2=="41420000" 					/*(L3) Wholesale trade*/
replace idN="440000" if idN2=="42000000" 					/*(L3) Retail trade*/
replace idN="480099" if idN2=="43000000" | idN2=="44220000" /*(L3) Transportation and warehousing / (L3) Utilities*/
replace idN="510000" if idN2=="50000000" 					/*(L2) Information*/
replace idN="520000" if idN2=="55520000" 					/*(L3) Finance and insurance*/
replace idN="530000" if idN2=="55530000" 					/*(L3) Real estate and rental and leasing*/
replace idN="540099" if idN2=="60000000" 					/*(L2) Professional and business services*/
replace idN="610000" if idN2=="65610000" 					/*(L3) Educational services*/
replace idN="620000" if idN2=="65620000" 					/*(L3) Health care and social assistance*/
replace idN="710000" if idN2=="70710000" 					/*(L3) Arts, entertainment, and recreation*/
replace idN="720000" if idN2=="70720000" 					/*(L3) Accommodation and food services*/
replace idN="810000" if idN2=="80000000" 					/*(L2) Other services*/
replace idN="910000" if idN2=="90910000" 					/*(L3) Federal*/
replace idN="920000" if idN2=="90920000" | idN2=="90930000" /*(L3) State government / (L3) Local government*/

keep if idN!="."
drop series_id year period month idN2

*Sumando industrias separadas
collapse (sum) value, by(periodo idN)
rename value EML`s'
rename idN código_industria

save "${rutabox}\Empleo CES\CESemployment_`s'.dta", replace
}





* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
* * * * * * * * * * * M E R G I N G     J O L T S    +     C E S  * * * * * * * * * * * 
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 


*Panel*
use "${rutabox}\Datos\HILS.dta", clear
local ajuste "HIRS JOLS JORS LDLS LDRS OSLS OSRS QULS QURS TSLS TSRS HILU HIRU JOLU JORU LDLU LDRU OSLU OSRU QULU QURU TSLU TSRU"
foreach a of local ajuste {
merge 1:1 periodo código_industria using "${rutabox}\Datos/`a'.dta", nogen
}

*br JOLU HILU código_industria periodo if código_industria=="300000" | código_industria=="320000" | código_industria=="340000"
drop if código_industria=="300000"
drop if código_industria=="400000"
drop if código_industria=="510099"
drop if código_industria=="600000"
drop if código_industria=="700000"
drop if código_industria=="900000"
drop if código_industria=="923000"
drop if código_industria=="929000"

merge 1:1 periodo código_industria using "${rutabox}\Empleo CES\CESemployment_S.dta", keep(3) nogen
merge 1:1 periodo código_industria using "${rutabox}\Empleo CES\CESemployment_U.dta", keep(3) nogen

save "${rutabox}\Panel.dta", replace




* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

use  "${rutabox}\Panel.dta", clear
*tab T, g(T_)
destring código_industria, replace
qui gen idN=código_industria
qui gen T=periodo
extrdate year    year=period
extrdate quarter trim=period

qui gen Tq=yq(year, trim)
format Tq %tq

xtset idN T

foreach v of varlist HILU JOLU HILS JOLS QULU LDLU OSLU {
*replace `v'=`v'/100
qui tssmooth ma `v'M3=`v', window(2 1 0)
}

*Hirings variable: HILS HILU
global S "U" /*U UM3 S */
gen H=HIL${S}
global P=1
global L=5
global abs "i.idN i.T i.trim i.idN##i.year  i.idN##c.trend i.idN##c.trend2 i.idN##c.trend3 i.idN##c.trend4"


/*Weights*/
xtset idN T
*Hiring
bys periodo: egen THILU=total(HILU)
gen weigthH=HILU/THILU
bys idN: egen AweigthH=mean(weigthH)
bys idN: egen AweigthH_aux=mean(weigthH) if periodo<ym(2010,01)
bys idN: egen AweigthH2=max(AweigthH_aux)

*Employment
bys periodo: egen TEMLU=total(EMLU)
gen weigthE=EMLU/TEMLU
bys idN: egen AweigthE=mean(weigthE)
bys idN: egen AweigthE_aux=mean(weigthE) if periodo<ym(2010,01)
bys idN: egen AweigthE2=max(AweigthE_aux)

* * * 
xtset idN T
save  "${rutabox}\Panel2.dta", replace
* * *




