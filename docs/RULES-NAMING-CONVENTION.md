# HeishaMon Rules — variable naming design criteria

**Status:** NC-01–NC-12 and the final name choices were reviewed in PR #14; the 61 selected renames were implemented in 2611.14 (commented source) and are published together with the loadable Rules in 2611.15. The remaining three identifiers were retained.
**Reference ruleset:** 2611.13.
**Scope:** Naming and documentation of user-defined global (`#`) and local (`$`) variables. This document does **not** authorize any renaming.

The goal is **consistent, compact, meaningful naming** without changes to heat-pump behavior. This builds on [RULES-CODING-STYLE.md](RULES-CODING-STYLE.md); that document governs layout and Rule documentation, while this document governs variable names.

## Twelve design criteria

| ID | Criterion | Decision rule |
| --- | --- | --- |
| NC-01 | **Prefix plus PascalCase** | Gebruik twee kleine letters voor het functionele domein, direct gevolgd door de naamstam in PascalCase: `$piKp`, `#rtTemp`, `#hwTempLast`. Geen underscores. De lowercase prefix is de enige standaarduitzondering op een initiële PascalCase-hoofdletter. |
| NC-02 | **Meaning over implementation** | Name what a value represents, rather than restating the expression used to calculate it. Avoid names whose meaning differs from the stored state. |
| NC-03 | **Shortest name that stays clear** | Prefer concise, specific names. Longer is not automatically better: judge readability in the *full expression*, especially when referenced frequently. |
| NC-04 | **Consistent abbreviations** | Allow commonly understood domain acronyms and a documented, small glossary. Avoid arbitrary contractions whose meaning requires historical knowledge. |
| NC-05 | **Consistent terminology** | One term per concept across Rules. Use `Req` for requested, `Target` for calculated target and `Actual` for measured/current values only where accurate. **`Last`** means the last earlier **sample/measurement** retained for comparison. **`Prev`** means a **previous state** temporarily retained so it can be restored after a transition. The historical suffix `P` may have different meanings; interpret the value, not the letter. `Saved` is not our chosen suffix for a previous restorable state. |
| NC-06 | **Units and time semantics** | Distinguish clock references, event timestamps and elapsed time through the **full identifier and context**. `Time` can legitimately mean a duration, as in running time; `Duration` is **not mandatory**. State units (`Min`, `Sec`, `Hour`) where necessary. Explain shared signed-duration conventions once per variable family and use an analogous structure for equivalent variables. Avoid forced implementation-derived names such as `WeekMin` when they reduce clarity. Temperature is in °C unless otherwise documented. |
| NC-07 | **Scope-sensitive length** | Global `#` variables should be intelligible outside the Rule that first writes them; local `$` names may rely more heavily on immediate Rule context. |
| NC-08 | **State versus value** | Distinguish boolean conditions/states (`Enabled`, `Active`), requested states (`Req`), **previous restorable states** (`Prev`), **last sampled values** (`Last`), and numeric targets/corrections (`Target`, `Correction`) when the differences matter. |
| NC-09 | **Retain useful established names** | Preserve clear, familiar identifiers when renaming offers little benefit. **`#Time`** is retained as a valid central time reference, derived from clock day/hour/minute with minute resolution and used to calculate modulo-10080 elapsed intervals. It is neither an independent ticking counter nor a HeishaMon timer. Document it instead of renaming it for cosmetic uniformity. |
| NC-10 | **Behavior-preserving refactor** | Names may change only in a separately approved refactoring. No changes to calculations, conditions, Rule order, timers, safety guards, interfaces or on-device behavior are permitted as part of a naming-only change. |
| NC-11 | **Group-wise review** | Assign each variable one primary **functional family** before proposing names: time and timers, compressor, CH/OpenTherm, PI control, weather curve/TaShift, heat-pump/mode state, DHW, cooling, pumps/quiet mode, etc. Agree name structure and terminology **within and across groups** before any per-variable choice. A variable may of course be used in several Rules. |
| NC-12 | **Functioneel eigenaarschap** | Alle eigen globale `#`- en lokale `$`-variabelen krijgen precies één functionele eigenaar en bijbehorende tweekarakters-prefix, ongeacht het invoerprotocol. Vermijd duplicatie van domeintermen in de stam (`#rtTemp`, niet `#rtRoomTemp`); uitzonderingen, zoals `#Time`, expliciet vastleggen. |

