# Variable naming inventory and proposals — Rules 2611.13

**Status:** Review proposal only. **No identifier renames approved or implemented.**
**Baseline:** `main` rules source blob `dea01246fa04134e845c8e8247ee43e34d9f0818` (2611.13); criteria [RULES-NAMING-CONVENTION.md](RULES-NAMING-CONVENTION.md).

## Review method

- Enumerated `#` and `$` identifiers from **executable source only** (block comments, line comments and diagnostic strings excluded); `System#Boot` event syntax excluded.
- Reference counts below are **lexical occurrences**, including assignments and the parameter declaration in `TaShift2($WCS)`, not runtime reads/calls. A name on the same line twice counts twice.
- Locations use short Rule labels: **Boot** = System#Boot, **T1..T12** = timer=1..12, **Freq** = @Compressor_Freq, **Outlet** = @Main_Outlet_Temp, **TaShift/TaShift2** = corresponding handlers.
- Class **A** = keep, **B** = suggested rename pending individual author decision, **C** = keep with documentation. A/B/C indicates *assessment*, not an approval.
- Proposals preserve variable scope and intent. Meaning is inferred from the **current code**, not presumed from the existing spelling. Names proposed here have **not been tested in the Rules compiler**.

**Coverage:** 64 user variables: 34 globals and 30 locals. Classification: 9 A, 40 B, 15 C.

## Global variables (`#`)

