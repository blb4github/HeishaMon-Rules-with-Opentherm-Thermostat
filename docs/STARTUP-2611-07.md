# Rules 2611.07 — guarded startup initialization

Date: 2026-11-15

## Background

A HeishaMon 4.4.0 firmware-startup log showed that timer 1 could run shortly before the first valid heat-pump data packet had been processed. In that case the previous Rules initialized `#OutsideTemp` and `#HPStateP` to `NULL`. Later updates such as `#OutsideTemp = (#OutsideTemp * 59 + @Outside_Temp) / 60` may not recover from this missing initial value. The same session showed repeated ON/OFF commands to `@SetHeatpump` approximately one minute apart.

The early initialization is established by the log. **It is not yet proven to be the sole cause of the ON/OFF sequence.**

## Exact change supplied by the author

- `System#Boot` still initializes the original Rules global state, but starts only `setTimer(1,10)`.
- `timer=1` checks eight inputs with `isset()`:
  - Heat pump: `@Heatpump_State`, `@Operating_Mode_State`, `@Outside_Temp`, `@Z1_Heat_Request_Temp`, `@Compressor_Freq`
  - OpenTherm: `?roomTempSet`, `?roomTemp`, `?chEnable`
- If a checked value is unavailable, timer 1 logs a waiting message and reschedules itself after five seconds, without running the state-adoption block.
- When ready, timer 1 adopts the existing heat-pump status, room values and time reference, and only then starts timers 2–10.
- The author deliberately retains the previous normal-case initial scheduling order and offsets. Relative to successful timer 1 execution: t2=10 s, t3=25 s, t4=30 s, t5=35 s, t6=40 s, t7=45 s, t8=50 s, t9=55 s, t10=22 s.
- `@ThreeWay_Valve_State` and `@DHW_Temp` are still consumed by timer 1 but are **not separately included in the author's readiness test**, on the assumption that the heat-pump values arrive as one set.
- `on @Main_Outlet_Temp` retains its existing `isset(#Time)` guard; other event handlers such as `on @Compressor_Freq` are unaffected by the timer gate.
- No TaShift, PI, Quiet Mode, OpenTherm demand-selection, DHW or pump-control logic changes.

## Repository files

- `HeishaMon_Rules_BlB4_commented.lua`: exact authored annotated source
- `HeishaMon_Rules_BlB4.lua`: exact authored ready-to-load source

The two uploaded files have equivalent executable logic after comments and layout are removed. The wait diagnostic differs only in formatting (`HP/OT` vs `HP / OT`).

## Suggested on-device checks

1. Confirm the boot print identifies `Heishamon_rules_2611.07.lua`.
2. If a startup retry occurs, check for the waiting log message and for successful eventual execution of timer 1.
3. Check that `#OutsideTemp` and `#HPStateP` become numeric and that the expected periodic timers are scheduled.
4. Observe `#HPStateR`, `@Heatpump_State`, `#chEnable`, `#RoomTempDelta` and `@SetHeatpump` to determine whether the previously observed minute-wise ON/OFF commands are absent.
5. Validate the compressor startup, outlet-temperature target, defrost handling and normal heating comfort over multiple real operating cycles.

These are verification steps, **not claims that the change has already been proven to eliminate the ON/OFF sequence**.

## Rules variable capacity

This version introduces no new persistent Rules globals beyond 2611.06 and retains the earlier work to fit under the 127-variable slot limit. The actual on-device count should be checked after loading.
