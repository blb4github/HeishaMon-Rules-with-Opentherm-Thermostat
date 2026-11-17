# Variabelenoverzicht en prefixvoorstellen — Rules 2611.13

**Status:** volledige concept-inventaris; **geen naamwijziging goedgekeurd of uitgevoerd**.
**Gebaseerd op:** `HeishaMon_Rules_BlB4_commented.lua` (versie 2611.13, bron-blob `dea01246fa04134e845c8e8247ee43e34d9f0818`) en [ontwerpcriteria NC-01–NC-12](RULES-NAMING-CONVENTION.md).

## Naamvorm, begrenzing en wijzigingsindeling

De voorkeursvorm is een sigil (`#` of `$`), **twee kleine letters voor de functionele eigenaar**, en een **PascalCase-stam**, zonder underscore. De eigenaren zijn de prefixes hieronder. De gedeelde `#Time` heeft bewust **geen prefix**.

**Wijzigingsindeling is uitsluitend tekstueel:**

- **Geen wijziging:** huidige en voorgestelde naam zijn letterlijk identiek.
- **Alleen prefix:** uitsluitend de twee lowercase prefixletters zijn direct na het sigil toegevoegd; de huidige variabelenaam is daarna exact intact, bijvoorbeeld `$Kp` → `$piKp`.
- **Alleen naam:** de correcte lowercase prefix was al aanwezig, uitsluitend de naamstam verandert (`#chEnableOnMin` → `#chStateMin`).
- **Prefix + naam:** een functionele prefix is toegevoegd of gewijzigd én de stam is inhoudelijk gewijzigd of ingekort (`#RoomTemp` → `#rtTemp`).

De prefix bepaalt de **functie**, niet de sensor-/protocolherkomst. `ot` geldt hier dus alleen voor ruwe OpenTherm-signaalfiltering; `ch` voor de gefilterde warmtevraag, `rt` voor kamerwaarden, en `pi` voor de regelaar.

## Prefixgroepen

| Prefix | Functionele groep | Variabelen |
| --- | --- | ---: |
| — (uitzondering) | Algemene tijdreferentie | 1 |
| `cp` | Compressor | 6 |
| `ot` | OpenTherm-signaalverwerking | 2 |
| `ch` | Centrale verwarmingsvraag (CH) | 6 |
| `rt` | Kamertemperatuur | 3 |
| `pi` | PI-regelaar | 12 |
| `wc` | Weersafhankelijke stooklijn | 6 |
| `ta` | Aanvoertemperatuur en TaShift | 5 |
| `hp` | Warmtepompmodus en algemene sensoren | 6 |
| `hw` | Tapwater (HW/DHW) | 8 |
| `cl` | Koelregeling | 5 |
| `pu` | Pompregeling | 2 |
| `qm` | Quiet Mode | 2 |

**Totaal:** 64 variabelen, 34 globaal (`#`) en 30 lokaal (`$`).

## Alle 64 voorstellen per functionele groep

De bestaande aantallen `Refs` zijn **lexicale** vermeldingen in uitvoerbare bron, inclusief toewijzingen; geen runtime-frequentie. De `Rules`-kolom volgt de vorige broninventaris. Bij iedere variabele staan zowel de volledige nieuwe naam als de exacte wijzigingsklasse.

### Algemene tijdreferentie (zonder prefix)

Geen prefix voor de centrale referentie; `#Time` is bewust een uitzondering.

| Huidige variabele | Groep / prefix | Volledig voorgestelde naam | Wijziging | Refs | Rules | Huidige betekenis |
| --- | --- | --- | --- | ---: | --- | --- |
| `#Time` | Geen | `#Time` | **Geen wijziging** | 20 | T1, T2, Freq, Outlet, T8, TaShift2 | Minuutgetal %day×1440 + %hour×60 + %minute; verschillen worden modulo 10080 bepaald. |

### Compressor (`cp`)

Getekende statusduur in minuten, aparte opstartteller in seconden, compressortoestand en frequentiedoel.