| Current name | Refs | Rule(s) | Meaning / value | Class | Proposed future name | Rationale |
| --- | ---: | --- | --- | :---: | --- | --- |
| `#chEnable` | 15 | T1, T4, T8, T9 | Gefilterde CH-vraag: Evohome of GPIO33-hysterese. | **B** | `#CHEnable` | NC-01/05: schrijf CH als protocolafkorting consequent; niet gelijk aan HP ON. |
| `#chEnableChangeTime` | 6 | Boot, T1, T8 | Weekdaggebaseerd minuutgetal bij laatste interne CH-vraagwisseling. | **B** | `#CHEnableChangeWeekMin` | NC-01/06: CH-hoofdletters en tijdreferentie expliciet. |
| `#chEnableOnMin` | 5 | Boot, T4, T8 | Getekende duur van huidige CH-vraagstatus (+aan, −uit). | **B** | `#CHEnableSignedMin` | NC-01/06: huidige naam suggereert alleen AAN; duur is getekend. |
| `#chEnableTimeOff` | 6 | Boot, T8 | Weekdaggebaseerd startminuutgetal van ononderbroken ruwe OT-offperiode; −1 = geen. | **B** | `#CHEnableOffStartWeekMin` | NC-01/06: expliciet starttijdstip, geen verstreken tijd. |
| `#CompFreqTarget` | 10 | Boot, T7, TaShift2 | Berekende compressorfrequentiereferentie (Hz) voor quiet-mode en PI-stap. | **A** | `#CompFreqTarget` | NC-03/09: compacte, bruikbare technische naam. |
| `#CompRunMin` | 11 | Boot, T2, Freq, TaShift, T4, T7, TaShift2 | Getekende compressorstatusduur in minuten (+draait, −staat stil). | **C** | `#CompRunMin` | NC-06/09: ingeburgerd; vermeld dat negatieve waarden OFF-duur betekenen. |
| `#CompRunSec` | 11 | Boot, T1, Freq, T3, TaShift, T11, TaShift2 | Opstartteller in seconden; 1999 markeert reeds lopende compressor. | **C** | `#CompRunSec` | NC-06/09: naam handhaven; teller stopt na drempel en kent sentinel. |
| `#CompState` | 15 | T1, Freq, TaShift, T4, T5, T7, T8, TaShift2 | Compressorstatus 0=uit, 1=nieuw gestart, 2=al actief bij reload. | **C** | `#CompState` | NC-08/09: goede naam; leg de enumcodes vast. |
| `#CompStateChangeTime` | 4 | T1, T2, Freq | Weekdaggebaseerd minuutgetal bij laatste compressorstatusverandering. | **B** | `#CompStateChangeWeekMin` | NC-06: eenheid en weekreferentie expliciet. |
| `#CoolingEnable` | 5 | Boot, T4, T8 | Laagdoorlaat-gefilterde OT-koelvraag. | **C** | `#CoolingEnable` | NC-09: naam is compact; documenteer verschil met ruwe OT-input. |
| `#DHWComfortDay` | 2 | Boot, T5 | Weekdag voor extra comfort-DHW-controle. | **A** | `#DHWComfortDay` | NC-03: helder en domeineigen. |
| `#DHWRun` | 14 | Boot, T1, TaShift, T4, T5, T8, T9 | DHW-toestand: −1 init, 0 idle, 1 finishing, 2 Rules-run, 3 extern gedetecteerd. | **C** | `#DHWRun` | NC-08/09: hoewel 'Run' geen boolean is, huidige naam handhaven met enum-uitleg. |
| `#DHWSterilizationDay` | 8 | Boot, T5 | Weekdag voor legionella/sterilisatie, tijdelijk +10 als gevraagd-status. | **C** | `#DHWSterilizationDay` | NC-08/09: betekenis behouden; +10-sentinel documenteren. |
| `#DHWTempP` | 3 | T1, T5 | Vorige DHW-temperatuurmeting voor snelle dalingsdetectie. | **B** | `#DHWTempPrev` | NC-02/04: cryptische P betekent previous. |
| `#Heat` | 6 | Boot, TaShift, T4, T8, T9 | 1 als actuele bedrijfsmodus 0 of 4 verwarmingslogica toestaat. | **B** | `#HeatingModeActive` | NC-02/08: is modusindicator, geen geproduceerde warmte of warmtevraag. |
| `#HPStateP` | 4 | T1, T5 | Voor DHW bewaarde WP-aan/uit-toestand. | **B** | `#HPStateSaved` | NC-04/05: P vervangen door Saved. |
| `#HPStateR` | 11 | T1, T4, T5, T8 | Door Rules gewenste WP-aan/uit-toestand. | **B** | `#HPStateReq` | NC-04/05: R vervangen door Req. |
| `#NoDefrost` | 2 | TaShift | TaShift mag door: geen defrost óf defrost met debiet 5–30 l/min. | **B** | `#DefrostGatePassed` | NC-02/08: huidige naam kan waar zijn tijdens defrost. |
| `#OMP` | 6 | Boot, T5 | Tijdens DHW bewaarde bedrijfsmodus. | **B** | `#ModeSaved` | NC-04/05: compacte, expliciete betekenis van P. |
| `#OMR` | 13 | T1, T4, T5, T8 | Door Rules gewenste bedrijfsmodus. | **B** | `#ModeReq` | NC-04/05: compacte, expliciete betekenis van R. |
| `#OutsideTemp` | 15 | T1, TaShift, T4, T5, T6, T7, T8, T10, TaShift2 | Gefilterde buitentemperatuur voor regeling. | **C** | `#OutsideTemp` | NC-09: kort en leesbaar; noteer lowpass, niet onverwerkte @Outside_Temp. |
| `#PIDintegral` | 4 | Boot, T9 | Begrensde I-bijdrage in °C van PI-regelaar. | **B** | `#PIIntegral` | NC-02/04: er is geen D-term; PI ipv PID, correcte PascalCase. |
| `#QMR` | 12 | Boot, T7 | Gevraagde quiet-mode-stand. | **B** | `#QuietModeReq` | NC-04/05: QMR vervangen door begrijpelijke naam. |
| `#RoomSetpoint` | 4 | T1, T8, T9 | OT-ruimte-insteltemperatuur, begrensd 10–22 °C. | **A** | `#RoomSetpoint` | NC-03: helder en compact. |
| `#RoomTemp` | 3 | T1, T8 | Via OT ontvangen kamertemperatuur. | **A** | `#RoomTemp` | NC-03: helder en compact. |
| `#RoomTempControl` | 8 | Boot, TaShift, T9, TaShift2 | Afgeronde totale PI-correctie in °C. | **B** | `#RoomPICorrection` | NC-02/08: duidelijker dat dit PI-uitgang is. |
| `#RoomTempDelta` | 15 | Boot, TaShift, T4, T8, T9 | Werkelijke kamertemperatuur min setpoint in °C. | **A** | `#RoomTempDelta` | NC-03: duidelijk; positieve waarde betekent warmer dan setpoint. |
| `#SHifT` | 12 | TaShift | Begrensde ±5 °C verschuiving van doeltemperatuur. | **B** | `#TargetShift` | NC-01/02: afwijkend hoofdletterpatroon en onduidelijke afkorting. |
| `#TaDelta` | 6 | TaShift, T5, T12, TaShift2 | Aanvoertemperatuur minus actuele Z1-warmtevraagtemperatuur. | **C** | `#TaDelta` | NC-04/09: Ta is ingeburgerde domeinterm; leg tekenrichting vast. |
| `#TaDeltaTimer` | 11 | Freq, T3, TaShift, T5, T12, TaShift2 | Bij overshoot getelde tijd in seconden. | **B** | `#TaDeltaSec` | NC-06: dit is een verstreken tijdsduur, geen timer-ID. |
| `#TaPIStepTime` | 16 | Boot, T1, Freq, TaShift, T5, TaShift2 | Weekdaggebaseerd minuutgetal van laatste PI-stap; −1 = handover niet actief. | **C** | `#TaPIStepTime` | NC-03/06/09: lange naam komt vaak voor; eenheid in documentatie kan voldoende zijn. |
| `#Time` | 20 | T1, T2, Freq, Outlet, T8, TaShift2 | Minuutgetal %day×1440 + %hour×60 + %minute; verschillen worden modulo 10080 bepaald. | **B** | `#WeekMin` | NC-06: maak temporele referentie expliciet; ondanks veelvuldig gebruik blijft kort. |
| `#WCS` | 5 | T1, TaShift, T8, T10 | Weersafhankelijk gecompenseerde basiswaarde (°C). | **C** | `#WCS` | NC-04/09: vertrouwde domeinafkorting; onderscheiden van lokale WCS. |
| `#Z1HRT` | 15 | TaShift, TaShift2 | Berekende, uiteindelijk aangevraagde Z1-aanvoertemperatuur. | **B** | `#Z1HeatReqTemp` | NC-02/04: HRT is cryptisch; ReqTemp specificeert de grootheid. |