### Tweeletter-prefixwoordenlijst — PR #14

**Naamvorm:** `#` of `$` + exact twee kleine ASCII-letters + PascalCase-stam, zonder underscores. De reguliere variabelenlexer gebruikt in HeishaMon `isalnum()` na het sigil. Protocol- en systeemvelden (`@`, `?`, `%`) worden niet hernoemd.

| Prefix | Eigenaar | Afbakening |
| --- | --- | --- |
| `ot` | Ruwe OpenTherm-signaalverwerking | Wachtstatus voor ruwe OT-CH-uitval |
| `rt` | Kamertemperatuur | Temperatuur, setpoint en delta |
| `pi` | PI-regeling | Kp, Ki, fout, integrator, anti-windup, stapmoment |
| `ch` | Centrale verwarmingsvraag | Gefilterde CH-vraag en statusduur |
| `hw` | Tapwater | DHW-toestand, temperatuurhistorie en schema |
| `hp` | Warmtepomp | Status, modus en algemene buitentemperatuur |
| `cp` | Compressor | Compressorstatus, looptijd en frequentie |
| `cl` | Koeling | Koelvraag en koeltemperatuur |
| `pu` | Pomp | Pompduty en debiet |
| `qm` | Quiet Mode | Quiet-aanvraag en DHW-offset |
| `wc` | Weersafhankelijke regeling | Stooklijnpunten, basis en correctie |
| `ta` | Aanvoertemperatuur/TaShift | Ta-delta, shift, defrost-gate, Z1-verzoek |

**Bewuste uitzondering:** `#Time` blijft de gedeelde centrale tijdreferentie zonder prefix. Een domeinprefix wordt gekozen op basis van de *functie van de opgeslagen toestand*: `ot` is alleen ruwe OT-ingangsverwerking, terwijl afgeleide CH-vraag `ch` is, kamertemperatuur `rt` en PI-parameters `pi`.

**Semantiek over groepen heen:** `Last` voor een vorige meetwaarde die met de huidige wordt vergeleken; `Prev` voor een toestand die tijdelijk wordt bewaard voor herstel; `Req` voor een verzoek. De getekende statusduur is +actief/−inactief, in minuten. `Duration` is geen verplichte naamcomponent.
### Interpretation of the refined conventions

- **`#Time`:** retain this established name. It is recalculated as `%day * 1440 + %hour * 60 + %minute`, giving minute resolution; it is not incremented by a separate timer. Elapsed differences are calculated modulo 10080.
- **Signed durations:** `#CompRunMin` and `#chEnableOnMin` both represent a positive ON duration and a negative OFF duration in minutes. Evaluate them together; do not add `Signed` to just one. Document the shared sign convention.
- **`Last` and `Prev`:** `#DHWTempP` → `#hwTempLast` would describe a last earlier sample retained for comparison. `#HPStateP` → `#hpStatePrev` and `#OMP` → `#hpModePrev` would denote previous states held for restoration. These examples were approved in the decision register and implemented in 2611.14/2611.15.
- **Time terminology:** a timestamp could use `ChangeTime` or `StartTime`; elapsed time could use `RunTime`, `ElapsedMin`, or `StateMin`. Neither `Duration` nor `WeekMin` is compulsory.

**Review priority:** semantic correctness and consistency **within a functional group**, then compactness/readability of complete expressions, and only then cosmetic uniformity.

### Scope exclusions and exceptions