| Huidige variabele | Groep / prefix | Volledig voorgestelde naam | Wijziging | Refs | Rules | Huidige betekenis |
| --- | --- | --- | --- | ---: | --- | --- |
| `#CompFreqTarget` | `cp` | `#cpFreqTarget` | **Prefix + naam** | 10 | Boot, T7, TaShift2 | Berekende compressorfrequentiereferentie (Hz) voor quiet-mode en PI-stap. |
| `#CompRunMin` | `cp` | `#cpStateMin` | **Prefix + naam** | 11 | Boot, T2, Freq, TaShift, T4, T7, TaShift2 | Getekende compressorstatusduur in minuten (+draait, −staat stil). |
| `#CompRunSec` | `cp` | `#cpRunSec` | **Prefix + naam** | 11 | Boot, T1, Freq, T3, TaShift, T11, TaShift2 | Opstartteller in seconden; 1999 markeert reeds lopende compressor. |
| `#CompState` | `cp` | `#cpState` | **Prefix + naam** | 15 | T1, Freq, TaShift, T4, T5, T7, T8, TaShift2 | Compressorstatus 0=uit, 1=nieuw gestart, 2=al actief bij reload. |
| `#CompStateChangeTime` | `cp` | `#cpStateChangeTime` | **Prefix + naam** | 4 | T1, T2, Freq | Weekdaggebaseerd minuutgetal bij laatste compressorstatusverandering. |
| `$CompElapsed` | `cp` | `$cpElapsedMin` | **Prefix + naam** | 3 | T2 | Ongetekende duur sinds compressorstatuswisseling. |

### OpenTherm-signaalverwerking (`ot`)

Uitsluitend het anti-glitch-filter van de ruwe `?chEnable=0`-melding; niet de afgeleide CH-vraag.

| Huidige variabele | Groep / prefix | Volledig voorgestelde naam | Wijziging | Refs | Rules | Huidige betekenis |
| --- | --- | --- | --- | ---: | --- | --- |
| `#chEnableTimeOff` | `ot` | `#otCHOffStartTime` | **Prefix + naam** | 6 | Boot, T8 | Weekdaggebaseerd startminuutgetal van ononderbroken ruwe OT-offperiode; −1 = geen. |
| `$chEnableOffElapsed` | `ot` | `$otCHOffElapsedMin` | **Prefix + naam** | 2 | T8 | Duur ononderbroken ruwe OT-vraag=0 vóór filtering. |

### Centrale verwarmingsvraag (CH) (`ch`)

Interne gefilterde warmtevraag en bijbehorende toestand-/tijdvariabelen. De prefix `ch` bestaat al bij twee namen.

| Huidige variabele | Groep / prefix | Volledig voorgestelde naam | Wijziging | Refs | Rules | Huidige betekenis |
| --- | --- | --- | --- | ---: | --- | --- |
| `#chEnable` | `ch` | `#chEnable` | **Geen wijziging** | 15 | T1, T4, T8, T9 | Gefilterde CH-vraag: Evohome of GPIO33-hysterese. |
| `#chEnableChangeTime` | `ch` | `#chEnableChangeTime` | **Geen wijziging** | 6 | Boot, T1, T8 | Weekdaggebaseerd minuutgetal bij laatste interne CH-vraagwisseling. |
| `#chEnableOnMin` | `ch` | `#chStateMin` | **Alleen naam** | 5 | Boot, T4, T8 | Getekende duur van huidige CH-vraagstatus (+aan, −uit). |
| `$chEnableCondition` | `ch` | `$chRestartAllowed` | **Alleen naam** | 3 | T4 | Voorwaarde: aanhoudende CH-vraag en langdurig compressor-off buiten nacht. |
| `$chEnableElapsed` | `ch` | `$chElapsedMin` | **Alleen naam** | 3 | T8 | Ongetekende duur sinds laatste CH-vraagwisseling. |
| `$OverNight` | `ch` | `$chOverNight` | **Alleen prefix** | 4 | T4 | Boolean: tijdvenster 23:00–02:59. |

### Kamertemperatuur (`rt`)

Kamertemperatuur, setpoint en verschil; via OpenTherm verkregen maar functioneel RT.

