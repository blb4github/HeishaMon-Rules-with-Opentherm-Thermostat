# HeishaMon rules with an OpenTherm thermostat

These are the rules I use to control a Panasonic heat pump with an OpenTherm thermostat. They are tailored to my installation; use them as inspiration and adapt the settings and integration to your own system.

## Current version: 2611.19 (2026-11-21)

See [CHANGELOG.md](CHANGELOG.md) for the changes in each published version.

| File | Purpose |
| --- | --- |
| [HeishaMon_Rules_BlB4.lua](HeishaMon_Rules_BlB4.lua) | Generated, ready-to-load rules (minified from the annotated source) |
| [HeishaMon_Rules_BlB4_commented.lua](HeishaMon_Rules_BlB4_commented.lua) | **Canonical, documented source**; make maintenance changes here and minify before loading |

The `.lua` extension is a filename convention: these files use the **HeishaMon rules language**, including `on ... then`, `@`, `#`, `$` and `?` variables. They are not standard Lua programs.

## My setup

- Panasonic WH-MDC07J3E5 for heating, cooling and domestic hot water with an external tank; radiators and convectors.
- HeishaMon Large (ESP32-S3), currently on a firmware build identified as **4.4.0**. The Rules require `gpio(33)` support for HEMS Dim; verify that capability in the actual firmware build rather than relying on the version number alone. See the firmware requirement below.
- CZ-TAW1 connected to the proxy port; I do not use it actively.
- Honeywell Evohome with an R8810 OpenTherm bridge, connected through an OpenTherm Gateway.
- Home Assistant with Evohome and OpenTherm Gateway integrations. Home Assistant supplies the living-room target and current temperature through the OTGW as normal OpenTherm room values, because Evohome's `chSetpoint` is not suitable as the primary control input for this heat-pump strategy.
- OTGW firmware 6.7 or newer is required for the `RT=` command used to provide Room Temperature (OpenTherm Data-ID 24).
- Heat-pump settings: `Heating_Mode: 1` (direct), `Cooling_Mode: 1` (direct), `Buffer_Installed: 0`, `DHW_Installed: 1`, `Pump_Flowrate_Mode: 0`, `Optional_PCB: 0`, `Z1_Sensor_Settings: 0`.

## What the rules do

1. Adjust maximum pump duty for heating, cooling, DHW and idle operation.
2. Set Quiet Mode based on compressor frequency, runtime, outside temperature, time of day and operating mode; allow an override through the buffer-tank delta setting.
3. Schedule DHW and sterilisation runs, with additional tank-temperature triggers and restoration of the previous operating mode/state.
4. Synchronise heat-pump temperatures and operating status with OpenTherm.
5. Control heating demand using filtered `chEnable`, room-temperature difference, outside temperature and runtime conditions.
6. Calculate weather compensation and use TaShift with room-temperature PI correction to adjust the heating target and support longer compressor runs.
7. Control cooling using Home Assistant/OpenTherm enable and water-temperature requests.
8. Handle the weekly clock rollover in compressor and thermostat elapsed-time calculations.

### TaShift/PI handover (introduced in 2611.06)

Historically, Rules 2611.06 combined the established 2610.08 compressor-start and defrost behavior with the room-temperature PI controller from 2611.01 (timer 9, P=1.2, I=0.02 per five-minute cycle, no D). The heating target is transferred toward the weather-compensation-plus-PI request in **steps of at most 1 °C**. Each step requires the compressor frequency to be at or below `#CompFreqTarget` after at least two minutes, **or** a newly started 15-minute timeout since the last step. Outlet overshoot safeguards and direct Zone 2 request overrides remain in place.

The preceding 2611.05 candidate could not be loaded because it exceeded the Rules engine's **127-variable limit**; 2611.06 removed redundant state/temporary variables. The author confirmed that 2611.06 loaded and heated the home, and merged the fix. See [2611.06 technical notes](docs/TA-SHIFT-2611-06-REVIEW.md).

### Startup initialization in 2611.07

A firmware-startup log from 15 November 2026 showed `timer=1` running before all relevant heat-pump data had been received. Values including `#OutsideTemp` and `#HPStateP` became `NULL`. The same session showed frequent `SetHeatpump` ON/OFF commands; **the causal link was not established conclusively**.

Version 2611.07 addresses the initialization race:

- `System#Boot` initializes local rule state and schedules **only `timer=1` after ten seconds**.
- `timer=1` uses `isset()` to wait for five selected heat-pump fields (`@Heatpump_State`, `@Operating_Mode_State`, `@Outside_Temp`, `@Z1_Heat_Request_Temp`, `@Compressor_Freq`) and three OpenTherm inputs (`?roomTempSet`, `?roomTemp`, `?chEnable`).
- If any checked value is unavailable, it logs `timer=1: waiting for HP / OT values` and retries after **five seconds**. It does not start the dependent periodic timers.
- After successful initialization, it schedules timers 2–10 in their **existing order and original normal-boot cadence**. The application logic, TaShift and PI controller are unchanged.

The guard is deliberately limited to those eight values; it is not a blanket readiness test for every heat-pump register. See [2611.07 startup notes](docs/STARTUP-2611-07.md) and [CHANGELOG.md](CHANGELOG.md).

### PI correction and readability updates (2611.08–2611.10)

**2611.08 changed the actual controller behavior** (compared with 2611.07):

- `timer=9` uses `Kp = 1.2` and **`Ki = 0.05` per five-minute sample**; it is a PI controller without a derivative term.
- `#PIDintegral` now stores the **I contribution itself in degrees Celsius of heating-target correction**, not the accumulated room-temperature error. The integral is independently limited to **±5 °C**, regardless of `Ki`. The **total PI correction** is also limited to **±5 °C**.
- Conditional anti-windup avoids integrating further into total-output saturation while allowing the integral to unwind when conditions permit. The integral is retained when room heating is unavailable, during DHW or defrost interruptions and across setpoint changes. The final PI correction is rounded to whole degrees.
- The prior `Ki = 0.02` with an accumulated-error clamp of ±50 had inadvertently limited the integral contribution to ±1 °C. These independent limits correct that coupling.
- Versions **2611.08 and later require a Rules engine with more than 127 variable slots**, as well as support for `gpio(33)`. A successful Rules load was observed with 131/255 slots in the 2611.08 test; it does not guarantee compatibility with other firmware builds.

**2611.09** reintroduced descriptive local variables, including `Kp`, `Ki`, the independent PI/I limits and four weather-compensation curve parameters (`Ta1`, `Ta2`, `Tb1`, `Tb2`). These improve readability without an intended change to the underlying weather-curve formula.

