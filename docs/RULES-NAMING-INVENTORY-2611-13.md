# Variable naming inventory and grouped review — Rules 2611.13

**Status:** Fully reassessed naming **proposals**, awaiting per-name decisions; no variable rename has been approved or implemented.
**Baseline:** canonical commented Rules 2611.13, GitHub blob `dea01246fa04134e845c8e8247ee43e34d9f0818`.
**Design criteria:** [RULES-NAMING-CONVENTION.md](RULES-NAMING-CONVENTION.md), NC-01–NC-11.

## Method and interpretation

- The **64 user-defined variables** are grouped into nine functional families, one primary review group per symbol. Grouping does not imply changes to Rules or variable scope.
- Every candidate below has been re-evaluated after the agreements to **retain `#Time`**, use **`Last`** for an earlier comparable sample and **`Prev`** for an earlier state retained for restoration, and treat **`Time`** as potentially a time reference, timestamp *or* duration without requiring `Duration`.
- A and C candidates deliberately retain the original spelling. A = clear enough to keep; C = retain and document the non-obvious meaning. B = proposed rename, **not yet approved**.
- Counts are lexical references in executable source (including assignments and function parameter declarations), not runtime activity. Diagnostic strings and comments are excluded. `System#Boot` is a Rule event, not user variable `#Boot`.
- Rule abbreviations: Boot = System#Boot, T1–T12 = timer=1–12, Freq = @Compressor_Freq, Outlet = @Main_Outlet_Temp, TaShift/TaShift2 = the named handlers.
- Technical interface symbols (`@`, `?`, `%`) and existing 2611.13 Rules themselves are outside the refactor. Naming alone is insufficient to prove parser compatibility; that must be tested later.

**Totals:** 64 variables: 34 global (`#`) + 30 local (`$`). Recommendations: **11 A**, **38 B**, **15 C**.

## 1. Centrale tijdreferentie

De gemeenschappelijke minuutresolutie-tijdreferentie is bewust kort; eventtijdstippen en verstreken tijden worden in hun eigen functionele groep beoordeeld.

| Current name | Refs | Rules | Meaning | Class | Suggested name | Why |
| --- | ---: | --- | --- | :---: | --- | --- |
| `#Time` | 20 | T1, T2, Freq, Outlet, T8, TaShift2 | Minuutgetal %day×1440 + %hour×60 + %minute; verschillen worden modulo 10080 bepaald. | **A** | `#Time` | NC-09: bewuste centrale tijdreferentie; minuutresolutie en modulo-10080-tijdsverschillen staan in de documentatie. |

## 2. Compressorstatus, frequentie en looptijden

CompStatus en CH-status gebruiken dezelfde conventie voor getekende tijden: positief = actief, negatief = niet actief, in minuten. Een gedeelde suffix `StateMin` is een voorstel, geen verplichting. `ChangeTime` betekent een tijdstip; `ElapsedMin` een duur.

| Current name | Refs | Rules | Meaning | Class | Suggested name | Why |
| --- | ---: | --- | --- | :---: | --- | --- |
| `#CompFreqTarget` | 10 | Boot, T7, TaShift2 | Berekende compressorfrequentiereferentie (Hz) voor quiet-mode en PI-stap. | **A** | `#CompFreqTarget` | NC-03/09: compacte, bruikbare technische naam. |
| `#CompRunMin` | 11 | Boot, T2, Freq, TaShift, T4, T7, TaShift2 | Getekende compressorstatusduur in minuten (+draait, −staat stil). | **B** | `#CompStateMin` | NC-05/06/11: de toestandduur is positief bij draaien en negatief bij uit; parallel met `#CHStateMin`. |
| `#CompRunSec` | 11 | Boot, T1, Freq, T3, TaShift, T11, TaShift2 | Opstartteller in seconden; 1999 markeert reeds lopende compressor. | **C** | `#CompRunSec` | NC-06/09: naam handhaven; teller stopt na drempel en kent sentinel. |
| `#CompState` | 15 | T1, Freq, TaShift, T4, T5, T7, T8, TaShift2 | Compressorstatus 0=uit, 1=nieuw gestart, 2=al actief bij reload. | **C** | `#CompState` | NC-08/09: goede naam; leg de enumcodes vast. |
| `#CompStateChangeTime` | 4 | T1, T2, Freq | Weekdaggebaseerd minuutgetal bij laatste compressorstatusverandering. | **A** | `#CompStateChangeTime` | NC-06/09: `ChangeTime` beschrijft al een gebeurtenistijdstip; geen expliciete kalenderimplementatie in de naam nodig. |
| `$CompElapsed` | 3 | T2 | Ongetekende duur sinds compressorstatuswisseling. | **B** | `$CompElapsedMin` | NC-06: minuten expliciet. |