| Huidige variabele | Groep / prefix | Volledig voorgestelde naam | Wijziging | Refs | Rules | Huidige betekenis |
| --- | --- | --- | --- | ---: | --- | --- |
| `#RoomSetpoint` | `rt` | `#rtSetpoint` | **Prefix + naam** | 4 | T1, T8, T9 | OT-ruimte-insteltemperatuur, begrensd 10–22 °C. |
| `#RoomTemp` | `rt` | `#rtTemp` | **Prefix + naam** | 3 | T1, T8 | Via OT ontvangen kamertemperatuur. |
| `#RoomTempDelta` | `rt` | `#rtDelta` | **Prefix + naam** | 15 | Boot, TaShift, T4, T8, T9 | Werkelijke kamertemperatuur min setpoint in °C. |

### PI-regelaar (`pi`)

Alle regelparameters, anti-windup-variabelen, correctie en tijdstip van de laatste PI-stap.

| Huidige variabele | Groep / prefix | Volledig voorgestelde naam | Wijziging | Refs | Rules | Huidige betekenis |
| --- | --- | --- | --- | ---: | --- | --- |
| `$RoomError` | `pi` | `$piError` | **Prefix + naam** | 5 | T9 | Setpoint minus kamertemperatuur: positieve warmtevraagfout. |
| `$Kp` | `pi` | `$piKp` | **Alleen prefix** | 2 | T9 | Proportionele PI-versterking. |
| `$Ki` | `pi` | `$piKi` | **Alleen prefix** | 2 | T9 | Integrale PI-versterking per 5-minutenstap. |
| `$PIp` | `pi` | `$piP` | **Prefix + naam** | 3 | T9 | Proportionele P-bijdrage in °C. |
| `#PIDintegral` | `pi` | `#piIntegral` | **Prefix + naam** | 4 | Boot, T9 | Begrensde I-bijdrage in °C van PI-regelaar. |
| `$PIintegralNext` | `pi` | `$piIntegralNext` | **Prefix + naam** | 3 | T9 | Volgende begrensde I-bijdrage, nog niet geaccepteerd. |
| `$PIcandidate` | `pi` | `$piCandidate` | **Prefix + naam** | 3 | T9 | Kandidaat PI-uitgang voor anti-windup. |
| `$Ilimit` | `pi` | `$piILimit` | **Prefix + naam** | 3 | T9 | Absolute grens voor integrale bijdrage in °C. |
| `$PIlimit` | `pi` | `$piLimit` | **Prefix + naam** | 5 | T9 | Absolute maximale totale PI-correctie. |
| `$PIoutput` | `pi` | `$piOutput` | **Prefix + naam** | 2 | T9 | Gecalculeerde totale PI-correctie vóór begrenzing. |
| `#RoomTempControl` | `pi` | `#piCorrection` | **Prefix + naam** | 8 | Boot, TaShift, T9, TaShift2 | Afgeronde totale PI-correctie in °C. |
| `#TaPIStepTime` | `pi` | `#piStepTime` | **Prefix + naam** | 16 | Boot, T1, Freq, TaShift, T5, TaShift2 | Weekdaggebaseerd minuutgetal van laatste PI-stap; −1 = handover niet actief. |

### Weersafhankelijke stooklijn (`wc`)

WCS-basistemperatuur, voor Z2 aangepaste werkwaarde en vier interpolatiepunten.

| Huidige variabele | Groep / prefix | Volledig voorgestelde naam | Wijziging | Refs | Rules | Huidige betekenis |
| --- | --- | --- | --- | ---: | --- | --- |
| `#WCS` | `wc` | `#wcBase` | **Prefix + naam** | 5 | T1, TaShift, T8, T10 | Weersafhankelijk gecompenseerde basiswaarde (°C). |
| `$WCS` | `wc` | `$wcAdjusted` | **Prefix + naam** | 14 | TaShift, TaShift2 | Voor Z2 gecorrigeerde WCS (alleen bij draaiende compressor). |
| `$Ta1` | `wc` | `$wcTa1` | **Alleen prefix** | 4 | T10 | Aanvoerstooklijnwaarde bij Tb1. |
| `$Ta2` | `wc` | `$wcTa2` | **Alleen prefix** | 3 | T10 | Aanvoerstooklijnwaarde bij Tb2 (36 °C in Direct mode). |
| `$Tb1` | `wc` | `$wcTb1` | **Alleen prefix** | 3 | T10 | Hogere buitentemperatuur op stooklijn. |
| `$Tb2` | `wc` | `$wcTb2` | **Alleen prefix** | 2 | T10 | Lagere buitentemperatuur op stooklijn. |