## Local variables (`$`)

| Current name | Refs | Rule(s) | Meaning / value | Class | Proposed future name | Rationale |
| --- | ---: | --- | --- | :---: | --- | --- |
| `$chEnableCondition` | 3 | T4 | Voorwaarde: aanhoudende CH-vraag en langdurig compressor-off buiten nacht. | **B** | `$CHRestartAllowed` | NC-01/02/08: geen willekeurige conditie, specifieke herstartmogelijkheid. |
| `$chEnableElapsed` | 3 | T8 | Ongetekende duur sinds laatste CH-vraagwisseling. | **B** | `$CHEnableElapsedMin` | NC-01/06: CH en duur-eenheid consequent. |
| `$chEnableOffElapsed` | 2 | T8 | Duur ononderbroken ruwe OT-vraag=0 vóór filtering. | **B** | `$CHEnableOffElapsedMin` | NC-01/06: betekenis en minuten expliciet. |
| `$CompElapsed` | 3 | T2 | Ongetekende duur sinds compressorstatuswisseling. | **B** | `$CompElapsedMin` | NC-06: minuten expliciet. |
| `$CoolForce` | 3 | T4 | Optionele −2 °C-correctie op gekoelde aanvoervraag. | **B** | `$CoolOffset` | NC-02: Force suggereert aan/uit of override, maar is temperatuur-offset. |
| `$CoolingControl` | 3 | T4 | Na grenzen berekende koelvraagtemperatuur (°C). | **B** | `$CoolReqTemp` | NC-02/08: temperatuurverzoek, geen regelaarstatus. |
| `$CoolingEnable` | 3 | T4 | Afgeronde, minimaal op nul begrensde lokale koelvraag. | **C** | `$CoolingEnable` | NC-07/09: kort in timer 4; documenteer onderscheid met globale filtertoestand. |
| `$CoolReqTempMin` | 3 | T4 | Ondergrens voor koelvraag (0 of begrensde outletwaarde). | **B** | `$CoolTempFloor` | NC-02: de waarde wordt als minimum in max() toegepast. |
| `$DHW10Condition` | 2 | T5 | DHW-temperatuur bereikt diepe onderschrijdingsdrempel. | **B** | `$DHWDeepLow` | NC-02/03: 10 is relatieve drempelverschuiving, niet tijd of uur. |
| `$DHW9hCondition` | 2 | T5 | DHW-te-koud of >5 °C temperatuurdaling; na 09:00 toegepast. | **B** | `$DHWLowOrDrop` | NC-02: conditie bevat zelf geen uurcontrole; huidige naam misleidt. |
| `$DHWTime` | 4 | T5 | Geplande DHW-triggeruur (0, 8 of 13). | **B** | `$DHWStartHour` | NC-06: uur als eenheid en gepland startsignaal expliciet. |
| `$DHWTimeCondition` | 2 | T5 | Temperatuur-/weekdagvoorwaarde voor geplande DHW-run. | **B** | `$DHWScheduleEligible` | NC-02/08: bevat geen actuele uurmatch; eligibility beter. |
| `$Ilimit` | 3 | T9 | Absolute grens voor integrale bijdrage in °C. | **B** | `$ILimit` | NC-01: hoofdlettergebruik I + Limit consistent. |
| `$Ki` | 2 | T9 | Integrale PI-versterking per 5-minutenstap. | **A** | `$Ki` | NC-01 uitzondering voor conventioneel regeltechnisch symbool. |
| `$Kp` | 2 | T9 | Proportionele PI-versterking. | **A** | `$Kp` | NC-01 uitzondering voor conventioneel regeltechnisch symbool. |
| `$MaxPumpDuty` | 15 | T6 | Te versturen maximale pompduty-instelling. | **A** | `$MaxPumpDuty` | NC-03/09: kort, helder binnen timer 6. |
| `$MaxPumpFlow` | 2 | T6 | Berekend doeldebiet voor pompduty-berekening. | **B** | `$PumpFlowTarget` | NC-02: doeldebiet, niet absoluut maximaal meetbaar debiet. |
| `$OverNight` | 4 | T4 | Boolean: tijdvenster 23:00–02:59. | **B** | `$NightWindow` | NC-01/02: consistente samenstelling en specifiek venster. |
| `$PIcandidate` | 3 | T9 | Kandidaat PI-uitgang voor anti-windup. | **B** | `$PICandidate` | NC-01: PascalCase bij PI-term. |
| `$PIintegralNext` | 3 | T9 | Volgende begrensde I-bijdrage, nog niet geaccepteerd. | **B** | `$PIIntegralNext` | NC-01: PascalCase bij PI-term. |
| `$PIlimit` | 5 | T9 | Absolute maximale totale PI-correctie. | **B** | `$PILimit` | NC-01: PascalCase bij PI-term. |
| `$PIoutput` | 2 | T9 | Gecalculeerde totale PI-correctie vóór begrenzing. | **B** | `$PIOutput` | NC-01: PascalCase bij PI-term. |
| `$PIp` | 3 | T9 | Proportionele P-bijdrage in °C. | **B** | `$PTerm` | NC-01/02: herkenbare naam voor P-term, geen verwarring met gehele PI. |
| `$QMDHW` | 3 | T7 | Tijdens DHW mogelijke −1 stap aan quiet-mode-commando. | **B** | `$DHWQuietOffset` | NC-02/04: benoem corrigerende offset. |
| `$RoomError` | 5 | T9 | Setpoint minus kamertemperatuur: positieve warmtevraagfout. | **A** | `$RoomError` | NC-03: helder en compact. |
| `$Ta1` | 4 | T10 | Aanvoerstooklijnwaarde bij Tb1. | **C** | `$Ta1` | NC-01/09: algebraïsche coördinaten zijn ingeburgerd; toelichten in header. |
| `$Ta2` | 3 | T10 | Aanvoerstooklijnwaarde bij Tb2 (36 °C in Direct mode). | **C** | `$Ta2` | NC-01/09: gekoppeld aan Ta1, geen stilistische bulkrename. |
| `$Tb1` | 3 | T10 | Hogere buitentemperatuur op stooklijn. | **C** | `$Tb1` | NC-01/09: algebraïsche referentie. |
| `$Tb2` | 2 | T10 | Lagere buitentemperatuur op stooklijn. | **C** | `$Tb2` | NC-01/09: algebraïsche referentie. |
| `$WCS` | 14 | TaShift, TaShift2 | Voor Z2 gecorrigeerde WCS (alleen bij draaiende compressor). | **B** | `$AdjustedWCS` | NC-02/05: onderscheid basis-#WCS van lokaal aangepast doel; mogelijk leesbaarheidsnadeel in dichte expressies. |