## 3. OpenTherm / CH-vraag en tijdvensters

`CH` is de domeinafkorting voor central heating; de via OT ontvangen `?chEnable` blijft ongewijzigd. De gefilterde interne vraag, ruwe UIT-wachttijd en de bijbehorende getekende statusduur worden als één samenhangende familie beoordeeld.

| Current name | Refs | Rules | Meaning | Class | Suggested name | Why |
| --- | ---: | --- | --- | :---: | --- | --- |
| `#chEnable` | 15 | T1, T4, T8, T9 | Gefilterde CH-vraag: Evohome of GPIO33-hysterese. | **B** | `#CHEnable` | NC-01/04: PascalCase met gebruikelijke CH-afkorting, onderscheid met externe `?chEnable` blijft intact. |
| `#chEnableChangeTime` | 6 | Boot, T1, T8 | Weekdaggebaseerd minuutgetal bij laatste interne CH-vraagwisseling. | **B** | `#CHEnableChangeTime` | NC-01/06: vaste CH-hoofdletters; `ChangeTime` is een gebeurtenistijdstip, niet een tijdsduur. |
| `#chEnableOnMin` | 5 | Boot, T4, T8 | Getekende duur van huidige CH-vraagstatus (+aan, −uit). | **B** | `#CHStateMin` | NC-05/06/11: zelfde getekende toestandsduurstructuur als compressor (`StateMin`); positief AAN, negatief UIT. |
| `#chEnableTimeOff` | 6 | Boot, T8 | Weekdaggebaseerd startminuutgetal van ononderbroken ruwe OT-offperiode; −1 = geen. | **B** | `#CHOffStartTime` | NC-03/06: beginmoment van aaneengesloten ruwe CH-uitperiode; compacte `StartTime`, geen eenheidssuffix nodig. |
| `$chEnableCondition` | 3 | T4 | Voorwaarde: aanhoudende CH-vraag en langdurig compressor-off buiten nacht. | **B** | `$CHRestartAllowed` | NC-02/08: conditie bepaalt toegestane CH-gedreven herstart; preciezer dan generiek `Condition`. |
| `$chEnableElapsed` | 3 | T8 | Ongetekende duur sinds laatste CH-vraagwisseling. | **B** | `$CHElapsedMin` | NC-01/06/11: korte lokale verstreken tijd sinds gefilterde CH-statuswisseling, in minuten. |
| `$chEnableOffElapsed` | 2 | T8 | Duur ononderbroken ruwe OT-vraag=0 vóór filtering. | **B** | `$CHOffElapsedMin` | NC-01/06/11: verstreken ononderbroken ruwe CH-uitduur in minuten, als tegenhanger van `#CHOffStartTime`. |
| `$OverNight` | 4 | T4 | Boolean: tijdvenster 23:00–02:59. | **B** | `$NightWindow` | NC-01/02: consistente samenstelling en specifiek venster. |

## 4. Kamertemperatuur en PI-regeling

De hele PI-keten is gezamenlijk beoordeeld: meetwaarde, setpoint, fout, P-term, I-term, anti-windup, correctie en PI-staptijd. `Kp` en `Ki` zijn bekende regeltechnische symbolen; `PI` is juist omdat geen afgeleide D-term wordt gebruikt.