### Aanvoertemperatuur en TaShift (`ta`)

Aanvoerdoelverschuiving, temperatuurverschil, overshootduur, defrost-vrijgave en Z1-warmtevraag.

| Huidige variabele | Groep / prefix | Volledig voorgestelde naam | Wijziging | Refs | Rules | Huidige betekenis |
| --- | --- | --- | --- | ---: | --- | --- |
| `#SHifT` | `ta` | `#taShift` | **Prefix + naam** | 12 | TaShift | Begrensde ±5 °C verschuiving van doeltemperatuur. |
| `#TaDelta` | `ta` | `#taDelta` | **Prefix + naam** | 6 | TaShift, T5, T12, TaShift2 | Aanvoertemperatuur minus actuele Z1-warmtevraagtemperatuur. |
| `#TaDeltaTimer` | `ta` | `#taDeltaSec` | **Prefix + naam** | 11 | Freq, T3, TaShift, T5, T12, TaShift2 | Bij overshoot getelde tijd in seconden. |
| `#NoDefrost` | `ta` | `#taDefrostAllowed` | **Prefix + naam** | 2 | TaShift | TaShift mag door: geen defrost óf defrost met debiet 5–30 l/min. |
| `#Z1HRT` | `ta` | `#taZ1ReqTemp` | **Prefix + naam** | 15 | TaShift, TaShift2 | Berekende, uiteindelijk aangevraagde Z1-aanvoertemperatuur. |

### Warmtepompmodus en algemene sensoren (`hp`)

WP-status en bedrijfsmodus (`Req` en `Prev`), plus de algemeen gebruikte gefilterde buitentemperatuur.

| Huidige variabele | Groep / prefix | Volledig voorgestelde naam | Wijziging | Refs | Rules | Huidige betekenis |
| --- | --- | --- | --- | ---: | --- | --- |
| `#Heat` | `hp` | `#hpHeatingMode` | **Prefix + naam** | 6 | Boot, TaShift, T4, T8, T9 | 1 als actuele bedrijfsmodus 0 of 4 verwarmingslogica toestaat. |
| `#HPStateR` | `hp` | `#hpStateReq` | **Prefix + naam** | 11 | T1, T4, T5, T8 | Door Rules gewenste WP-aan/uit-toestand. |
| `#HPStateP` | `hp` | `#hpStatePrev` | **Prefix + naam** | 4 | T1, T5 | Voor DHW bewaarde WP-aan/uit-toestand. |
| `#OMR` | `hp` | `#hpModeReq` | **Prefix + naam** | 13 | T1, T4, T5, T8 | Door Rules gewenste bedrijfsmodus. |
| `#OMP` | `hp` | `#hpModePrev` | **Prefix + naam** | 6 | Boot, T5 | Tijdens DHW bewaarde bedrijfsmodus. |
| `#OutsideTemp` | `hp` | `#hpOutsideTemp` | **Alleen prefix** | 15 | T1, TaShift, T4, T5, T6, T7, T8, T10, TaShift2 | Gefilterde buitentemperatuur voor regeling. |

### Tapwater (HW/DHW) (`hw`)

DHW-toestand, eerdere temperatuur (`Last`), comfort-/sterilisatiedagen en startvoorwaarden.