- `@...` (HeishaMon heat-pump interface), `?...` (OpenTherm interface), `%...` time/runtime values, Rule event names, built-in functions and their signatures are **not renamed** by this convention.
- Existing short domain names such as `#WCS` are not automatically renamed. Whether a specific name remains or changes is decided in the review phase, not by this document alone.
- A proposed new name must not collide with a different existing symbol or built-in name. Any refactoring must rename **all references**, including parameter passing such as `TaShift2($WCS)`, in a controlled manner.
- Consistency with the HeishaMon Rules syntax and compiler takes priority over cosmetic preferences.

## Engineering constraints (separate from the style preferences)

1. **Variable slots:** the tested firmware supports 255 variable slots, compared with the earlier 127-slot limit. A simple rename should not create duplicate old/new symbols or increase the number of unique user variables. Name length and variable count are different properties; do not assume identifier length has zero compiler/memory impact without checking.
2. **Bytecode jumps:** conditional jumps are subject to a 255-instruction offset limit, independent of variable slots. Verify compilation and jump-range checks after renaming.
3. **Parser and firmware:** the selected identifiers must compile in the actual Rules engine and remain compatible with `gpio(33)`, OpenTherm and parameterized Rule calls used in 2611.13.
4. **No behavioral drift:** compare the original and proposed executable logic after mechanically mapping approved old identifiers to their new names. Counts, instruction/jump checks, load logs and a physical run test are separate safeguards; textual equivalence alone is not a runtime guarantee.
5. **Minifier and strings:** the loadable file is derived from the commented canonical source. The minifier is known to insert spaces around `/` even inside a diagnostic string (e.g. `HP/OT` becomes `HP / OT`). Handle this separately from variable-rename verification; do not silently adjust control semantics.
6. **Rollback:** preserve working Rules 2611.13 and the validated firmware as a reproducible reference until a renamed version has passed tests.

The [2611.13 variable inventory](RULES-NAMING-INVENTORY-2611-13.md) preserves the original proposals and complete author-approved decision register. All 61 changes are implemented in 2611.15, including the six `Change` decisions specifying alternatives.

## Review and decision process

The process deliberately separates **design criteria**, **naming proposals**, and **approval**:

1. **Criteria (this document):** agree the above rules first, without editing any Rule code.
2. **Prefixgroepen en volledige inventaris:** wijs alle 64 gebruikersvariabelen aan één primaire prefixgroep toe; vermeld huidig, prefix, volledige voorstelnaam, gebruik, betekenis, wijzigingscategorie en motivatie, vóór enige per-naam keuze of implementatie.
3. **Per-name decision:** review each proposed change individually with the author and record **Rename / Keep / Defer**, its final approved name and any reason/exception. Even a clearly better candidate is not applied automatically.
4. **Implementation only after approval:** apply only accepted renames in a separate PR/version. Update source comments and documentation, generate the loadable file, check symbol coverage and executable equivalence, compile with the intended firmware, verify limits and run on-device tests. Do not merge unreviewed code.

### Indeling van voorgestelde wijzigingen

- **Geen wijziging:** de naam blijft exact gelijk.
- **Alleen prefix:** uitsluitend de twee prefixletters worden direct achter `#` of `$` ingevoegd; de oorspronkelijke naam blijft letter voor letter intact, bijvoorbeeld `$Kp` → `$piKp`.
- **Alleen naam:** de correcte prefix staat er al, alleen de stam wijzigt (`#chEnableOnMin` → `#chStateMin`).
- **Prefix + naam:** er komt een (andere) prefix en de stam verandert/wordt korter (`#RoomTemp` → `#rtTemp`).

Deze wijzigingscategorie is uitsluitend een tekstuele classificatie, geen goedkeuring. Voor iedere werkelijke voorgestelde wijziging volgt nog een expliciet besluit.

## Design principle

> Optimize understandability of the overall Rules, not identifier length or uniformity in isolation. Prefer small, demonstrated readability gains while protecting the known-stable 2611.13 controller.