| Current name | Refs | Rules | Meaning | Class | Suggested name | Why |
| --- | ---: | --- | --- | :---: | --- | --- |
| `#RoomSetpoint` | 4 | T1, T8, T9 | OT-ruimte-insteltemperatuur, begrensd 10–22 °C. | **A** | `#RoomSetpoint` | NC-03: helder en compact. |
| `#RoomTemp` | 3 | T1, T8 | Via OT ontvangen kamertemperatuur. | **A** | `#RoomTemp` | NC-03: helder en compact. |
| `#RoomTempDelta` | 15 | Boot, TaShift, T4, T8, T9 | Werkelijke kamertemperatuur min setpoint in °C. | **A** | `#RoomTempDelta` | NC-03: duidelijk; positieve waarde betekent warmer dan setpoint. |
| `$RoomError` | 5 | T9 | Setpoint minus kamertemperatuur: positieve warmtevraagfout. | **A** | `$RoomError` | NC-03: helder en compact. |
| `$Kp` | 2 | T9 | Proportionele PI-versterking. | **A** | `$Kp` | NC-01 uitzondering voor conventioneel regeltechnisch symbool. |
| `$Ki` | 2 | T9 | Integrale PI-versterking per 5-minutenstap. | **A** | `$Ki` | NC-01 uitzondering voor conventioneel regeltechnisch symbool. |
| `$PIp` | 3 | T9 | Proportionele P-bijdrage in °C. | **B** | `$PTerm` | NC-02/11: alleen proportionele term, zodat `PI` voor de totale regeluitgang gereserveerd blijft. |
| `#PIDintegral` | 4 | Boot, T9 | Begrensde I-bijdrage in °C van PI-regelaar. | **B** | `#PIIntegral` | NC-01/02/11: I-toestand van PI-regeling (er is geen D-term). |
| `$PIintegralNext` | 3 | T9 | Volgende begrensde I-bijdrage, nog niet geaccepteerd. | **B** | `$PIIntegralNext` | NC-01/11: consistente PI-hoofdletters; kandidaat I-term voor anti-windup. |
| `$PIcandidate` | 3 | T9 | Kandidaat PI-uitgang voor anti-windup. | **B** | `$PICandidate` | NC-01/11: consistente PI-hoofdletters. |
| `$Ilimit` | 3 | T9 | Absolute grens voor integrale bijdrage in °C. | **B** | `$ILimit` | NC-01/11: standaard PascalCase voor de I-begrenzing in de PI-familie. |
| `$PIlimit` | 5 | T9 | Absolute maximale totale PI-correctie. | **B** | `$PILimit` | NC-01/11: consistente PI-hoofdletters voor totale PI-limiet. |
| `$PIoutput` | 2 | T9 | Gecalculeerde totale PI-correctie vóór begrenzing. | **B** | `$PIOutput` | NC-01/11: consistente PI-hoofdletters. |
| `#RoomTempControl` | 8 | Boot, TaShift, T9, TaShift2 | Afgeronde totale PI-correctie in °C. | **B** | `#RoomPICorrection` | NC-02/08/11: afgeronde PI-correctie aan de doeltemperatuur; consistent met de gehele PI-familie. |
| `#TaPIStepTime` | 16 | Boot, T1, Freq, TaShift, T5, TaShift2 | Weekdaggebaseerd minuutgetal van laatste PI-stap; −1 = handover niet actief. | **C** | `#TaPIStepTime` | NC-06/09: eventtijdstip van laatste PI-stap; `Time` is voldoende, wekelijkse minutenrekening staat in de commentaren. |

## 5. Weersafhankelijk regelen, TaShift en aanvoertemperatuur

`WCS` is de weersafhankelijke basiswaarde. De lokale `$WCS` is een aangepaste werkwaarde die aan TaShift2 wordt doorgegeven. De extra lengte van een expliciete `Adjusted...`-naam is hier afgewogen tegen het frequente gebruik in vergelijkingen. `Ta` en curvepunten zijn herkenbare vaktermen.