| Huidige variabele | Groep / prefix | Volledig voorgestelde naam | Wijziging | Refs | Rules | Huidige betekenis |
| --- | --- | --- | --- | ---: | --- | --- |
| `#DHWRun` | `hw` | `#hwState` | **Prefix + naam** | 14 | Boot, T1, TaShift, T4, T5, T8, T9 | DHW-toestand: −1 init, 0 idle, 1 finishing, 2 Rules-run, 3 extern gedetecteerd. |
| `#DHWTempP` | `hw` | `#hwTempLast` | **Prefix + naam** | 3 | T1, T5 | Vorige DHW-temperatuurmeting voor snelle dalingsdetectie. |
| `#DHWComfortDay` | `hw` | `#hwComfortDay` | **Prefix + naam** | 2 | Boot, T5 | Weekdag voor extra comfort-DHW-controle. |
| `#DHWSterilizationDay` | `hw` | `#hwSterilizationDay` | **Prefix + naam** | 8 | Boot, T5 | Weekdag voor legionella/sterilisatie, tijdelijk +10 als gevraagd-status. |
| `$DHW10Condition` | `hw` | `$hwDeepLow` | **Prefix + naam** | 2 | T5 | DHW-temperatuur bereikt diepe onderschrijdingsdrempel. |
| `$DHW9hCondition` | `hw` | `$hwLowOrDrop` | **Prefix + naam** | 2 | T5 | DHW-te-koud of >5 °C temperatuurdaling; na 09:00 toegepast. |
| `$DHWTime` | `hw` | `$hwStartHour` | **Prefix + naam** | 4 | T5 | Geplande DHW-triggeruur (0, 8 of 13). |
| `$DHWTimeCondition` | `hw` | `$hwScheduleEligible` | **Prefix + naam** | 2 | T5 | Temperatuur-/weekdagvoorwaarde voor geplande DHW-run. |

### Koelregeling (`cl`)

Gefilterde vraag, afgeronde lokale enable, temperatuur-offset, aanvraag en ondergrens.

| Huidige variabele | Groep / prefix | Volledig voorgestelde naam | Wijziging | Refs | Rules | Huidige betekenis |
| --- | --- | --- | --- | ---: | --- | --- |
| `#CoolingEnable` | `cl` | `#clEnable` | **Prefix + naam** | 5 | Boot, T4, T8 | Laagdoorlaat-gefilterde OT-koelvraag. |
| `$CoolingEnable` | `cl` | `$clEnable` | **Prefix + naam** | 3 | T4 | Afgeronde, minimaal op nul begrensde lokale koelvraag. |
| `$CoolForce` | `cl` | `$clOffset` | **Prefix + naam** | 3 | T4 | Optionele −2 °C-correctie op gekoelde aanvoervraag. |
| `$CoolingControl` | `cl` | `$clReqTemp` | **Prefix + naam** | 3 | T4 | Na grenzen berekende koelvraagtemperatuur (°C). |
| `$CoolReqTempMin` | `cl` | `$clReqTempMin` | **Prefix + naam** | 3 | T4 | Ondergrens voor koelvraag (0 of begrensde outletwaarde). |

### Pompregeling (`pu`)

Pompduty en berekend debietdoel.

| Huidige variabele | Groep / prefix | Volledig voorgestelde naam | Wijziging | Refs | Rules | Huidige betekenis |
| --- | --- | --- | --- | ---: | --- | --- |
| `$MaxPumpDuty` | `pu` | `$puMaxDuty` | **Prefix + naam** | 15 | T6 | Te versturen maximale pompduty-instelling. |
| `$MaxPumpFlow` | `pu` | `$puFlowTarget` | **Prefix + naam** | 2 | T6 | Berekend doeldebiet voor pompduty-berekening. |

### Quiet Mode (`qm`)

Gevraagde Quiet Mode en correctie tijdens DHW.

| Huidige variabele | Groep / prefix | Volledig voorgestelde naam | Wijziging | Refs | Rules | Huidige betekenis |
| --- | --- | --- | --- | ---: | --- | --- |
| `#QMR` | `qm` | `#qmReq` | **Prefix + naam** | 12 | Boot, T7 | Gevraagde quiet-mode-stand. |
| `$QMDHW` | `qm` | `$qmDHWOffset` | **Prefix + naam** | 3 | T7 | Tijdens DHW mogelijke −1 stap aan quiet-mode-commando. |

## Cross-family conventions — gecontroleerd tegen alle voorstellen

**Tijd:** `#Time` blijft de centrale referentie. `...ChangeTime` en `...StartTime` zijn opgeslagen tijdstippen; `...ElapsedMin` zijn tijdsduren. `#cpStateMin` en `#chStateMin` hebben dezelfde getekende betekenis: positieve minuten actief, negatieve minuten inactief. De compressor-opstartteller `#cpRunSec` is bewust een afzonderlijke teller.

