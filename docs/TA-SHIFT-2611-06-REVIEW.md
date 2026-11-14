# TaShift 2611.06 — variable-capacity correction (draft)

## Diagnosed loading failure, 2026-11-15 00:04:23

HeishaMon rejected the 2611.05 candidate with:
`ERROR: maximum number of 127 variables reached`
`Failed to load new rules, reverting back to older rules!`

The logging shows 2611.01 loaded with 126/127 variable slots; 2611.05 reached 127/127 while compiling rule #13, before the remaining three rules. This is the Rules variable-table limit, not the 32 KB bytecode memory allocation.

## Revised 2611.06

- Preserve original TaShift of 2610.08 and the untouched PI controller of 2611.01.
- Keep just ONE new persistent Rules global: `#TaPIStepTime`.
  - `-1`: normal startup or restart after compressor off or defrost.
  - `>=0`: PI transfer phase, timestamp of last accepted 1-degree step.
- Remove previous `#TaPIPhase` and the new temporary variables `$StepElapsed`, `$PIWanted`, `$OriginalSoftStart` and `$SafeTarget`; calculate these conditions directly.
- Remove legacy `#Debug = 1` initialization because `#Debug` was not referenced anywhere else in the executable Rules.
- Remove unused `$t3Timer` by selecting `setTimer(3,15)` or `setTimer(3,60)` directly; preserves the same cadence.
- Continue to release EACH 1 C target step only when compressor frequency is at/below `#CompFreqTarget` after at least two minute ticks, OR after the step's own 15-minute timeout.
- Keep the first 130 seconds of the original above-7-C startup, defrost/flow gate, existing outlet safeguards and Zone 2 request override.
- Preserve the original PI `timer=9` byte-for-byte.
- Uses existing `#Time` (minute-of-week); `%time` is not required.
- During boot with compressor already running, set `#TaPIStepTime = #Time` to avoid starting a low-temperature startup from a Rules reload.

## Validation

Static inspection confirms the annotated and executable Rules match and PI is unchanged. The expected number of Rules variable slots is approximately 126/127 based on the previous firmware log. **This version has NOT yet been compiled or loaded by the actual HeishaMon Rules engine**. Re-check load log, `varstack slots` and compressor/target behavior before accepting. Do not merge without user approval.
