# Rules 2611.16 — target stability during heating

**Date:** 2026-11-18  
**Basis:** 2611.15  
**Status:** Author reports 2611.16 loaded on HeishaMon. Field behavior **not yet evaluated**; evaluate the next heating day against the 2026-11-18 baseline.

## Observations prompting the change

Two separate target oscillations were observed on 2026-11-18 while running Rules 2611.15:

1. **A — Reversed target steps during a sustained compressor run.** An outlet-temperature overshoot correction briefly raised the heating target; after the PI step wait elapsed, PI lowered it by 1 °C, and the overshoot protection soon raised it again. Representative sequences were near 08:13 and 11:14. The earlier down-step condition compared outlet temperature with the **old** target plus 0.8 °C, not with the proposed lower target.
2. **B — Short 5 °C target increases while the compressor was stopped.** Around `#rtDelta = 0`, the compressor-off TaShift branch could switch `#taShift` between `-5` and `0`, yielding e.g. 25 → 30 → 25 °C target pulses. Some were followed by very short compressor operation (roughly around midday and after 17:00); the Panasonic's own compressor-stop reason is not established.

These explanations are based on the 2611.15 Rules conditions and the day's HeishaMon log; they motivate the intervention but do **not** yet demonstrate its effectiveness.

## A — Guard a PI-requested downward step against the proposed target

**Location:** `TaShift2($wcAdjusted)`, PI step calculation. The 10/15-minute timing criteria, the maximum 1 °C accepted PI step and the independent overshoot safety paths are unchanged.

Former condition:

```text
elseif $wcAdjusted + #piCorrection < @Z1_Heat_Request_Temp && @Main_Outlet_Temp <= @Z1_Heat_Request_Temp + 0.8 then
    #taZ1ReqTemp = max(@Z1_Heat_Request_Temp - 1, $wcAdjusted + #piCorrection);
```

2611.16:

```text
elseif $wcAdjusted + #piCorrection < @Z1_Heat_Request_Temp then
    #taZ1ReqTemp = max(@Z1_Heat_Request_Temp - 1, $wcAdjusted + #piCorrection);
    if @Main_Outlet_Temp > #taZ1ReqTemp + 0.8 then
        #taZ1ReqTemp = @Z1_Heat_Request_Temp;
    end
```

**Purpose:** do not apply a 1 °C target reduction if the actual outlet temperature would already be more than 0.8 °C above the **new** target. This avoids an immediate conflict with outlet overshoot protection. If the step is rejected, the existing `#piStepTime` update test only refreshes its timestamp on PI initialization or a changed target; the controller can retry as conditions change.

**Trade-off / risk to watch:** the new criterion may be strict when the heat pump holds outlet temperature near the **current** target. A target previously raised by overshoot protection could be held elevated longer than desired. This is a behavior change requiring live observation, not a proven improvement yet.

## B — Preserve the low compressor-off target across a small temperature deviation

**Location:** `TaShift()`, compressor-off branch.

Former hysteresis subcondition:

```text
(#rtDelta > 0 && #taShift == -5)
```

2611.16 subcondition:

```text
(#rtDelta > -0.15 && #taShift == -5)
```

**Purpose:** retain `#taShift = -5` when it is already active at `#rtDelta = 0.0` or approximately `-0.1 °C`, instead of jumping back to neutral as the room measurement fluctuates near the setpoint. It releases near `-0.2 °C` with the usual 0.1 °C room readings.

**Scope:** this remains part of the existing compressor-off expression:

```text
#cpRunMin > (-2 * #hpOutsideTemp - 30)
```

The time/outside-temperature dependent reheat path is therefore retained. No new timer or state variable was added. `#taShift` also serves heating-running logic; this is a small, targeted hysteresis, not a dedicated independent state machine.

## Scope and checks

- User-provided loadable `2611.16_rc` and annotated `2611.16` inputs have identical executable token streams.
- Against the PR #16 version of 2611.15, executable changes are confined to the compressor-off branch of `TaShift` and the PI-down-step branch of `TaShift2`, plus the boot version string.
- All other Rules, scheduling intervals, pump logic, DHW management, cooling behavior, output commands and PI calculation (`timer=9`) are unchanged.
- The annotated header was corrected to `2611.16`; two explanatory comments were added. The loadable file is otherwise the author-provided upload (with a final newline).

## Next field review

Compare the next day's graphs and HeishaMon log against the 2026-11-18 reference:

1. During long compressor runs, check whether a target raised by the overshoot guard still falls 1 °C and rebounds shortly thereafter, and whether any elevated target persists for too long.
2. At compressor-off periods, check for 5 °C target pulses near `#rtDelta = 0` and for short compressor starts. Record room delta, `#taShift`, target, outlet temperature and compressor state.
3. Check that normal reopening of heating on a cold room or after the elapsed-time condition is still possible, and that intended PI target reductions eventually occur.

**Validation status:** On-device loading reported by author; no conclusion on A/B effectiveness yet.