## Review topics before choosing replacements

1. **CH terminology.** The `#chEnable*` family is based on the OT `?chEnable` signal but has extra GPIO33 filtering. The recommendation uses `CHEnable` for the family; alternatively the author may prefer `CHDemand`. Decide the **entire family** consistently without renaming the OT interface symbol.
2. **Time references.** `#Time`, compressor-change and CH-change timestamps use a week-day-based minute count (`%day * 1440 + %hour * 60 + %minute`), with **elapsed differences** normalized modulo 10080; the stored raw `#Time` is not itself modulo 10080. The `WeekMin` suffix clarifies this. In contrast, signed `#CompRunMin` and `#chEnableOnMin` durations indicate **positive ON / negative OFF**, and `#TaPIStepTime = -1` signifies inactive. Long names in dense PI expressions may remain unchanged by author decision.
3. **Short historical names.** `#OMR`, `#OMP`, `#QMR`, `#HPStateP/R` are compact but opaque. The proposed `Req`/`Saved` replacements distinguish requested and saved values without fully spelling out the product names.
4. **PI terms.** Prefer `PI` for a controller without a derivative term, preserve the conventional `Kp`/`Ki` symbols, and use consistent capitalization for other `PI*` locals.
5. **WCS.** `#WCS` is the weather-compensated base; `$WCS` is the locally adjusted reference passed to `TaShift2`. The proposed longer `$AdjustedWCS` is a **trade-off**, because the local occurs frequently in mathematical expressions.
6. **Status enums and sentinels.** Keep and document the special values of `#DHWRun`, `#CompState`, `#CompRunSec`, and `#DHWSterilizationDay`. Any future *logic* simplification is out of scope.
7. **Scope and name collision.** Retain the `#`/`$` roles. Before any approved refactor, validate every new identifier against all current names, Rule handlers, parser keywords and firmware limits.

