# TaShift 2611.02 — design review (draft)

## Problem observed (2026-11-12)
The long compressor run at ~19-20 Hz kept outlet near 28-31C while the living room remained below its target. The former TaShift computed positive room `#SHifT` but subsequently limited `#Z1HRT` to `max($WCS-5,ceil(outlet)-1)`, effectively making outlet-temperature tracking an **upper** bound on a room-controlled heating target. The `#TaDeltaTimer` and `#TaDelta` rescue branches could also overwrite a positive PI request with a smaller shift.

## Control contract
- Normal heating (compressor running, outside startup exception): target = effective weather baseline + max(room PI request, compressor-stop protection floor), clipped to +/-5C total shift. In symbols, `WCS + clamp(max(RoomTempControl, ceil(outlet-1.9-WCS)), -5, +5)`.
- A target correction demanded by room PI is authoritative unless the pre-existing **startup** exception applies or the explicit Z2 override is active.
- `#TaDelta` and its timer may only increase the target to reduce outlet overshoot; they cannot lower the PI-requested target.
- The 130s startup exception for `#OutsideTemp>7`, idle hysteresis, -5C suppression when demand is absent/room warm, and Z2 override remain.
- No new timer, ramp, gain or damping mechanism.

## Counterfactual against historical observations
The new PI from 2611.01 was replayed against the historic 12-Nov room temperatures; historical outlet values were kept fixed. In normal compressor-running branches, ignoring physical feedback:

| Local time | #WCS | PI | Historical target | Proposed target |
|---|---:|---:|---:|---:|
| 08:02 | 31 | +2 | 30 | 33 |
| 09:02 | 31 | +2 | 28 | 33 |
| 11:02 | 30 | +2 | 28 | 32 |
| 13:32 | 30 | +2 | 30 | 32 |
| 15:02 | 30 | +2 | 30 | 32 |

The new targets would influence the compressor and outlet: **these are not predicted real outcomes**. The first compressor run may change substantially; that is a key test risk.

## Intended scenario checks
- Compressor running, room cold, at minimum frequency: no downward target chasing below `WCS+PI`; PI remains effective.
- Outlet approaching >2C over target: maintain or raise target only as required for compressor continuity.
- Compressor at 19-20 Hz, PI decreases: target can follow PI down; old low-frequency hold is removed.
- Above 7C in first 130 seconds: existing soft-start logic still overrides PI.
- Off, room cold, `#chEnable=1`, pre-07:00: allow PI after existing off-cycle conditions.
- Off, room warm or no heat demand at night: preserve -5C suppression.
- DHW and defrost: do not alter existing TaShift eligibility; timer 9 holds integral.
- If `@Z2_Heat_Request_Temp>25`, explicit override still wins.

## Deployment caution
The previous always-on upper cap also reduced heat output during sustained operation. Removing it increases actual heating targets, especially before ~10:42 on 12 Nov when #WCS was 31C. Measure target, outlet, compressor Hz, cycling and living-room error after enabling. Do not infer that 32-33C always produces better overall COP; compare heat delivered and runtime.
