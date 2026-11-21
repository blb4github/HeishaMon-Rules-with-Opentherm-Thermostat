# Changelog

## 2611.19 — 2026-11-21 (combined 2611.17–2611.19 changes since 2611.16)

**Status:** The author reports 2611.19 running on HeishaMon. This entry consolidates the three locally tested iterations, without separate 2611.17/2611.18 changelog entries.

- **2611.17 — stagger pump and target writes:** `timer=6` starts **47 seconds** after successful initialization rather than 40, while retaining its 60-second recurring interval. The intent is to reduce near-simultaneous `SetMaxPumpDuty` and `SetZ1HeatRequestTemperature` commands, which coincided with some requested temperature changes not being reflected in the Panasonic's readback. That correlation does **not** establish a firmware communication defect or prove the timing change resolves it.
- **2611.17 — suppress unnecessary pump-limit commands:** introduce local `$puLimitCheck` in `timer=6`. For normal compressor-driven space heating with no defrost and `@Pump_Flow >= 8`, write `@SetMaxPumpDuty` only if the calculated limit differs **and** `@Pump_Duty >= min(@Max_Pump_Duty, $puMaxDuty)`. Thus, when the actual duty is below both old and desired limits, changing the maximum provides no immediate hydraulic effect and no command is sent. The existing target calculation, minimum limit of 82, DHW, defrost, cooling, compressor-idle and low-flow overrides remain as before.
- **2611.18 — 10-minute sustained room overshoot:** add global `#rtHighStartTime = -1`. In `timer=8`, save `#Time` at the first `#rtDelta > 0.2` reading and reset to -1 on recovery. In `timer=4`, replace the direct daytime +0.2 °C OFF trigger by `#rtHighStartTime >= 0 && (#Time - #rtHighStartTime + 10080) % 10080 >= 10 && %hour > 9`. Weekly wrap-around is retained; no tick counter or new scheduled timer is introduced. Existing independent `#rtDelta > 1.5` and `#chEnable == 0` for over 30 minutes, compressor run/off, outside temperature and restart conditions are unchanged.
- **2611.19 — one shared upper room-temperature threshold:** add `#rtUpperThreshold = 0.21` in `System#Boot` and replace the **five** former `0.2` literals in (1) `timer=8` overtemperature timing, (2) `timer=4` restart permission, (3) compressor-off `TaShift`, (4) GPIO33/Dim demand hysteresis in `timer=8`, and (5) `timer=9` PI-integrator eligibility. The distinct strict/non-strict operators are unchanged. With the previous threshold of 0.2, observed `#rtDelta = +0.203125` could just trigger the OFF dwell; 0.21 deliberately places that reading below the common boundary.
- **Scope and verification:** the author supplied the annotated and loadable 2611.19 files. Their executable token streams match, with 17 Rule handlers. The annotated source's stale `2611.14` header is corrected and documentation is brought up to date; no extra executable changes were introduced while publishing. Overnight/long-run behavior and reliable acknowledgment of heating-target writes still warrant monitoring.

## 2611.16 — 2026-11-18 (target stability refinements; field validation pending)

**Field-test candidate loaded on HeishaMon.** The author reports that 2611.16 is installed. Outcome of the two stability fixes will be evaluated against the 2026-11-18 HeishaMon log and target/room-temperature graphs.

- **A — PI down-step / overshoot interaction (`TaShift2`):** previously the down-step permission checked `@Main_Outlet_Temp <= @Z1_Heat_Request_Temp + 0.8`, relative to the **old/current** target. Now the next target is calculated first, and a proposed reduction is cancelled if `@Main_Outlet_Temp > #taZ1ReqTemp + 0.8`. Intended to stop short 1 °C PI reductions that are immediately undone by outlet overshoot protection during long compressor runs.
- **B — compressor-off target hysteresis (`TaShift`):** change the hold condition from `#rtDelta > 0 && #taShift == -5` to `#rtDelta > -0.15 && #taShift == -5`. This retains the existing 5 °C reduced request through approximately `-0.1 °C` room deviation and seeks to prevent brief 5 °C target spikes and associated short compressor starts near the setpoint.
- Both changes preserve the existing maximum 1 °C PI step, timing logic, independently active overshoot protection and compressor-off time gate. **They deliberately change target behavior** relative to 2611.15, unlike the 2611.14–2611.15 naming/PI readability refactor.
- Both author-supplied 2611.16 files were verified to have identical executable token streams; outside the two named branches and the boot version message, the executable logic is identical to 2611.15.
- Correct the annotated source's stale `2611.14` version header and document the rationale and field-test checklist in [technical notes](docs/TARGET-STABILITY-2611-16.md).
- **Validation still required:** watch for persistent elevated targets after correction A, remaining off-cycle target pulses/short starts after correction B, and normal recovery of heating demand. Loading 2611.16 does not yet prove improvement.
## 2611.15 — 2026-11-18 (variable naming and equivalent PI cleanup)