| Current name | Refs | Rules | Meaning | Class | Suggested name | Why |
| --- | ---: | --- | --- | :---: | --- | --- |
| `#WCS` | 5 | T1, TaShift, T8, T10 | Weersafhankelijk gecompenseerde basiswaarde (°C). | **C** | `#WCS` | NC-04/09: vertrouwde domeinafkorting; onderscheiden van lokale WCS. |
| `$WCS` | 14 | TaShift, TaShift2 | Voor Z2 gecorrigeerde WCS (alleen bij draaiende compressor). | **C** | `$WCS` | NC-03/07/09/11: lokale, voor Z2 aangepaste WCS blijft compact in veelgebruikte TaShift-expressies; betekenis documenteren en apart beoordelen. |
| `#OutsideTemp` | 15 | T1, TaShift, T4, T5, T6, T7, T8, T10, TaShift2 | Gefilterde buitentemperatuur voor regeling. | **C** | `#OutsideTemp` | NC-09: kort en leesbaar; noteer lowpass, niet onverwerkte @Outside_Temp. |
| `$Ta1` | 4 | T10 | Aanvoerstooklijnwaarde bij Tb1. | **C** | `$Ta1` | NC-01/09: algebraïsche coördinaten zijn ingeburgerd; toelichten in header. |
| `$Ta2` | 3 | T10 | Aanvoerstooklijnwaarde bij Tb2 (36 °C in Direct mode). | **C** | `$Ta2` | NC-01/09: gekoppeld aan Ta1, geen stilistische bulkrename. |
| `$Tb1` | 3 | T10 | Hogere buitentemperatuur op stooklijn. | **C** | `$Tb1` | NC-01/09: algebraïsche referentie. |
| `$Tb2` | 2 | T10 | Lagere buitentemperatuur op stooklijn. | **C** | `$Tb2` | NC-01/09: algebraïsche referentie. |
| `#SHifT` | 12 | TaShift | Begrensde ±5 °C verschuiving van doeltemperatuur. | **B** | `#TargetShift` | NC-01/02: afwijkend hoofdletterpatroon en onduidelijke afkorting. |
| `#TaDelta` | 6 | TaShift, T5, T12, TaShift2 | Aanvoertemperatuur minus actuele Z1-warmtevraagtemperatuur. | **C** | `#TaDelta` | NC-04/09: Ta is ingeburgerde domeinterm; leg tekenrichting vast. |
| `#TaDeltaTimer` | 11 | Freq, T3, TaShift, T5, T12, TaShift2 | Bij overshoot getelde tijd in seconden. | **B** | `#TaDeltaSec` | NC-02/06: teller is een opgebouwde duur in seconden (stappen van tien), geen HeishaMon timer-ID. |
| `#NoDefrost` | 2 | TaShift | TaShift mag door: geen defrost óf defrost met debiet 5–30 l/min. | **B** | `#DefrostGatePassed` | NC-02/08: huidige naam kan waar zijn tijdens defrost. |
| `#Z1HRT` | 15 | TaShift, TaShift2 | Berekende, uiteindelijk aangevraagde Z1-aanvoertemperatuur. | **B** | `#Z1HeatReqTemp` | NC-02/04: HRT is cryptisch; ReqTemp specificeert de grootheid. |

## 6. Warmtepompstatus en bedrijfsmodus

Binnen deze familie staat `Req` voor de gewenste stand en `Prev` voor de stand van vóór DHW die later kan worden teruggezet. Het woord `Prev` is dus bewust anders dan `Last` bij een historische temperatuurmeting.

| Current name | Refs | Rules | Meaning | Class | Suggested name | Why |
| --- | ---: | --- | --- | :---: | --- | --- |
| `#Heat` | 6 | Boot, TaShift, T4, T8, T9 | 1 als actuele bedrijfsmodus 0 of 4 verwarmingslogica toestaat. | **B** | `#HeatingModeActive` | NC-02/08: is modusindicator, geen geproduceerde warmte of warmtevraag. |
| `#HPStateR` | 11 | T1, T4, T5, T8 | Door Rules gewenste WP-aan/uit-toestand. | **B** | `#HPStateReq` | NC-04/05: R vervangen door Req. |
| `#HPStateP` | 4 | T1, T5 | Voor DHW bewaarde WP-aan/uit-toestand. | **B** | `#HPStatePrev` | NC-05/08: `Prev` = eerdere WP-toestand die na DHW kan worden hersteld. |
| `#OMR` | 13 | T1, T4, T5, T8 | Door Rules gewenste bedrijfsmodus. | **B** | `#ModeReq` | NC-04/05: compacte, expliciete betekenis van R. |
| `#OMP` | 6 | Boot, T5 | Tijdens DHW bewaarde bedrijfsmodus. | **B** | `#ModePrev` | NC-05/08: `Prev` = bedrijfsmodus van vóór DHW die later kan worden hersteld. |

## 7. Tapwater (DHW) en sterilisatie

