# HeishaMon Rules — variable naming design criteria

**Status:** Approved design criteria (PR #13 merged); individual identifier changes are not approved.
**Reference ruleset:** 2611.13.
**Scope:** Naming and documentation of user-defined global (`#`) and local (`$`) variables. This document does **not** authorize any renaming.

The goal is **consistent, compact, meaningful naming** without changes to heat-pump behavior. This builds on [RULES-CODING-STYLE.md](RULES-CODING-STYLE.md); that document governs layout and Rule documentation, while this document governs variable names.

## Ten design criteria

| ID | Criterion | Decision rule |
| --- | --- | --- |
| NC-01 | **PascalCase** | Prefer PascalCase for both `#` and `$` user variables: `#CompRunMin`, `$RoomError`. Widely understood acronyms may remain uppercase within a name (e.g. `DHW`, `HP`, `PI`, `WCS`, `Z1`). A well-established scientific symbol such as `Kp`/`Ki` may remain in conventional notation. |
| NC-02 | **Meaning over implementation** | Name what a value represents, rather than restating the expression used to calculate it. Avoid names whose meaning differs from the stored state. |
| NC-03 | **Shortest name that stays clear** | Prefer concise, specific names. Longer is not automatically better: judge readability in the *full expression*, especially when referenced frequently. |
| NC-04 | **Consistent abbreviations** | Allow commonly understood domain acronyms and a documented, small glossary. Avoid arbitrary contractions whose meaning requires historical knowledge. |
| NC-05 | **Consistent terminology** | Use one term for one concept across Rules. Where useful, distinguish `Req` (requested), `Saved` (stored for restoration), `Target` (calculated target), and `Actual` (measured state). Do not assume those distinctions when the current semantics do not support them. |
| NC-06 | **Units and time semantics** | State units where omission could cause confusion: `Min`, `Sec`, optionally `WeekMin` for week-relative timestamps. Distinguish timestamps from durations, including signed running/off durations. Temperature values are in °C unless otherwise documented. |
| NC-07 | **Scope-sensitive length** | Global `#` variables should be intelligible outside the Rule that first writes them; local `$` names may rely more heavily on immediate Rule context. |
| NC-08 | **State versus value** | Distinguish boolean conditions/states (`Enabled`, `Active`), requests (`Req`), saved state (`Saved`), and numeric targets/corrections (`Target`, `Correction`) when meaningful. |
| NC-09 | **Retain useful established names** | Keep an existing name when it is clear and well understood. Renaming solely for superficial uniformity is not sufficient justification; document an understandable compact legacy term when appropriate. |
| NC-10 | **Behavior-preserving refactor** | Names may change only in a separately approved refactoring. No changes to calculations, conditions, Rule order, timers, safety guards, interfaces or on-device behavior are permitted as part of a naming-only change. |

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

The [2611.13 variable inventory and rename proposals](RULES-NAMING-INVENTORY-2611-13.md) documents step 2, while all per-name decisions remain pending.

## Review and decision process

The process deliberately separates **design criteria**, **naming proposals**, and **approval**:

1. **Criteria (this document):** agree the above rules first, without editing any Rule code.
2. **Complete inventory and suggested names:** enumerate *every* current `#` and `$` variable from the canonical 2611.13 source. For each, record current name, scope, meaning, Rule(s) using it, frequency of use (when practical), criteria affected, proposed future name (including a deliberate recommendation to retain the existing name), and concise rationale. Do not implement proposed renames.
3. **Per-name decision:** review each proposed change individually with the author and record **Rename / Keep / Defer**, its final approved name and any reason/exception. Even a clearly better candidate is not applied automatically.
4. **Implementation only after approval:** apply only accepted renames in a separate PR/version. Update source comments and documentation, generate the loadable file, check symbol coverage and executable equivalence, compile with the intended firmware, verify limits and run on-device tests. Do not merge unreviewed code.

### Classification of current names

- **A — Keep:** meets the criteria well enough; no change proposed.
- **B — Propose rename:** demonstrably clearer or more consistent; *proposal only* pending author decision.
- **C — Keep with documentation:** compact or established terminology whose meaning should be recorded in a glossary.

An assessment in category B does **not** mean a rename is approved. The author decides for every such name. The inventory is an evidence-based proposal, not a bulk rename plan.

## Design principle

> Optimize understandability of the overall Rules, not identifier length or uniformity in isolation. Prefer small, demonstrated readability gains while protecting the known-stable 2611.13 controller.