**Previous release.** The author supplied both the annotated and firmware-loadable 2611.15 files; on-device execution of this precise version has not yet been separately confirmed.

- Carry forward the **61 approved identifier renames** from PR #14 (55 original naming proposals and six author-selected alternatives). The three existing names `#Time`, `#chEnable` and `#chEnableChangeTime` remain unchanged. See [the decision register](docs/RULES-NAMING-INVENTORY-2611-13.md) and [naming convention](docs/RULES-NAMING-CONVENTION.md).
- Restructure `timer=9` for readability with `$piError = #rtSetpoint - #rtTemp` rather than negating `#rtDelta`. The latter still means actual room temperature minus setpoint and remains unchanged for other control functions.
- Make separate I-term bounds (`$piIMin = -5`, `$piIMax = 5`) and overall correction bounds (`$piMin = -5`, `$piMax = 5`) explicit. Retain `Kp = 1.2`, `Ki = 0.05` per five-minute cycle, the ±5 °C limits, conditional anti-windup, DHW/temporary-OFF hold, and the final whole-degree output rounding.
- **No intentional control-behavior change compared with 2611.13.** Outside `timer=9`, the executable expressions match 2611.13 after the 61-name mapping and version-label normalization. The PI rewrite is equivalent when `#rtDelta = #rtTemp - #rtSetpoint` as maintained by timer 8. No changes to Rule ordering, timer intervals, heat-pump commands or other thresholds.
- Verified the author's **annotated and loadable files have matching executable token streams**. A 250,000-case numerical comparison of old and new PI algebra found no differences; this is not a substitute for on-device release testing.
- Update README and documentation status to reflect the now-published named Rules.

## 2611.14 — 2026-11-18 (intermediate commented-source naming release)

- Apply the decisions from PR #14 to the canonical commented source only; the repository's loadable file remained on 2611.13 at that stage.
- The author confirmed 2611.14 running on HeishaMon with an independently supplied loadable file. The code refactoring changed names and associated documentation, not controller behavior.
- Superseded by the paired annotated/loadable 2611.15 release.
## 2611.13 — 2026-11-16 (two-part TaShift, PI handover and DHW safeguards)

**Current working ruleset.** The author confirmed that 2611.13 loads and runs on HeishaMon; extended operational validation is not implied.

- Replace the interim 24-Rule split with **17 Rules**: `TaShift` handles the heating/DHW/defrost gate, compressor-start logic, effective weather baseline and preliminary target, then calls `TaShift2($WCS)` for controlled PI handover, outlet safeguards, Zone 2 priority and the final target write.
- Calculate the local WAR-adjusted `$WCS` **once** in `TaShift` while the compressor runs and pass it to `TaShift2` as a Rule argument. The compressor-off path retains the `coalesce($WCS, #WCS)` baseline fallback.
- Keep the established original DHW/defrost gate (`#Heat == 1`, three-way valve in heating position, `#DHWRun < 2`, `#NoDefrost == 1`), rather than the temporary extra TaShift/DHW conditions from 2611.12.
- Keep the PI handover's at-most-1 °C accepted target steps. The initial step uses at least 2 minutes with low compressor frequency, or 15 minutes; **subsequent** low-frequency steps use at least **10 minutes** and the fallback remains **15 minutes**.
- In timer 9, hold both `#PIDintegral` and `#RoomTempControl` during DHW and Evohome's temporary 12 °C OFF setpoint. Permit PI updates again when the valve is back in heating position, DHW has ended and `?roomTempSet`/`#RoomSetpoint` are above 12 °C.
- When a Rules-initiated DHW cycle finishes normally, reset `#TaPIStepTime = -1`, `#TaDeltaTimer = 0` and `#TaDelta = 0` before normal heating resumes.
- Keep the established startup, cooling, circulation pump, Quiet Mode and GPIO33 logic. Change the source's waiting-message spacing to match the **author-supplied and tested loadable file** (`timer=1: waiting for HP / OT values`); this is diagnostic text only.
- The prior compilation review reported 193 instructions in `TaShift` and 173 in `TaShift2`, avoiding the 255-instruction conditional-jump overflow. The uploaded annotated and loadable 2611.13 files were checked for matching executable tokens after the diagnostic normalization.
- Update README and add [technical release notes](docs/TA-SHIFT-2611-13.md).