Hier wordt `Last` voorgesteld voor de laatste eerder opgeslagen DHW-temperatuur die met de actuele waarde wordt vergeleken. Enums en tijdelijke sentinels worden expliciet toegelicht, maar hoeven niet uitsluitend om die reden een andere variabelenaam te krijgen.

| Current name | Refs | Rules | Meaning | Class | Suggested name | Why |
| --- | ---: | --- | --- | :---: | --- | --- |
| `#DHWRun` | 14 | Boot, T1, TaShift, T4, T5, T8, T9 | DHW-toestand: −1 init, 0 idle, 1 finishing, 2 Rules-run, 3 extern gedetecteerd. | **C** | `#DHWRun` | NC-08/09: hoewel 'Run' geen boolean is, huidige naam handhaven met enum-uitleg. |
| `#DHWTempP` | 3 | T1, T5 | Vorige DHW-temperatuurmeting voor snelle dalingsdetectie. | **B** | `#DHWTempLast` | NC-05/08: `Last` = laatst opgeslagen eerdere meetwaarde voor vergelijking, niet een terug te zetten toestand. |
| `#DHWComfortDay` | 2 | Boot, T5 | Weekdag voor extra comfort-DHW-controle. | **A** | `#DHWComfortDay` | NC-03: helder en domeineigen. |
| `#DHWSterilizationDay` | 8 | Boot, T5 | Weekdag voor legionella/sterilisatie, tijdelijk +10 als gevraagd-status. | **C** | `#DHWSterilizationDay` | NC-08/09: betekenis behouden; +10-sentinel documenteren. |
| `$DHW10Condition` | 2 | T5 | DHW-temperatuur bereikt diepe onderschrijdingsdrempel. | **B** | `$DHWDeepLow` | NC-02/03: 10 is relatieve drempelverschuiving, niet tijd of uur. |
| `$DHW9hCondition` | 2 | T5 | DHW-te-koud of >5 °C temperatuurdaling; na 09:00 toegepast. | **B** | `$DHWLowOrDrop` | NC-02: conditie bevat zelf geen uurcontrole; huidige naam misleidt. |
| `$DHWTime` | 4 | T5 | Geplande DHW-triggeruur (0, 8 of 13). | **B** | `$DHWStartHour` | NC-06: geplande startuurwaarde, met eenheid; geen duur. |
| `$DHWTimeCondition` | 2 | T5 | Temperatuur-/weekdagvoorwaarde voor geplande DHW-run. | **B** | `$DHWScheduleEligible` | NC-02/08: bevat geen actuele uurmatch; eligibility beter. |

## 8. Koelregeling

De naamgeving onderscheidt een gefilterde enable-vraag van een lokale afgeronde enable-vraag, een temperatuurcorrectie (`Offset`), een gevraagde temperatuur en een ondergrens.

| Current name | Refs | Rules | Meaning | Class | Suggested name | Why |
| --- | ---: | --- | --- | :---: | --- | --- |
| `#CoolingEnable` | 5 | Boot, T4, T8 | Laagdoorlaat-gefilterde OT-koelvraag. | **C** | `#CoolingEnable` | NC-09: naam is compact; documenteer verschil met ruwe OT-input. |
| `$CoolingEnable` | 3 | T4 | Afgeronde, minimaal op nul begrensde lokale koelvraag. | **C** | `$CoolingEnable` | NC-07/09: kort in timer 4; documenteer onderscheid met globale filtertoestand. |
| `$CoolForce` | 3 | T4 | Optionele −2 °C-correctie op gekoelde aanvoervraag. | **B** | `$CoolOffset` | NC-02: Force suggereert aan/uit of override, maar is temperatuur-offset. |
| `$CoolingControl` | 3 | T4 | Na grenzen berekende koelvraagtemperatuur (°C). | **B** | `$CoolReqTemp` | NC-02/08: temperatuurverzoek, geen regelaarstatus. |
| `$CoolReqTempMin` | 3 | T4 | Ondergrens voor koelvraag (0 of begrensde outletwaarde). | **B** | `$CoolTempFloor` | NC-02: de waarde wordt als minimum in max() toegepast. |

## 9. Pomp en Quiet Mode

De variabelen beschrijven een pompdoelwaarde, pompduty en de aangevraagde quiet-mode-stand. Een tijdelijke DHW-correctie wordt als offset benoemd.