**Herkomst versus functie:** ruwe `?chEnable`-uitvalfiltering hoort bij `ot`, de interne gefilterde CH-vraag bij `ch`; `rt`-waarden worden weliswaar via OpenTherm aangeleverd maar zijn eigendom van de kamertemperatuurfunctie. De PI-regelaar heeft een eigen `pi`-prefix.

**Voorgaande waarden:** `Last` betekent vorige bewaarde meting voor vergelijking (`#hwTempLast`); `Prev` betekent eerdere status voor herstel na DHW (`#hpStatePrev`, `#hpModePrev`).

**Compactheid:** omdat de prefix al de functionele context geeft, wordt dubbele terminologie weggelaten (`#cpState`, niet `#cpCompState`; `#rtTemp`, niet `#rtRoomTemp`). Dit verklaart waarom veel voorstellen de wijzigingsklasse **Prefix + naam** hebben, hoewel de semantische inhoud niet verandert.

**Historische waarden:** `#hwState` blijft een enum met speciale toestanden; `#cpState` blijft de compressorstatus-enum; `#cpRunSec` heeft een opstart/sentinel-codering. De variabelenaam-opruiming verandert geen enkele van deze betekenissen of waarden.

## Beslisregister — per werkelijke wijziging

Geen van de onderstaande voorstellen is al geaccepteerd. De auteur beslist per naam **Rename / Keep / Defer**; de tabel is geen opdracht om alle variabelen te hernoemen.

