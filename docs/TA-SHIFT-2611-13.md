# Rules 2611.13 — TaShift split, PI handover and DHW behavior

Date: **2026-11-16**. Status: **author confirmed load and execution on HeishaMon**; extended operating validation has not been supplied.

## Reason for the refactor

HeishaMon Rules conditional branches use a jump offset limited to **255 compiled instructions**. This limit is distinct from the **Rules variable table** (127 slots on earlier builds, extended to 255 slots on the tested build). Version 2611.11 placed roughly 360 compiled instructions in the enlarged TaShift block. Firmware with the new jump-range check rejected it and preserved the previously loaded Rules. The 2611.12 trial used a supervisory Rule plus eight helpers (24 Rules); while it avoided the large branch, it was less readable.

Version **2611.13** reduces TaShift to two functions and has **17 Rules** overall. The preceding compiler review reported `TaShift` at approximately 193 and `TaShift2` at approximately 173 compiled instructions. Counts describe Rule bodies; the relevant restriction is the **size of each conditional jump**, not a per-Rule or total-program instruction count.

## Current control flow

1. `@Main_Outlet_Temp` (only when `#Time` is initialized) or `timer=3` calls `TaShift()`.
2. `TaShift` resets `#TaPIStepTime` when defrost begins and evaluates the established gate: `#Heat == 1 && @ThreeWay_Valve_State == 0 && #DHWRun < 2 && #NoDefrost == 1`.
3. With the compressor running, `$WCS = #WCS + min(max(@Z2_Heat_Request_Temp - 20, -5), 5)` is calculated **once**. Target shifts, compressor-start conditions and outlet-temperature overshoot protection are handled before the call.
4. `#Z1HRT` is prepared from `coalesce($WCS, #WCS) + #SHifT`, clamped to the established range/temperature constraints; with the compressor off, `$WCS` is unset and `#WCS` is used.
5. `TaShift2($WCS)` applies the PI handover when allowed, restores outlet-temperature safeguards, honors the direct Zone 2 override when `@Z2_Heat_Request_Temp > 25`, then issues `@SetZ1HeatRequestTemperature` only if the target changed.

### PI step timing

| Phase | Frequency at/below `#CompFreqTarget` | Timeout / escape |
| --- | --- | --- |
| First accepted handover step (`#TaPIStepTime < 0`) | At least **2 min** compressor runtime | At least **15 min** compressor runtime |
| Later accepted steps (`#TaPIStepTime >= 0`) | At least **10 min** since the last accepted step | At least **15 min** since the last accepted step |

The conditions also require the original startup/outside-temperature guard (`#OutsideTemp <= 7`, or `#CompRunSec >= 130`, or sentinel `#CompRunSec == -1`). Each accepted PI step is limited to **1 °C** toward `$WCS + #RoomTempControl`; outlet-temperature safeguards and the direct Zone 2 override can act separately.

## DHW and temporary OpenTherm setpoint

- `timer=9` calculates PI only when `#DHWRun < 1`, the three-way valve is in heating position, and both `?roomTempSet > 12` and `#RoomSetpoint > 12`. Otherwise the existing **integral and PI output are held**, avoiding disturbance from Evohome's temporary 12 °C OFF setpoint during DHW.
- On successful completion of a Rules-managed DHW cycle, `timer=5` restores the previous operating request and resets `#TaPIStepTime = -1`, `#TaDeltaTimer = 0` and `#TaDelta = 0` to begin a fresh PI handover and overshoot evaluation.
- The original `TaShift` DHW gate is retained; supplementary temporary DHW guards added in 2611.12 are **not** part of 2611.13.

## Source/firmware consistency

- Canonical source: [`HeishaMon_Rules_BlB4_commented.lua`](../HeishaMon_Rules_BlB4_commented.lua). Loadable file: [`HeishaMon_Rules_BlB4.lua`](../HeishaMon_Rules_BlB4.lua).
- Both published files derive from the author's 2611.13 uploads. The **only normalization** of the annotated upload is changing the startup waiting diagnostic from `HP/OT` to `HP / OT`, matching the unchanged tested loadable upload.
- Executable token comparison was performed after this normalization; the files match. This verifies source/loadable consistency, **not** runtime safety.
- Firmware must support more than 127 Rules variable slots, `gpio(33)`, Rule arguments such as `TaShift2($WCS)`, and normal HeishaMon/OpenTherm Rules functionality. Use a build that rejects conditional jumps beyond 255 instructions.

## Further operational checks

Review a complete room-heating/DHW/room-heating cycle: ensure timer 9 holds both PI states during the 12 °C phase, the previous values are restored only after normal room setpoint returns, and the PI handover restarts without large target changes. Watch the 10/15-minute PI step timing, compressor startups, defrost events, Zone 2 overrides, HeishaMon Rules log and load/memory reports. These checks are **recommended** and are not claimed completed by this repository update.