**2611.10** is the agreed **style and documentation revision** of 2611.09. All 16 Rules retain their existing order, scheduling and executable control logic; changes are formatting and explanatory comments. Maintenance uses the annotated file as the single source of truth. The loadable file is generated with the [HeishaMon rules minifier](https://github.com/klaashoekstra94/heishamon_rules_minify). See [Rules coding style](docs/RULES-CODING-STYLE.md) for the formatting and documentation conventions.

### TaShift refactor and DHW-safe PI control (2611.11–2611.13)

**2611.13 established the controller structure retained through 2611.19.** Version 2611.16 makes two targeted stability changes to the target calculation (see below); it is not a behavior-preserving rename-only release. It retains the established compressor-start, defrost, outlet-temperature and Zone 2 safety behavior while reorganizing TaShift to respect the Rules engine's **255-instruction conditional-jump limit**:

- `TaShift()` checks the existing heating/DHW/defrost gate, computes the effective `$WCS` once when the compressor is running, calculates the preliminary Zone 1 target, then calls `TaShift2($WCS)`.
- `TaShift2($WCS)` handles the controlled PI handover, outlet-temperature corrections, direct Zone 2 override and final Zone 1 write. There are **17 Rules** in total (up from 16 in 2611.10). The two subrules were reported as 193 and 173 compiled instructions respectively; the conditional-jump check is a **per-jump** limit, not a maximum total ruleset size.
- The first PI step can occur after 2 minutes when compressor frequency is at or below `#CompFreqTarget`, or after 15 minutes. Subsequent steps use 10 minutes at/below the frequency target or a 15-minute escape, with at most 1 °C change per accepted step. The existing outlet and Zone 2 safeguards still apply.
- `timer=9` **holds both the integral and PI output** during DHW and while Evohome temporarily presents its 12 °C OFF setpoint. Integration resumes only when DHW is finished, the three-way valve is back in heating position and the normal setpoint has returned.
- After a Rules-managed DHW cycle finishes, `timer=5` resets `#TaPIStepTime`, `#TaDeltaTimer` and `#TaDelta` to restart the PI handover and outlet overshoot tracking cleanly.

**Development history:** 2611.11 had an oversized conditional jump (about 360 instructions) and was rejected by a firmware build checking the 255-instruction limit. Version 2611.12 used an intermediate 24-Rule split; 2611.13 replaces that with the simpler two-part structure. Neither candidate superseded the then-working 2611.13 ruleset.

The author confirmed **2611.13 and subsequently 2611.14 running on HeishaMon**; those are load/running observations, not long-term heating, cooling and DHW validation. The supplied 2611.15 files have been compared for identical executable content, but no separate 2611.15 on-device test has been reported yet. See [technical release notes](docs/TA-SHIFT-2611-13.md) and [CHANGELOG.md](CHANGELOG.md).
### Naming and PI readability (2611.14–2611.15)

Version **2611.14** applied the naming decisions from the [2611.13 variable inventory](docs/RULES-NAMING-INVENTORY-2611-13.md) to the annotated Rules only: **61 identifiers renamed** (55 accepted proposals and six author-selected alternatives); `#Time`, `#chEnable` and `#chEnableChangeTime` remain as before. Names follow the [two-letter functional-prefix convention](docs/RULES-NAMING-CONVENTION.md), including `pi`, `rt`, `wc`, `hw`, `hp`, `cp`, `ch` and other domains. The author reported 2611.14 running on HeishaMon.

Version **2611.15** publishes **both the annotated and loadable source** with the approved names and simplifies the equivalent PI expressions in `timer=9`:

- `#rtDelta` continues to mean **actual room temperature minus setpoint** for the heating and GPIO hysteresis logic. The PI error is now written directly as `$piError = #rtSetpoint - #rtTemp`, positive when the room needs more heat.
- Separate explicit I-contribution limits (`$piIMin = -5`, `$piIMax = 5`) and overall PI-output limits (`$piMin = -5`, `$piMax = 5`) replace limits calculated using `* -1`. Gains remain `$piKp = 1.2` and `$piKi = 0.05` per five-minute sample.
- The conditional anti-windup, PI hold during DHW/temporary OFF, integration guard, numeric bounds, timer scheduling and heat-pump control decisions remain unchanged.

The supplied annotated and loadable 2611.15 files have **identical executable token streams**. After mapping approved names, the control expressions outside timer 9 are identical to 2611.13; the PI rewrite is algebraically equivalent under the maintained room-delta invariant. See [CHANGELOG.md](CHANGELOG.md).

### Target stability refinements (2611.16)

Version **2611.16** was loaded on the author's HeishaMon on 2026-11-18. Subsequent field observations motivated the changes in 2611.17–2611.19. The purpose is to address two types of target oscillation observed on 2611.15:

- **A — Prevent premature 1 °C target reductions during long compressor runs:** `TaShift2` now checks the measured outlet temperature against the **proposed lower target + 0.8 °C**, instead of the **current target + 0.8 °C**. This should avoid PI immediately undoing a target increase applied by overshoot protection. The maximum 1 °C PI step, existing 10/15-minute timing and overshoot safety rules are unchanged. **Monitor whether a previously elevated target can still decrease in reasonable time**, since this condition can hold it higher for longer.
- **B — Add modest hysteresis when the compressor is stopped:** `TaShift` retains a previously active `#taShift = -5` while `#rtDelta > -0.15 °C`, instead of only while `#rtDelta > 0 °C`. This should suppress short 5 °C target increases caused by temperature rounding near the room setpoint. The existing compressor-off time/outside-temperature condition still governs whether the low shift is held.

The loadable and commented 2611.16 files have matching executable code. Other Rules and the PI formulation in `timer=9` are unchanged compared with 2611.15. On-device loading was confirmed; long-term field validation remains ongoing. See [the complete observation, rationale and follow-up test plan](docs/TARGET-STABILITY-2611-16.md) and [CHANGELOG.md](CHANGELOG.md).

### Pump command reduction and room-temperature stop filtering (2611.17–2611.19)

**2611.17** staggers the first `timer=6` pump update from 40 to **47 seconds** after startup initialization (its 60-second recurrence is unchanged). During normal space heating, with defrost inactive and `@Pump_Flow >= 8`, `$puLimitCheck` suppresses a `SetMaxPumpDuty` command unless the **actual** `@Pump_Duty` reaches the lower of the current and computed maximum duty. This avoids cycling a limit that the Panasonic is not using. The original DHW, defrost, cooling, compressor-idle and low-flow behavior is preserved. This reduces unnecessary pump commands; it is not proof that earlier closely spaced commands caused unacknowledged temperature requests.

**2611.18** adds `#rtHighStartTime` and requires the room delta to remain above the upper threshold for **10 minutes** before the ordinary overtemperature OFF branch in `timer=4` can run (only from 10:00 onward and still subject to its existing compressor, outside-temperature and restart guards). `timer=8` records the start minute and resets it whenever the delta returns to or below the threshold. Existing independent triggers at `#rtDelta > 1.5` and sustained `#chEnable == 0` are unchanged.

**2611.19** centralizes the five common room-temperature upper-bound comparisons into `#rtUpperThreshold = 0.21 °C` (previously individual literal `0.2` comparisons): the overshoot timer, restart permission, compressor-off TaShift, GPIO33/Dim demand hysteresis and PI-integrator eligibility. The distinct comparison operators (`<`, `<=`, `>`) remain unchanged. The chosen value is slightly above the observed quantized `+0.203125 °C` reading.

The author reports **2611.19 running on HeishaMon**. Its longer-term compressor cycling, room comfort, DHW/defrost and target-write acknowledgement still require field observation; see the single combined [changelog entry](CHANGELOG.md).

## OpenTherm room values

The room setpoint and current room temperature are transported as their normal OpenTherm values instead of encoding room temperature in `maxRelativeModulation`.

- `?roomTempSet` is the room setpoint (OpenTherm Data-ID 16). In this setup Home Assistant writes the living-room target temperature to the OTGW with `BS=<temperature>`. The rules limit the resulting setpoint to 10–22 °C.
- `?roomTemp` is the current room temperature (OpenTherm Data-ID 24). Home Assistant writes the living-room current temperature to the OTGW with `RT=<temperature>`. The `RT=` command requires OTGW firmware 6.7 or newer.
- If the thermostat does not itself provide Data-ID 24, the OTGW can be configured to provide it as an alternative Data-ID (`AA=24`).
- `?chEnable` is the Evohome heating-demand signal in **normal mode** (GPIO33 != 1); short off periods are filtered by the rules with a delay greater than 15 minutes. In **Dim mode** (GPIO33 == 1), internal demand is determined from room-temperature hysteresis instead.

The old use of `?maxRelativeModulation` as an encoded room-temperature transport is no longer used.

### Filtering the room temperature upstream

In this installation the Evohome/ramses room-temperature value occasionally shows short, non-physical spikes or dips. Because `?roomTemp` is used directly by TaShift and the thermostat logic, such glitches can otherwise cause a short target-temperature jump.

Home Assistant therefore filters the raw living-room temperature before sending it to the OTGW with `RT=`. The current setup uses a Home Assistant `filter` sensor with a `lowpass` filter, `time_constant: 15` and `precision: 2`, and the OTGW automation rounds the filtered result to 0.1 °C before sending it. This filtering is installation-specific and is not part of the HeishaMon rules themselves.

## Firmware requirements (GPIO33 and Rules variables)

**Important:** this ruleset uses `gpio(33)` in timer 8 **and requires more than 127 Rules variable slots as of 2611.08**. Conditional jumps must also fit the Rules bytecode's 255-instruction offset; use firmware that detects and rejects oversized conditional jumps rather than silently accepting a corrupted control path. Verify both features in the firmware actually installed; the version label alone is insufficient. The 2611.08 load log showed 131/255 slots on a suitable build. Confirm GPIO support before using HEMS Dim mode.

**Earlier compatible custom firmware release (historical reference):** [HeishaMon Large – GPIO + synchronous webserver (`blb4-gpio-webserver-1.0.0`)](https://github.com/blb4github/HeishaMon/releases/tag/blb4-gpio-webserver-1.0.0). This is an author's pre-release build with extended GPIO support, built from commit [`20df324`](https://github.com/blb4github/HeishaMon/commit/20df32456cdb5a189d614e9424b73c099a19f5dd) and published with the firmware artifact `Heishamon-firmware-Alpha-20df324.zip`. It provides the GPIO functionality needed for the Rules 2610.08 and later HEMS Dim feature. It also contains experimental improvements to the synchronous webserver; it is **not an official upstream HeishaMon release**.

The firmware source is in the [blb4github/HeishaMon fork](https://github.com/blb4github/HeishaMon). The linked pre-release documents an earlier known GPIO-capable build, **not** the firmware now running in the author's installation. When using that earlier release, download its specific firmware attachment; for firmware 4.4.0, verify GPIO support and compatibility with your hardware before flashing.

Firmware without the required Rules GPIO support may fail to parse or evaluate `gpio(33)`; do not assume that a normal build will silently ignore Dim mode. The other parts of this ruleset also depend on the HeishaMon 4.x Rules and OpenTherm functions mentioned above.

## HEMS Dim mode on GPIO33 (2610.08)

Timer 8 uses `gpio(33)` to select how the internal `#chEnable` heating-demand state is determined:

- **GPIO33 is exactly 1 — HEMS Dim mode.** Evohome `?chEnable` is ignored for this demand calculation. Instead the room-temperature difference `#rtDelta = #rtTemp - #rtSetpoint` controls `#chEnable` with hysteresis: heating demand becomes **1 below the room setpoint** (delta < 0 °C), becomes **0 above the room setpoint by more than 0.2 °C** (delta > +0.2 °C), and **retains its previous state** between those thresholds. The normal Evohome off-delay is cleared in Dim mode.
- **GPIO33 is anything other than 1 — normal Evohome mode.** Heating demand follows `?chEnable`; transient Evohome off signals are filtered, requiring an off period of more than 15 minutes before clearing an active `#chEnable`.

Whenever `#chEnable` changes, timer 8 updates `#chEnableChangeTime`; the normal elapsed-time bookkeeping is retained. **This does not directly switch the heat pump on or off**: timer 4 still applies room-temperature, outside-temperature, compressor-runtime, overnight and other conditions before changing the required heat-pump state. In particular, turning on Dim mode is not an unconditional or immediate heat-pump stop.

The 2610.08 Dim behaviour supersedes the simpler GPIO33 heat-demand block from 2610.05/2610.06.

## Startup protection (2610.07 and 2611.07)

The `on @Main_Outlet_Temp` handler now calls `TaShift()` only when `isset(#Time)` is true. Timer 1 initialises `#Time` and adopts the current heat-pump state, including `#cpState = 2` if the compressor is already running at startup. This prevents the outlet-temperature event from calling TaShift before timer 1 has initialised the rules' state.

This is **an initialisation-order guard**, not a three-minute ban on lowering the heating target. As of 2611.07, `timer=1` also gates the startup of periodic timers 2–10 on eight checked input values. Event-driven Rules, including the `@Compressor_Freq` handler, are not themselves delayed by this timer gate; boot logs should still be reviewed after firmware upgrades.

## Other integration values to check

- `?dhwEnable` enables the rules' DHW control.
- `?CoolingEnable` enables cooling and is smoothed by the rules. Home Assistant supplies `?coolingControl` from its dew-point calculation; the rules apply further water-temperature limits. Configure this external calculation for your installation.
- `@Z2_Heat_Request_Temp` provides a heating-target override: 15–25 corresponds to a −5 to +5 °C shift around 20; values above 25 request a direct temperature.
- `@Buffer_Tank_Delta` below 4 overrides Quiet Mode.
- Review the DHW settings (including `#DHWComfortDay` and `#DHWSterilizationDay`), weather-curve settings, fixed upper curve temperature (36 °C), GPIO33 wiring/mode and pump settings before use.

## Loading and editing

1. Save a copy of your existing rules and check the settings and integration above.
2. Load the contents of `HeishaMon_Rules_BlB4.lua` into the HeishaMon rules editor, without Markdown fences.
3. Check the boot log for `BLB Heishamon_rules_2611.16.lua`. If some inputs are not ready, look for `timer=1: waiting for HP / OT values` and confirm the periodic timers start once initialization succeeds. Check the Rules engine supports more than 127 variable slots and `gpio(33)`.
4. Verify that `#OutsideTemp` and `#HPStateP` are numeric, `?roomTempSet` and `?roomTemp` contain the intended values, and unwanted repeated `@SetHeatpump` commands do not occur.
5. Monitor real operation, including heat-pump starts, compressor frequency, target temperature and defrosts. A successful load does not by itself validate physical control behavior.

For edits, work **only** in `HeishaMon_Rules_BlB4_commented.lua`, then generate `HeishaMon_Rules_BlB4.lua` using the [HeishaMon rules minifier](https://github.com/klaashoekstra94/heishamon_rules_minify). Do not maintain the two files independently. Confirm executable equivalence after minification and review the [coding style](docs/RULES-CODING-STYLE.md).

> Usage is at your own risk. These are personal control rules, including installation-specific heating, cooling and hot-water settings.

Thanks to [HeishaMon](https://github.com/Egyras/HeishaMon), [@CurlyMoo](https://github.com/CurlyMoo) for the rules functionality and [@fbloemhof](https://github.com/fbloemhof) for the documentation inspiration.

Licensed under the [MIT License](LICENSE).