| Huidig → voorstel | Prefix | Wijzigingsindeling | Besluit | Definitieve naam |
| --- | :---: | --- | --- | --- |
| `#CompFreqTarget` → `#cpFreqTarget` | `cp` | Prefix + naam | Rename | — |
| `#CompRunMin` → `#cpStateMin` | `cp` | Prefix + naam | Change | #cpRunMin |
| `#CompRunSec` → `#cpRunSec` | `cp` | Prefix + naam | Rename | — |
| `#CompState` → `#cpState` | `cp` | Prefix + naam | Rename | — |
| `#CompStateChangeTime` → `#cpStateChangeTime` | `cp` | Prefix + naam | Rename | — |
| `$CompElapsed` → `$cpElapsedMin` | `cp` | Prefix + naam | Rename | — |
| `#chEnableTimeOff` → `#otCHOffStartTime` | `ot` | Prefix + naam | Rename | — |
| `$chEnableOffElapsed` → `$otCHOffElapsedMin` | `ot` | Prefix + naam | Rename | — |
| `#chEnableOnMin` → `#chStateMin` | `ch` | Alleen naam | Rename | — |
| `$chEnableCondition` → `$chRestartAllowed` | `ch` | Alleen naam | Rename | — |
| `$chEnableElapsed` → `$chElapsedMin` | `ch` | Alleen naam | Rename | — |
| `$OverNight` → `$chOverNight` | `ch` | Alleen prefix | Rename | — |
| `#RoomSetpoint` → `#rtSetpoint` | `rt` | Prefix + naam | Rename | — |
| `#RoomTemp` → `#rtTemp` | `rt` | Prefix + naam | Rename | — |
| `#RoomTempDelta` → `#rtDelta` | `rt` | Prefix + naam | Rename | — |
| `$RoomError` → `$piError` | `pi` | Prefix + naam | Rename | — |
| `$Kp` → `$piKp` | `pi` | Alleen prefix | Rename | — |
| `$Ki` → `$piKi` | `pi` | Alleen prefix | Rename | — |
| `$PIp` → `$piP` | `pi` | Prefix + naam | Rename | — |
| `#PIDintegral` → `#piIntegral` | `pi` | Prefix + naam | Rename | — |
| `$PIintegralNext` → `$piIntegralNext` | `pi` | Prefix + naam | Rename | — |
| `$PIcandidate` → `$piCandidate` | `pi` | Prefix + naam | Rename | — |
| `$Ilimit` → `$piILimit` | `pi` | Prefix + naam | Rename | — |
| `$PIlimit` → `$piLimit` | `pi` | Prefix + naam | Rename | — |
| `$PIoutput` → `$piOutput` | `pi` | Prefix + naam | Rename | — |
| `#RoomTempControl` → `#piCorrection` | `pi` | Prefix + naam | Rename | — |
| `#TaPIStepTime` → `#piStepTime` | `pi` | Prefix + naam | Rename | — |
| `#WCS` → `#wcBase` | `wc` | Prefix + naam | Change | #wcTarget |
| `$WCS` → `$wcAdjusted` | `wc` | Prefix + naam | Rename | — |
| `$Ta1` → `$wcTa1` | `wc` | Alleen prefix | Change | $wcTargetLow |
| `$Ta2` → `$wcTa2` | `wc` | Alleen prefix | Change | $wcTargetHigh |
| `$Tb1` → `$wcTb1` | `wc` | Alleen prefix | Change | $wcOutsideHigh |
| `$Tb2` → `$wcTb2` | `wc` | Alleen prefix | Change | $wcOutsideLow |
| `#SHifT` → `#taShift` | `ta` | Prefix + naam | Rename | — |
| `#TaDelta` → `#taDelta` | `ta` | Prefix + naam | Rename | — |
| `#TaDeltaTimer` → `#taDeltaSec` | `ta` | Prefix + naam | Rename | — |
| `#NoDefrost` → `#taDefrostAllowed` | `ta` | Prefix + naam | Rename | — |
| `#Z1HRT` → `#taZ1ReqTemp` | `ta` | Prefix + naam | Rename | — |
| `#Heat` → `#hpHeatingMode` | `hp` | Prefix + naam | Rename | — |
| `#HPStateR` → `#hpStateReq` | `hp` | Prefix + naam | Rename | — |
| `#HPStateP` → `#hpStatePrev` | `hp` | Prefix + naam | Rename | — |
| `#OMR` → `#hpModeReq` | `hp` | Prefix + naam | Rename | — |
| `#OMP` → `#hpModePrev` | `hp` | Prefix + naam | Rename | — |
| `#OutsideTemp` → `#hpOutsideTemp` | `hp` | Alleen prefix | Rename | — |
| `#DHWRun` → `#hwState` | `hw` | Prefix + naam | Rename | — |
| `#DHWTempP` → `#hwTempLast` | `hw` | Prefix + naam | Rename | — |
| `#DHWComfortDay` → `#hwComfortDay` | `hw` | Prefix + naam | Rename | — |
| `#DHWSterilizationDay` → `#hwSterilizationDay` | `hw` | Prefix + naam | Rename | — |
| `$DHW10Condition` → `$hwDeepLow` | `hw` | Prefix + naam | Rename | — |
| `$DHW9hCondition` → `$hwLowOrDrop` | `hw` | Prefix + naam | Rename | — |
| `$DHWTime` → `$hwStartHour` | `hw` | Prefix + naam | Rename | — |
| `$DHWTimeCondition` → `$hwScheduleEligible` | `hw` | Prefix + naam | Rename | — |
| `#CoolingEnable` → `#clEnable` | `cl` | Prefix + naam | Rename | — |
| `$CoolingEnable` → `$clEnable` | `cl` | Prefix + naam | Rename | — |
| `$CoolForce` → `$clOffset` | `cl` | Prefix + naam | Rename | — |
| `$CoolingControl` → `$clReqTemp` | `cl` | Prefix + naam | Rename | — |
| `$CoolReqTempMin` → `$clReqTempMin` | `cl` | Prefix + naam | Rename | — |
| `$MaxPumpDuty` → `$puMaxDuty` | `pu` | Prefix + naam | Rename | — |
| `$MaxPumpFlow` → `$puFlowTarget` | `pu` | Prefix + naam | Rename | — |
| `#QMR` → `#qmReq` | `qm` | Prefix + naam | Rename | — |
| `$QMDHW` → `$qmDHWOffset` | `qm` | Prefix + naam | Rename | — |

## Implementatie blijft nadrukkelijk een aparte stap

Pas na per-naam-besluiten: geaccepteerde hernoemingen integraal doorvoeren in de canonieke Rules-bron inclusief parameterplaatsen, commentaren en referenties; na naamsubstitutie uitvoerbare tokens vergelijken; minifier draaien; naamvalidatie, variabelenslots, sprongafstand en compile/load- en praktijkgedrag controleren. De werkende 2611.13 blijft de terugvalbasis.

**In deze PR wordt geen Rules-code gewijzigd.**