| Current name | Refs | Rules | Meaning | Class | Suggested name | Why |
| --- | ---: | --- | --- | :---: | --- | --- |
| `$MaxPumpDuty` | 15 | T6 | Te versturen maximale pompduty-instelling. | **A** | `$MaxPumpDuty` | NC-03/09: kort, helder binnen timer 6. |
| `$MaxPumpFlow` | 2 | T6 | Berekend doeldebiet voor pompduty-berekening. | **B** | `$PumpFlowTarget` | NC-02: doeldebiet, niet absoluut maximaal meetbaar debiet. |
| `#QMR` | 12 | Boot, T7 | Gevraagde quiet-mode-stand. | **B** | `#QuietModeReq` | NC-04/05: QMR vervangen door begrijpelijke naam. |
| `$QMDHW` | 3 | T7 | Tijdens DHW mogelijke −1 stap aan quiet-mode-commando. | **B** | `$DHWQuietOffset` | NC-02/04: benoem corrigerende offset. |

## Agreed cross-family conventions

**Time.** `#Time` is retained. Its value is refreshed from `%day * 1440 + %hour * 60 + %minute` at minute resolution. A *difference* between time references is normalized with `% 10080`; the `#Time` value is not itself necessarily within 0–10079. `ChangeTime` / `StartTime` represent timestamps; `ElapsedMin`, `StateMin` etc. represent durations. These names are examples of the shared convention, not an absolute syntax requirement.

**Signed state duration.** The paired proposed names `#CompStateMin` and `#CHStateMin` have exactly the same meaning for their respective signals: **positive when ON, negative when OFF**, absolute value in minutes. This pairing explicitly fixes the inconsistency in the first inventory (`Signed` appeared in only one of them). The original `#CompRunMin` and `#chEnableOnMin` stay unchanged until individual approval.

**`Last` versus `Prev`.** `#DHWTempLast` denotes a **last earlier observed value** retained for comparison with the present temperature. `#HPStatePrev` and `#ModePrev` denote **previous states held across DHW** so a prior operating state can be restored. No `Saved` suffix is proposed.

**Compact terms.** Standard domain acronyms (`CH`, `DHW`, `HP`, `PI`, `Ta`, `WCS`) are kept where they carry stable meaning. The local `$WCS` remains a documented candidate to retain despite a changed value, because its frequent use in dense TaShift expressions makes a long name less readable. A/C are also reviewable if the author prefers another name.

**Status/enums/sentinels.** `#CompState`, `#DHWRun`, `#CompRunSec` and `#DHWSterilizationDay` have values beyond simple booleans; document their exact special values. This is a documentation matter unless a separate behavioral change is approved.

## Per-name decision register — no decisions yet

The following are only the **current B recommendations** after the grouped reassessment. Each requires an explicit **Rename / Keep / Defer** choice and an accepted final name from the author. An A or C name can also be brought back for review.

