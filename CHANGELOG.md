# Changelog

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

