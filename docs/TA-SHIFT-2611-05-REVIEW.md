# TaShift 2611.05 — draft design and field-test protocol
Date: 2026-11-14

## Goal
Combine the unchanged PI controller of 2611.01 with the quiet startup behaviour of
2610.08 and an empirically controlled handover to the WAR+PI requested outlet
temperature. Never merge or deploy this candidate without checking it.

## Implementation
- Start with the exact original TaShift from release 2610.08, including its
  compressor-off target behaviour, low-frequency hold, Z2 override, defrost/flow
  exception, 130-second warm-outside soft start, and #TaDelta protections.
- Keep the PI in timer=9 from release 2611.01 literally unchanged.
- New #TaPIPhase: 0 for legacy startup/defrost, 1 for controlled transfer.
- On compressor start/stop and whenever TaShift observes defrost active,
  restore phase 0. On Rules reload during an already running compressor, start
  in phase 1 to avoid suddenly applying the old low-start target mid-run.
- Phase 0 release criterion: @Compressor_Freq <= #CompFreqTarget after at least
  two #CompRunMin minutes, OR #CompRunMin >= 15. Above 7 C ambient, retain
  the original first-130-second startup handling.
- On phase 1, the PI demand is $WCS + #RoomTempControl; the actual zone-1 request
  is advanced one degree per approved step, in either direction.
- Subsequent approvals use the same frequency criterion plus a minimum of
  two minute-counter ticks since the last step, OR 15 minutes after that step.
  A safety-motivated target correction also restarts the step timer.
- Do not step DOWN if the resulting outlet overshoot would exceed 1.8 C.
  Old #TaDelta >= 3 or #TaDeltaTimer >= 80 protections are allowed to step
  target UP once independently of frequency/timeout, max 1 C per write.
- Preserve original Zone 2 direct temperature override >25 C (this bypasses
  the PI step mechanism as it did in 2610.08).

## Timekeeping
This candidate deliberately does NOT require the custom %time firmware token.
#Time is updated once per minute, modulo 10080 minutes per week. Two
minute-counter ticks imply roughly 60-120 seconds after a step, avoiding
immediate repeated steps at the next poll. The 15-minute escape is approximate
to minute precision. A later separate experiment may switch only TaShift step
timestamps to the seconds-valued %time for tighter response timing.

## Review points
1. A morning compressor start should reproduce the lower, quiet 2610.08 target
   and not immediately request full WAR+PI.
2. Below #CompFreqTarget, permit exactly one +1 C step, then wait for a
   fresh observation after at least two minute-counter ticks.
3. Above #CompFreqTarget, allow the next +1 C step only after 15 minutes.
   Repeat the 15-minute escape separately after EACH step, not just the first.
4. Prevent a one-degree downward step when the resulting target would leave
   >1.8 C outlet overshoot.
5. During defrost, keep the original flow-dependent TaShift actions and
   the old outlet cap. Resume in phase 0 after defrost.
6. Verify DHW/sterilization, startup above 7 C, Z2 direct override,
   Rules reload while running, and weekly #Time rollover.
7. Confirm HeishaMon Rules parser accepts the candidate and monitor compressor
   Hz, outlet, target, defrost/flow, #TaPIPhase and #TaPIStepTime.
8. Always use the normal polling interval (5 seconds, not 250 seconds).

## Limitations
No physical heat-pump validation or firmware parser execution was performed.
The compressor response to the target changes is empirical. Target changes made
by the legacy startup, Z2 override or safety correction can differ from the
strict 1 C per approved PI step scheme. A timeout is a fallback, not proof
that the heat pump has settled.
