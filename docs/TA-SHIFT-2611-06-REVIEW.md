# TaShift 2611.06 — variable-capacity correction (historical review)

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

## Validation and status update (2026-11-15)

- Static inspection confirmed the documented and ready-to-load code agree and timer 9 PI is preserved.
- The author subsequently **loaded 2611.06 successfully on HeishaMon**, confirmed that the house was heating, and merged [PR #9](https://github.com/blb4github/HeishaMon-Rules-with-Opentherm-Thermostat/pull/9). This supersedes the provisional "not loaded" status from the original review.
- The exact on-device variable-slot count and complete seasonal/defrost performance were not independently verified.
- **2611.07** was then supplied to guard the early boot initialization under firmware 4.4.0. That subsequent version does not alter TaShift/PI; see [startup notes](STARTUP-2611-07.md).