## 2611.12 — 2026-11-16 (intermediate local candidate; superseded)

- Split the oversized TaShift logic across a supervisory Rule and eight helpers (24 Rules in total).
- Add DHW/temporary 12 °C-setpoint PI suspension and post-DHW PI/overshoot reset; those protective behaviors were retained in 2611.13.
- Superseded before repository publication by the simpler 2611.13 structure. Do not use as the current version.

## 2611.11 — 2026-11-16 (local candidate; rejected by firmware jump check)

- Expanded TaShift exceeded the Rules engine's **255-instruction conditional-jump offset** (approximately 360 compiled instructions for the combined Rule); this is separate from the expanded 255-variable-slot table.
- The firmware check correctly rejected loading 2611.11 and retained the previously active Rules. An unchecked overlong jump risks bypassing intended DHW safety conditions.
- Not a usable release; replaced by the split-rule approach in 2611.12 and 2611.13.
## 2611.10 — 2026-11-16 (consistent style and documentation)

**Documentation and formatting only relative to 2611.09.** This release consolidates the current active 16-Rule source; do not confuse this review with the functional PI changes introduced in 2611.08.

- Adopt a consistent format for the complete **annotated source**, retaining all 16 existing Rules, their original order, timer scheduling, conditions and calculations.
- Standardize Rule headers as `Purpose`, `Explanation`, `Result` and `Called by`, describing current behavior rather than accumulating historical change notes.
- Remove obsolete and redundant inline comments. Keep short useful comments aligned in a fixed column **within each Rule**; use a separate comment above a block for non-obvious behavior.
- Apply **8-column tab stops**, tabs only for code indentation and comment alignment, and an approximately **160-column maximum** per line. A different comment column is allowed for each Rule.
- Keep release history in this changelog rather than in the annotated Rules. The commented source is the **single source of truth**; generate the loadable file via minify.
- The waiting diagnostic uses `timer=1: waiting for HP/OT values` consistently in both files; this is a message-text normalization only.
- Confirmed **3,371 identical executable tokens** between the submitted 2611.10 annotated source and loadable counterpart after diagnostic-string normalization. This checks source/minified consistency, **not** physical on-device behavior.
- Update [README](README.md) and add the [Rules coding style](docs/RULES-CODING-STYLE.md) for future maintenance.

## 2611.09 — 2026-11-15 (readability preparation)

- Reintroduce local temporary variables to make complex expressions clearer; in particular, explicit PI parameters/limits in timer 9 and the four weather-curve points `$Ta1`, `$Ta2`, `$Tb1`, `$Tb2` in timer 10.
- Preserve the established Rule ordering and timer cadence.
- The re-expression of the weather curve was intended to preserve its original calculation. This was a preparatory readability release, later followed by the full style review in 2611.10.

## 2611.08 — 2026-11-15 (PI integral contribution and limit corrected)

**Functional controller update relative to 2611.07.**