## Author's decision register — deliberately not decided here

Every **B** entry requires a separate **Rename / Keep / Defer** decision with its final name and reason. **A** and **C** may also be challenged; this table is not an instruction to rename all B entries.

| Proposed rename | Decision | Final approved name | Notes |
| --- | --- | --- | --- |
| `#chEnable` → `#CHEnable` | Pending | — | — |
| `#chEnableChangeTime` → `#CHEnableChangeWeekMin` | Pending | — | — |
| `#chEnableOnMin` → `#CHEnableSignedMin` | Pending | — | — |
| `#chEnableTimeOff` → `#CHEnableOffStartWeekMin` | Pending | — | — |
| `#CompStateChangeTime` → `#CompStateChangeWeekMin` | Pending | — | — |
| `#DHWTempP` → `#DHWTempPrev` | Pending | — | — |
| `#Heat` → `#HeatingModeActive` | Pending | — | — |
| `#HPStateP` → `#HPStateSaved` | Pending | — | — |
| `#HPStateR` → `#HPStateReq` | Pending | — | — |
| `#NoDefrost` → `#DefrostGatePassed` | Pending | — | — |
| `#OMP` → `#ModeSaved` | Pending | — | — |
| `#OMR` → `#ModeReq` | Pending | — | — |
| `#PIDintegral` → `#PIIntegral` | Pending | — | — |
| `#QMR` → `#QuietModeReq` | Pending | — | — |
| `#RoomTempControl` → `#RoomPICorrection` | Pending | — | — |
| `#SHifT` → `#TargetShift` | Pending | — | — |
| `#TaDeltaTimer` → `#TaDeltaSec` | Pending | — | — |
| `#Time` → `#WeekMin` | Pending | — | — |
| `#Z1HRT` → `#Z1HeatReqTemp` | Pending | — | — |
| `$chEnableCondition` → `$CHRestartAllowed` | Pending | — | — |
| `$chEnableElapsed` → `$CHEnableElapsedMin` | Pending | — | — |
| `$chEnableOffElapsed` → `$CHEnableOffElapsedMin` | Pending | — | — |
| `$CompElapsed` → `$CompElapsedMin` | Pending | — | — |
| `$CoolForce` → `$CoolOffset` | Pending | — | — |
| `$CoolingControl` → `$CoolReqTemp` | Pending | — | — |
| `$CoolReqTempMin` → `$CoolTempFloor` | Pending | — | — |
| `$DHW10Condition` → `$DHWDeepLow` | Pending | — | — |
| `$DHW9hCondition` → `$DHWLowOrDrop` | Pending | — | — |
| `$DHWTime` → `$DHWStartHour` | Pending | — | — |
| `$DHWTimeCondition` → `$DHWScheduleEligible` | Pending | — | — |
| `$Ilimit` → `$ILimit` | Pending | — | — |
| `$MaxPumpFlow` → `$PumpFlowTarget` | Pending | — | — |
| `$OverNight` → `$NightWindow` | Pending | — | — |
| `$PIcandidate` → `$PICandidate` | Pending | — | — |
| `$PIintegralNext` → `$PIIntegralNext` | Pending | — | — |
| `$PIlimit` → `$PILimit` | Pending | — | — |
| `$PIoutput` → `$PIOutput` | Pending | — | — |
| `$PIp` → `$PTerm` | Pending | — | — |
| `$QMDHW` → `$DHWQuietOffset` | Pending | — | — |
| `$WCS` → `$AdjustedWCS` | Pending | — | — |

## Safety gate for a later, separately approved implementation

- Preserve exact working 2611.13 and compiler/firmware configuration as rollback.
- Apply only approved one-to-one identifier renames in the canonical commented Rules source and its comments, respecting all references and parameter passing.
- Reject missing identifiers, unintended duplicate names, collisions and any changes in executable token sequences after renaming is reversed in a comparison.
- Generate the loadable Rules from the canonical source. Accommodate the known minifier `/` spacing behavior in diagnostic strings without altering semantics.
- Validate variable slots, each conditional jump offset, parser/compiler acceptance, initial load and operational behavior; successful token comparison does not replace on-device validation.

**No Rule logic, timers, heat-pump safeguards, or firmware are changed by this inventory.**