| Group | Current → proposed | Decision | Accepted name | Reason / exception |
| --- | --- | --- | --- | --- |
| Compressorstatus, frequentie en looptijden | `#CompRunMin` → `#CompStateMin` | Pending | — | — |
| Compressorstatus, frequentie en looptijden | `$CompElapsed` → `$CompElapsedMin` | Pending | — | — |
| OpenTherm / CH-vraag en tijdvensters | `#chEnable` → `#CHEnable` | Pending | — | — |
| OpenTherm / CH-vraag en tijdvensters | `#chEnableChangeTime` → `#CHEnableChangeTime` | Pending | — | — |
| OpenTherm / CH-vraag en tijdvensters | `#chEnableOnMin` → `#CHStateMin` | Pending | — | — |
| OpenTherm / CH-vraag en tijdvensters | `#chEnableTimeOff` → `#CHOffStartTime` | Pending | — | — |
| OpenTherm / CH-vraag en tijdvensters | `$chEnableCondition` → `$CHRestartAllowed` | Pending | — | — |
| OpenTherm / CH-vraag en tijdvensters | `$chEnableElapsed` → `$CHElapsedMin` | Pending | — | — |
| OpenTherm / CH-vraag en tijdvensters | `$chEnableOffElapsed` → `$CHOffElapsedMin` | Pending | — | — |
| OpenTherm / CH-vraag en tijdvensters | `$OverNight` → `$NightWindow` | Pending | — | — |
| Kamertemperatuur en PI-regeling | `$PIp` → `$PTerm` | Pending | — | — |
| Kamertemperatuur en PI-regeling | `#PIDintegral` → `#PIIntegral` | Pending | — | — |
| Kamertemperatuur en PI-regeling | `$PIintegralNext` → `$PIIntegralNext` | Pending | — | — |
| Kamertemperatuur en PI-regeling | `$PIcandidate` → `$PICandidate` | Pending | — | — |
| Kamertemperatuur en PI-regeling | `$Ilimit` → `$ILimit` | Pending | — | — |
| Kamertemperatuur en PI-regeling | `$PIlimit` → `$PILimit` | Pending | — | — |
| Kamertemperatuur en PI-regeling | `$PIoutput` → `$PIOutput` | Pending | — | — |
| Kamertemperatuur en PI-regeling | `#RoomTempControl` → `#RoomPICorrection` | Pending | — | — |
| Weersafhankelijk regelen, TaShift en aanvoertemperatuur | `#SHifT` → `#TargetShift` | Pending | — | — |
| Weersafhankelijk regelen, TaShift en aanvoertemperatuur | `#TaDeltaTimer` → `#TaDeltaSec` | Pending | — | — |
| Weersafhankelijk regelen, TaShift en aanvoertemperatuur | `#NoDefrost` → `#DefrostGatePassed` | Pending | — | — |
| Weersafhankelijk regelen, TaShift en aanvoertemperatuur | `#Z1HRT` → `#Z1HeatReqTemp` | Pending | — | — |
| Warmtepompstatus en bedrijfsmodus | `#Heat` → `#HeatingModeActive` | Pending | — | — |
| Warmtepompstatus en bedrijfsmodus | `#HPStateR` → `#HPStateReq` | Pending | — | — |
| Warmtepompstatus en bedrijfsmodus | `#HPStateP` → `#HPStatePrev` | Pending | — | — |
| Warmtepompstatus en bedrijfsmodus | `#OMR` → `#ModeReq` | Pending | — | — |
| Warmtepompstatus en bedrijfsmodus | `#OMP` → `#ModePrev` | Pending | — | — |
| Tapwater (DHW) en sterilisatie | `#DHWTempP` → `#DHWTempLast` | Pending | — | — |
| Tapwater (DHW) en sterilisatie | `$DHW10Condition` → `$DHWDeepLow` | Pending | — | — |
| Tapwater (DHW) en sterilisatie | `$DHW9hCondition` → `$DHWLowOrDrop` | Pending | — | — |
| Tapwater (DHW) en sterilisatie | `$DHWTime` → `$DHWStartHour` | Pending | — | — |
| Tapwater (DHW) en sterilisatie | `$DHWTimeCondition` → `$DHWScheduleEligible` | Pending | — | — |
| Koelregeling | `$CoolForce` → `$CoolOffset` | Pending | — | — |
| Koelregeling | `$CoolingControl` → `$CoolReqTemp` | Pending | — | — |
| Koelregeling | `$CoolReqTempMin` → `$CoolTempFloor` | Pending | — | — |
| Pomp en Quiet Mode | `$MaxPumpFlow` → `$PumpFlowTarget` | Pending | — | — |
| Pomp en Quiet Mode | `#QMR` → `#QuietModeReq` | Pending | — | — |
| Pomp en Quiet Mode | `$QMDHW` → `$DHWQuietOffset` | Pending | — | — |

## Implementation gate (later PR only)

1. Agree all chosen names *individually*, then create a separate code-only refactor. Any accepted new name must be unique, parser-compatible and consistent with the entire family.
2. Edit only canonical `HeishaMon_Rules_BlB4_commented.lua`, including all uses in assignments, conditions, `TaShift2($WCS)` parameter passing, comments and any diagnostics. Regenerate the minified loadable Rules.
3. Verify the source diff after reversing the approved identifier mappings: **no expression, constant, condition, timer or command changes**. Account for the known minifier spaces-around-`/` diagnostic-string quirk.
4. Check the firmware's variable-slot and 255-instruction conditional-jump limits, compiler acceptance, load log and runtime behavior. Preserve working 2611.13 and firmware for rollback.

**No Rules changes are part of this PR.**