- In timer 9, retain `Kp = 1.2` but set **`Ki = 0.05` per five-minute update**, with no derivative term.
- Redefine `#PIDintegral` as the integral **contribution in degrees Celsius** instead of an accumulated room-temperature error.
- Clamp the integral contribution independently to **±5 °C** (`$Ilimit = 5`), while separately limiting the combined PI output to **±5 °C** (`$PIlimit = 5`). Changing `Ki` no longer silently changes the integral limit.
- Previously, reducing `Ki` from 0.1 to 0.02 without changing the accumulated-error clamp of ±50 had inadvertently reduced the I contribution limit from ±5 °C to ±1 °C.
- Retain conditional anti-windup and integrator hold across temporary interruptions/setpoint changes; the final correction is still rounded to whole degrees.
- Use `* -1` in place of unary minus on Rules variables for compatibility with the Rules parser.
- **Compatibility change:** the expanded local variables exceed the former 127-slot limit. A 2611.08 load test recorded 16 active Rules and **131/255 variable slots** on a compatible build; builds limited to 127 slots are no longer sufficient. GPIO33 support remains required.

## 2611.07 — 2026-11-15 (startup data-readiness guard)

**Use input readiness rather than a fixed boot delay to initialize rule state.** This is the source provided as the author's current ruleset; dynamic behavior after the change still requires observation.

- In `System#Boot`, schedule **only timer 1** after ten seconds. Previously the boot handler also scheduled timers 2 through 10 independently, allowing their execution before the one-time initialization had succeeded.
- In timer 1, require `isset()` for five selected heat-pump values (`@Heatpump_State`, `@Operating_Mode_State`, `@Outside_Temp`, `@Z1_Heat_Request_Temp`, `@Compressor_Freq`) and three OpenTherm values (`?roomTempSet`, `?roomTemp`, `?chEnable`). Zero is a valid initialized value.
- When a checked input is absent, log `timer=1: waiting for HP / OT values`, retry timer 1 after five seconds, and do not schedule the other periodic timers yet. Once the checked inputs exist, initialize the existing variables and then start timers 2–10.
- Preserve the original normal-case first execution offsets and ordering of timers 2–10 (measured from boot, assuming timer 1 runs at +10 s): 2=+20 s, 3=+35 s, 4=+40 s, 5=+45 s, 6=+50 s, 7=+55 s, 8=+60 s, 9=+65 s, 10=+32 s. On retries, they all shift together.
- No changes to the TaShift and PI control algorithms, GPIO33 demand logic, DHW logic, pump duty or Quiet Mode. Update the rule version string to 2611.07.
- Uploaded readable and ready-to-load files were checked to have the same executable expressions after removing comments/formatting. Their waiting-message text has a harmless spacing difference; both versions are retained exactly as supplied.
- **Motivation:** during the firmware 4.4.0 startup on 2026-11-15, some values were still `NULL` when timer 1 ran. A repeating heat-pump ON/OFF sequence was also observed, but the initialization race is a suspected contributor rather than a proven exclusive cause. See [startup notes](docs/STARTUP-2611-07.md).

## 2611.06 — 2026-11-15 (variable-capacity correction and PI handover)

