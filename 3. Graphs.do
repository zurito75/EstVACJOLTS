/*
Graphs.

This dofile compares the market thightness and the job finding rate
using data from JOLTS and the and estimated vacancies from agregated Hires
Leonardo+Raquel

*/

global rutabox "C:\Users\zurit\Dropbox\JOLTS\OpenCode" /*Here the path where you placed the folder "OpenCode"*/
global S "U" /*U UM3 S */


* * * * * * * * * *
** Unemployment **
/*Data from: https://data.bls.gov/pdq/SurveyOutputServlet
Labor Force Statistics including the National Unemployment Rate
(Current Population Survey - CPS)
Number in thousands
*/
import excel "${rutabox}\Datos\UnemploymentUSA.xlsx", sheet("BLS Data Series") cellrange(A12:M30) firstrow clear
rename (Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec) (u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12)
reshape long u, i(Year) j(mes)
gen T=ym(Year, mes)
format T %tm
extrdate q quarter = T
keep T u

save "${rutabox}\Datos\UnemploymentUSA.dta", replace
* * * * * * * * * *


** Methodology **
use "${rutabox}\Resultados\AICSeriesResults.dta", clear
merge 1:1 T  using "${rutabox}\Datos\UnemploymentUSA.dta", keep(3) nogen


***Seasonal Adjustment***
capture drop _SA*
keep if T<ym(2019,6)


foreach x of varlist HILU JOLU ef u {
	            tsset T, monthly
	            tssmooth ma `x'_ma=`x', window(1 1 1)
	            replace `x' = `x'_ma
                tsset T, monthly
}

cd "C:\ado\plus\s"
adopath + "C:\ado\plus\s"
foreach x of varlist HILU JOLU ef u {
                tsset T, monthly
                sax12  `x', satype(dta)  comptype(mult) transfunc(auto) outauto(all) outlsrun(3) ammaxlag(3 1) ammaxdiff(2 1) ammaxlead(3) ammaxback(3) priormode(diff) ///
                               x11seas(x11default) sliding history noview
  
  
                sax12im "`x'.out", ext(d10 d11 d12 d13)
                sax12im "`x'.out", ext(sp2) noftvar

                gen        `x'_SA=`x'_d11 
                drop `x'_d10 `x'_d11 `x'_d12 `x'_d13
                sax12del `x' 
}      

tsline  JOLU_SA ef_SA       
save "${rutabox}\Resultados\MTandJFR.dta", replace


use "${rutabox}\Resultados\MTandJFR.dta", clear

*Market tightness
gen mt_JOLTS = JOL${S}_SA/u_SA
gen mt_ef    = ef_SA/u_SA

*Market tightness proxy Job finding rate  (hires_t/unemployed_t-1 = vacancies_t/unemployed_t-1 )
gen mt2_JOLTS = JOL${S}_SA/l1.u_SA
gen mt2_ef    = ef_SA     /l1.u_SA

*Job filling rate
*gen jfr_JOLTS = HIL${S}_SA/(l1.JOL${S}_SA)
*gen jfr_ef    = HIL${S}_SA/(l1.ef_SA   )     
gen jfr_JOLTS = HIL${S}_SA/((l1.JOL${S}_SA+l2.JOL${S}_SA+l3.JOL${S}_SA)/3)
gen jfr_ef    = HIL${S}_SA/((l1.ef_SA   +l2.ef_SA   +l3.ef_SA)/3)     


label var ef         "Estimated vacancies"
label var JOL${S}    "Job Openings (JOLTS)"
label var HIL${S}    "Hirings (JOLTS)"
label var jfr_JOLTS  "Job Filling Rate (JOLTS)"
label var jfr_ef     "Job Filling Rate (estimated)"
label var mt_JOLTS   "Market Tightness (JOLTS)"
label var mt_ef      "Market Tightness (estimated)"
label var mt2_JOLTS  "Market Tightness (JOLTS)"
label var mt2_ef     "Market Tightness (estimated)"


***Graphs***
*Market tightness
tw  (line mt_JOLTS T if T<ym(2019,6), lc(black) lw(medthick)) ///
    (line mt_ef    T if T<ym(2019,6), lc(gray)   ),    ///
	xtitle("") xlabel(504(24)696, labsize(small) angle(h)) ylabel(, labsize(small) angle(h)) ///
	title("Market Tightness") graphregion(fcolor(white)) legend(r(2) size(small)) /*name(MarketTightness, replace)*/
graph export "${rutabox}\Resultados\MarketTightness.png", replace

*Market tightness
tw  (line mt2_JOLTS T if T<ym(2019,6), lc(black) lw(medthick)) ///
    (line mt2_ef    T if T<ym(2019,6), lc(gray)   ),    ///
	xtitle("") xlabel(504(24)696, labsize(small) angle(h)) ylabel(, labsize(small) angle(h)) ///
	title("Market Tightness") graphregion(fcolor(white)) legend(r(2) size(small)) /*name(MarketTightness2, replace)*/
graph export "${rutabox}\Resultados\MarketTightness2.png", replace

*Job filling rate
tw  (line jfr_JOLTS T if T<ym(2019,6), lc(black) lw(medthick)) ///
    (line jfr_ef    T if T<ym(2019,6), lc(gray)   ),    ///
	xtitle("") xlabel(504(24)696, labsize(small) angle(h)) ylabel(0.0(0.5)1.5, labsize(small) angle(h)) ///
	title("Job Filling Rate") graphregion(fcolor(white)) legend(r(2) size(small)) /*name(JobFindingRate, replace)*/
corr(jfr_JOLTS jfr_ef)
graph export "${rutabox}\Resultados\JobFillingRate.png", replace




