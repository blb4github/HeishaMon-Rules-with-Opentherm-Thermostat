# HeishaMon Rules — variable naming design criteria

**Status:** Approved design criteria (PR #13 merged); individual identifier changes are not approved.
**Reference ruleset:** 2611.13.
**Scope:** Naming and documentation of user-defined global (`#`) and local (`$`) variables. This document does **not** authorize any renaming.

The goal is **consistent, compact, meaningful naming** without changes to heat-pump behavior. This builds on [RULES-CODING-STYLE.md](RULES-CODING-STYLE.md); that document governs layout and Rule documentation, while this document governs variable names.

## Eleven design criteria

| ID | Criterion | Decision rule |
| --- | --- | --- |
| NC-01 | **PascalCase** | Prefer PascalCase for both `#` and `$` user variables: `#CompRunMin`, `$RoomError`. Widely understood acronyms may remain uppercase within a name (e.g. `DHW`, `HP`, `PI`, `WCS`, `Z1`). A well-established scientific symbol such as `Kp`/`Ki` may remain in conventional notation. |
| NC-02 | **Meaning over implementation** | Name what a value represents, rather than restating the expression used to calculate it. Avoid names whose meaning differs from the stored state. |
| NC-03 | **Shortest name that stays clear** | Prefer concise, specific names. Longer is not automatically better: judge readability in the *full expression*, especially when referenced frequently. |
| NC-04 | **Consistent abbreviations** | Allow commonly understood domain acronyms and a documented, small glossary. Avoid arbitrary contractions whose meaning requires historical knowledge. |
| NC-05 | **Consistent terminology** | One term per concept across Rules. Use `Req` for requested, `Target` for calculated target and `Actual` for measured/current only where accurate. **`Last`** refers to the last earlier **measurement or sampled value** retained for comparison. **`Prev`** refers to a **previous state** temporarily retained so it can be restored after a transition. Do not automatically map a historical suffix `P` to the same word everywhere. `Saved` is not the preferred suffix for those previous states. |
| NC-06 | **Units and time semantics** | Distinguish a central clock reference, a timestamp, and elapsed time by the **complete name and context**. `Time` can also correctly denote a duration (running time, waiting time): `Duration` is **not mandatory**. Add `Min`, `Sec` or `Hour` when units matter. Document a shared sign convention for equivalent signed durations, and use analogous naming structures. Avoid forcing implementation-derived suffixes such as `WeekMin` if they do not improve readability. Temperature values are in °C unless otherwise documented. |
| NC-07 | **Scope-sensitive length** | Global `#` variables should be intelligible outside the Rule that first writes them; local `$` names may rely more heavily on immediate Rule context. |
| NC-08 | **State versus value** | Distinguish boolean conditions/states (`Enabled`, `Active`), requests (`Req`), saved state (`Saved`), and numeric targets/corrections (`Target`, `Correction`) when meaningful. |
| NC-09 | **Retain useful established names** | Preserve clear, familiar names when renaming adds little value. **`#Time` remains a valid central controller time reference:** it is calculated from day/hour/minute with minute resolution and used for modulo-10080 elapsed intervals; it is not a standalone ticking counter or a HeishaMon timer. Document it instead of renaming it for cosmetic uniformity. |
| NC-10 | **Behavior-preserving refactor** | Names may change only in a separately approved refactoring. No changes to calculations, conditions, Rule order, timers, safety guards, interfaces or on-device behavior are permitted as part of a naming-only change. |
| NC-11 | **Group-wise review** | Assign each variable a primary **functional family** before proposing names: time/timers, compressor, CH/OpenTherm, PI control, weather curve/TaShift, heat-pump/mode state, DHW, cooling, pumps/quiet mode, etc. Agree consistent semantics and structures **within and across families**; group membership is a review aid, not a restriction on usage across Rules. |

### Interpretation of the refined conventions

- **`#Time`:** retain the established name. It is recalculated as `%day * 1440 + %hour * 60 + %minute` and therefore has minute resolution. The clock value is not incremented by an independent timer; elapsed differences are normalized modulo 10080.
- **Signed durations:** `#CompRunMin` and `#chEnableOnMin` both store a positive ON-time and a negative OFF-time in minutes. Evaluate their candidate names together. There is no reason to add `Signed` to only one when the shared sign convention can be documented once.
- **`Last` versus `Prev`:** `#DHWTempP` → `#DHWTempLast` would indicate the last earlier temperature sample used for comparison. `#HPStateP` → `#HPStatePrev` and `#OMP` → `#ModePrev` would indicate states preserved for later restoration. These are **illustrative candidates only**, not approved renames.
- **Time/duration terms:** an event could use `ChangeTime` or `StartTime`; an elapsed duration could use `RunTime`, `ElapsedMin` or `StateMin`. Do not make `Duration` obligatory. Context and units matter more than a rigid suffix.

**Priority:** correct semantic meaning and consistency **per functional group**, then compactness/readability of whole expressions, then cosmetic uniformity.
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

The [2611.13 variable inventory and rename proposals](RULES-NAMING-INVENTORY-2611-13.md) is an **initial draft** prepared before these refinements. Its suggested names and A/B/C classifications require **group-wise reassessment** before any individual rename decisions.

## Review and decision process

The process deliberately separates **design criteria**, **naming proposals**, and **approval**:

1. **Criteria (this document):** agree the above rules first, without editing any Rule code.
2. **Functional-group review and complete inventory:** enumerate all current `#` and `# HeishaMon Rules — variable naming design criteria

**Status:** Approved design criteria (PR #13 merged); individual identifier changes are not approved.
**Reference ruleset:** 2611.13.
**Scope:** Naming and documentation of user-defined global (`#`) and local (`$`) variables. This document does **not** authorize any renaming.

The goal is **consistent, compact, meaningful naming** without changes to heat-pump behavior. This builds on [RULES-CODING-STYLE.md](RULES-CODING-STYLE.md); that document governs layout and Rule documentation, while this document governs variable names.

## Eleven design criteria

| ID | Criterion | Decision rule |
| --- | --- | --- |
| NC-01 | **PascalCase** | Prefer PascalCase for both `#` and `$` user variables: `#CompRunMin`, `$RoomError`. Widely understood acronyms may remain uppercase within a name (e.g. `DHW`, `HP`, `PI`, `WCS`, `Z1`). A well-established scientific symbol such as `Kp`/`Ki` may remain in conventional notation. |
| NC-02 | **Meaning over implementation** | Name what a value represents, rather than restating the expression used to calculate it. Avoid names whose meaning differs from the stored state. |
| NC-03 | **Shortest name that stays clear** | Prefer concise, specific names. Longer is not automatically better: judge readability in the *full expression*, especially when referenced frequently. |
| NC-04 | **Consistent abbreviations** | Allow commonly understood domain acronyms and a documented, small glossary. Avoid arbitrary contractions whose meaning requires historical knowledge. |
| NC-05 | **Consistent terminology** | One term per concept across Rules. Use `Req` for requested, `Target` for calculated target and `Actual` for measured/current only where accurate. **`Last`** refers to the last earlier **measurement or sampled value** retained for comparison. **`Prev`** refers to a **previous state** temporarily retained so it can be restored after a transition. Do not automatically map a historical suffix `P` to the same word everywhere. `Saved` is not the preferred suffix for those previous states. |
| NC-06 | **Units and time semantics** | Distinguish a central clock reference, a timestamp, and elapsed time by the **complete name and context**. `Time` can also correctly denote a duration (running time, waiting time): `Duration` is **not mandatory**. Add `Min`, `Sec` or `Hour` when units matter. Document a shared sign convention for equivalent signed durations, and use analogous naming structures. Avoid forcing implementation-derived suffixes such as `WeekMin` if they do not improve readability. Temperature values are in °C unless otherwise documented. |
| NC-07 | **Scope-sensitive length** | Global `#` variables should be intelligible outside the Rule that first writes them; local `$` names may rely more heavily on immediate Rule context. |
| NC-08 | **State versus value** | Distinguish boolean conditions/states (`Enabled`, `Active`), requests (`Req`), saved state (`Saved`), and numeric targets/corrections (`Target`, `Correction`) when meaningful. |
| NC-09 | **Retain useful established names** | Preserve clear, familiar names when renaming adds little value. **`#Time` remains a valid central controller time reference:** it is calculated from day/hour/minute with minute resolution and used for modulo-10080 elapsed intervals; it is not a standalone ticking counter or a HeishaMon timer. Document it instead of renaming it for cosmetic uniformity. |
| NC-10 | **Behavior-preserving refactor** | Names may change only in a separately approved refactoring. No changes to calculations, conditions, Rule order, timers, safety guards, interfaces or on-device behavior are permitted as part of a naming-only change. |
| NC-11 | **Group-wise review** | Assign each variable a primary **functional family** before proposing names: time/timers, compressor, CH/OpenTherm, PI control, weather curve/TaShift, heat-pump/mode state, DHW, cooling, pumps/quiet mode, etc. Agree consistent semantics and structures **within and across families**; group membership is a review aid, not a restriction on usage across Rules. |

### Interpretation of the refined conventions

- **`#Time`:** retain the established name. It is recalculated as `%day * 1440 + %hour * 60 + %minute` and therefore has minute resolution. The clock value is not incremented by an independent timer; elapsed differences are normalized modulo 10080.
- **Signed durations:** `#CompRunMin` and `#chEnableOnMin` both store a positive ON-time and a negative OFF-time in minutes. Evaluate their candidate names together. There is no reason to add `Signed` to only one when the shared sign convention can be documented once.
- **`Last` versus `Prev`:** `#DHWTempP` → `#DHWTempLast` would indicate the last earlier temperature sample used for comparison. `#HPStateP` → `#HPStatePrev` and `#OMP` → `#ModePrev` would indicate states preserved for later restoration. These are **illustrative candidates only**, not approved renames.
- **Time/duration terms:** an event could use `ChangeTime` or `StartTime`; an elapsed duration could use `RunTime`, `ElapsedMin` or `StateMin`. Do not make `Duration` obligatory. Context and units matter more than a rigid suffix.

**Priority:** correct semantic meaning and consistency **per functional group**, then compactness/readability of whole expressions, then cosmetic uniformity.
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

The [2611.13 variable inventory and rename proposals](RULES-NAMING-INVENTORY-2611-13.md) is an **initial draft** prepared before these refinements. Its suggested names and A/B/C classifications require **group-wise reassessment** before any individual rename decisions.

## Review and decision process

The process deliberately separates **design criteria**, **naming proposals**, and **approval**:

1. **Criteria (this document):** agree the above rules first, without editing any Rule code.
 variables, assign each a primary functional group, and first agree the group's terminology and naming structure. For every variable then record current name, scope, meaning, using Rule(s), frequency where practical, applicable criteria, candidate name (including explicit retention), and rationale. Do not implement renames.
3. **Per-name decision:** review each proposed change individually with the author and record **Rename / Keep / Defer**, its final approved name and any reason/exception. Even a clearly better candidate is not applied automatically.
4. **Implementation only after approval:** apply only accepted renames in a separate PR/version. Update source comments and documentation, generate the loadable file, check symbol coverage and executable equivalence, compile with the intended firmware, verify limits and run on-device tests. Do not merge unreviewed code.

### Classification of current names

- **A — Keep:** meets the criteria well enough; no change proposed.
- **B — Propose rename:** demonstrably clearer or more consistent; *proposal only* pending author decision.
- **C — Keep with documentation:** compact or established terminology whose meaning should be recorded in a glossary.

An assessment in category B does **not** mean a rename is approved. The author decides for every such name. The inventory is an evidence-based proposal, not a bulk rename plan.

## Design principle

> Optimize understandability of the overall Rules, not identifier length or uniformity in isolation. Prefer small, demonstrated readability gains while protecting the known-stable 2611.13 controller.