- Combine the original 2610.08 startup/defrost behavior with the unchanged 2611.01 PI controller, using a stepwise ±1 °C transfer toward the WAR/PI target.
- Require compressor frequency at or below `#CompFreqTarget` after at least two minutes, or a fresh 15-minute escape for **each individual** target step.
- Avoid exceeding the HeishaMon Rules **127-variable limit**: use one `#TaPIStepTime` variable for both phase and timestamp; remove the redundant phase and temporary variables, unused `#Debug`, and `$t3Timer`.
- The author confirmed that 2611.06 loaded successfully and heated the home. [PR #9](https://github.com/blb4github/HeishaMon-Rules-with-Opentherm-Thermostat/pull/9) was merged. See [technical notes](docs/TA-SHIFT-2611-06-REVIEW.md).

## 2611.05 — 2026-11-14 (superseded; rejected on device)

- Proposed controlled stepwise PI transfer after the 2610.08 soft start. This historical change was merged as PR #8, but the device rejected it with `ERROR: maximum number of 127 variables reached`; HeishaMon fell back to its previously loaded rules.
- Replaced by 2611.06, which addressed the variable table limit.

## 2611.01 — review candidate (2026-11-13; not field-tested)

**Combined PI (timer 9) and TaShift update, prepared as one release before initial deployment.**

- Reduce provisional gains to P=1.2 and I=0.02 per five-minute cycle (formerly P=3, I=0.1); remove D.
- Preserve the integral across ordinary setpoint changes; P still responds immediately.
- Integrate only with aggregate heat demand (`#chEnable=1`), available space heating (`#Heat=1`, `#DHWRun<2`, three-way valve in room position, no defrost), and `#RoomTempDelta<=+0.2°C`. This last threshold is a proxy for living-room heat availability, **not** a zone-valve measurement. A temporary compressor stop does not by itself suspend integration.
- Hold the integral without resetting it whenever heating is not available, including during DHW diversion, defrost and night setback.
- Conditional integration prevents additional I accumulation when the **candidate total PI output** exceeds ±5°C; integration in the opposite direction remains possible. Keep absolute integral limits ±50; with I=0.02 they represent at most ±1°C integral contribution.
- Clamp `#RoomTempControl` to ±5°C. Remove obsolete `#PIDpreverror` and `#RoomSetpointP` state variables.
- Offline replay of the 240 five-minute cycles from 2026-11-12: proposed PI ~+2°C at 09:02, 13:32 and 15:02 versus old PID +7/+8/+7°C. This holds the historical room-temperature series fixed and is **not a closed-loop physical forecast**.
- **TaShift included in the same release:** compute effective weather baseline on each call; when the compressor runs normally, honor room PI while keeping the outlet-overshoot target floor. Remove the low-frequency hold that could retain an outdated #SHifT.
- Convert TaDelta and TaDeltaTimer emergency corrections into max() lower-bound safeguards, instead of overriding a positive PI correction.
- Remove the persistent outlet-dependent upper limit on #Z1HRT that previously held the target at 28-30C despite a positive room PI request.
- During compressor idle periods, honor room PI if heat is requested and the existing anti-cycle conditions allow; retain nighttime -5C suppression if the living room is not cold or heating demand is absent.
- Preserve the existing first-130-second high-outside-temperature soft-start exception, ±5C shift limit, defrost/DHW guards and explicit Zone 2 override. TaShift does not add another PI damper or timer.
- Open-loop counterfactual for 12 November: at 09:02 a candidate target of about 33C (old 28C); at 13:32 about 32C (old 30C). Actual room temperatures and compressor response under the new rules remain untested.
- See [TaShift design review](docs/TA-SHIFT-2611-01-REVIEW.md) for assumptions and test scenarios.


## 2610.08 — 2026-10-30

**HEMS Dim mode changes heating-demand selection (timer 8).**

- When `gpio(33) == 1`, ignore Evohome `?chEnable` when calculating internal `#chEnable`. Instead apply living-room temperature hysteresis using `#RoomTempDelta = #RoomTemp - #RoomSetpoint`:
  - With `#RoomTempDelta < 0`, switch internal `#chEnable` from 0 to 1 (room below setpoint).
  - With `#RoomTempDelta > +0.2`, switch it from 1 to 0 (room more than 0.2 °C above setpoint).
  - From 0 through +0.2 °C inclusive, preserve the previous state.
- Reset `#chEnableTimeOff` in Dim mode, so Evohome's off-delay is not applied to this room-temperature demand.
- Keep `#chEnableChangeTime` and the existing elapsed-time calculation when demand changes, preserving timer 4's runtime-dependent decisions.
- With `gpio(33) != 1`, continue to use the existing filtered Evohome `?chEnable` logic with its greater-than-15-minute off delay.
- **Important:** GPIO33 selects the internal heating-demand logic; it does **not** immediately force a compressor or heat-pump stop. Timer 4 continues applying its existing conditions before acting on a changed demand. This supersedes the direct internal demand-block behaviour introduced in 2610.05.
- The upload includes both the tested ready-to-load rules and its commented source; no other executable logic was deliberately changed from 2610.06 aside from the 2610.07 guard below and this timer 8 change.

## 2610.07 — intermediate local version

**Prevent TaShift from running before rule state initialisation.**

- The `on @Main_Outlet_Temp` event now checks `isset(#Time)` before calling `TaShift()`.
- Timer 1 initialises `#Time` and the current compressor state after boot. Previously an early outlet-temperature event could invoke TaShift before that initialisation.
- This specifically addresses early event ordering, including rules/firmware reload scenarios. It does not introduce a target-temperature floor or three-minute target-write restriction; existing TaShift calculations are otherwise retained.

## 2610.06 — 2026-10-20

Changes present in the supplied 2610.06 files since the 2610.04 GitHub release:

- Correct the warm-season check for an early DHW run: `%month > 3 && %month < 9` (April–August) instead of the always-true OR expression.
- Replace the hard-coded DHW comfort-day comparison with `%day == #DHWComfortDay`.
- Retain the GPIO33 HEMS heat-demand block introduced in local version 2610.05.
- No additional running-compressor restart target-write guard is present in the supplied 2610.06 executable code.

## 2610.05 — local intermediate version

- Add a HEMS heat-demand block using `gpio(33)` in timer 8. An explicit value of 1 sets internal `#chEnable` to zero; otherwise the normal Evohome demand logic is applied. The actual heat-pump stop decision remains subject to timer 4 conditions.

## 2610.04 — 2026-10-15

Changes since published version **2610.03**.

### TaShift idle hysteresis

- Add hysteresis to the compressor-off TaShift logic to avoid repeated target switching around the room setpoint.
- Keep a previously active `#SHifT = -5` while `#RoomTempDelta` remains between 0 and +0.1 °C.
- Switch to `#SHifT = -5` when `#RoomTempDelta > 0.1` °C once the compressor-off duration condition is met.
- Release the retained −5 °C shift when `#RoomTempDelta <= 0`, or when the shift was not already −5 °C.
- Existing night-time and `#RoomTempDelta > 0.2` behaviour remains unchanged.

### Room-temperature input

- The rules continue to use `?roomTemp` directly through OpenTherm Data-ID 24.
- During validation, short non-physical Evohome/ramses room-temperature spikes were observed. They can make the rules correctly react to a false temperature step and therefore cause a short heating-target jump.
- In the current installation this is handled upstream in Home Assistant with a low-pass filtered room-temperature sensor (`time_constant: 15`, `precision: 2`) before sending `RT=<temperature>` to the OTGW. This is an integration measure, not a rules-language change.

### Validation

- Confirmed in detailed HeishaMon logging that a short 25 → 30 °C target jump was caused by a `?roomTemp` glitch, not by an unexplained Panasonic target reset: timer 3 explicitly set `#SHifT = 0` and `#Z1HRT = 30` after the false negative room-temperature delta.
- Update the boot version string and repository documentation to 2610.04.

## 2610.03 — 2026-10-11

Changes since published version **2610.01**. Intermediate local version 2610.02 is intentionally included in this release rather than documented as a separate published release.

### Heating startup

- Improve the compressor startup cycle to avoid the previous target-temperature jump from approximately 25 °C to 30 °C during ramp-up.

### OpenTherm room temperature

- Use `?roomTemp` directly as the current room temperature instead of decoding a temperature from `?maxRelativeModulation`.
- Use the OpenTherm Gateway `RT=<temperature>` command, introduced in OTGW firmware 6.7, to provide Room Temperature as OpenTherm Data-ID 24.
- Keep `?roomTempSet` as the room setpoint; in this setup Home Assistant supplies it to the OTGW with `BS=<temperature>` (OpenTherm Data-ID 16).
- Remove the former `maxRelativeModulation` room-temperature encoding, including the fallback in which a value of 100 used the room setpoint.
- Remove the special `#RoomTemp != 15` condition that blocked a new `chEnable` activation. A room temperature of 15 °C is no longer used as a transport sentinel and can again be treated as a normal temperature.
- `chEnable` remains the heating-demand signal and retains the existing filtering of short off periods.

### Documentation

- Update the environment and integration notes for the new `RT=` / `?roomTemp` path.
- Document the OTGW firmware 6.7 requirement for `RT=` and the use of `AA=24` when Data-ID 24 must be injected as an alternative Data-ID.
- Update the boot version string and README to 2610.03.

## 2610.01 — 2026-10-10

Changes since published version **2609.02**.

### Domestic hot water

- Require `#DHWRun < 1` before starting a rules-controlled DHW run. Active, finishing and boot-detected runs cannot re-enter the start branch and overwrite the saved previous operating mode (`#OMP`) or heat-pump state (`#HPStateP`).
- Lower the scheduled sterilisation-day DHW-start threshold from below 55 °C to below 50 °C. At 50 °C or above, that specific scheduled trigger does not request a run. This changes the start trigger, not the sterilisation target temperature; other DHW triggers and the existing sterilisation logic during a DHW run remain unchanged.
- Update the boot version string and DHW explanation in both rules files.

### Loading and recovery

- Document that timer 1 still adopts the current operating mode 10 seconds after boot, and timer 8 enforces `#OMR` every 30 seconds. A previously adopted DHW-only mode is not automatically corrected by this release; initialise the rules with the intended operating mode when recovering from this state.

### Validation

- Confirmed that the commented source and ready-to-load rules contain identical executable content after comments and whitespace are removed.
- Reviewed changes against published 2609.02. Heat-pump runtime behaviour after recovery remains to be verified in the installation.

## 2609.02

Consolidated changes since the previously published GitHub version **2602.22d**. Intermediate local versions are intentionally omitted.

### Heating and TaShift

- Shorten the initial soft-start condition from 150 to 130 seconds.
- Keep the existing shift when the compressor is below 21 Hz and the newly calculated shift would be lower.
- Calculate the normal running shift with a 1.9 °C outlet-temperature margin instead of 2 °C.
- Initialise the high-temperature-difference timer at 10 seconds and reduce its intervention threshold from 180 to 80 seconds. Run TaShift every 15 seconds while this timer is active.
- Add a check for a requested target at least 3 °C above the outlet temperature, alongside the existing high outlet-temperature check.
- Require a positive room-temperature difference for the temperature-dependent idle reduction; night-time and room-overtemperature conditions remain available.
- Store the requested heating temperature in `#Z1HRT`, use `coalesce($WCS, #WCS)` as the weather-compensation fallback, and remove the previous fixed 27 °C minimum. The direct Z2 temperature override remains available.
- Reduce the usual heating switch-on room-temperature threshold from +0.3 to +0.2 °C and the daytime switch-off threshold from +0.7 to +0.2 °C; existing runtime, outside-temperature and demand conditions still apply.

### OpenTherm and timekeeping

- Calculate room temperature before processing heating demand. Ignore a new `chEnable` activation when the decoded room temperature is 15 °C, the value used here to indicate heating is off.
- Calculate compressor elapsed time, `chEnable` elapsed time and the `chEnable` off-delay modulo 10,080 minutes to handle the weekly time-reference rollover in both running and stopped states. Elapsed durations still wrap after a full week.
- Use timer 1 for one-time initialisation and timer 2 for the recurring minute clock; timer 2 now first runs 20 seconds after boot.
- Read `?dhwEnable` directly instead of keeping a duplicate global variable; reduce several other temporary variables and use explicit state comparisons in multiple rules.

### Cooling

- Block thermostat heating/cooling control while sterilisation is active or a rules-controlled DHW run is in progress.
- When the compressor is stopped and outlet temperature exceeds the main target by more than 3 °C, lower the cooling request by 2 °C, subject to the existing limits.
- Compare the actual cooling request with the calculated, limited target before sending an update.
- Apply the running-compressor cooling-temperature limit specifically in compressor state 1, rather than any nonzero state.
- Return to heating/off after cooling only when the requested mode is cooling (1), instead of any nonzero mode.

### Domestic hot water and pump control

- Include equality at the two low tank-temperature trigger thresholds and start the daytime condition at 09:00 rather than after 09:00.
- Change the scheduled sterilisation-day DHW-run trigger from tank temperature below 63 °C to below 55 °C. This is a run trigger, not the sterilisation target temperature.
- Select heat+DHW from previous mode 0, cool+DHW from previous mode 1, and DHW-only for other previous modes.
- Increase the heating idle-pump duty formula from `102 - 4 * Heat_Delta` to `112 - 4 * Heat_Delta` while the heat pump is on, the compressor is stopped and defrost is inactive, to address E62 errors. Other duty limits remain unchanged.

### Repository documentation

- Provide the ready-to-load rules as `HeishaMon_Rules_BlB4.lua` and the documented source as `HeishaMon_Rules_BlB4_commented.lua`.
- Replace the obsolete `.md`/`.txt` rules files and update installation, firmware and Home Assistant integration notes.
- Remove the stale README reference to ExternalOverride; its removal predates this release.
