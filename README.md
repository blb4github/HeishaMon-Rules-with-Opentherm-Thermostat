# HeishaMon rules with an OpenTherm thermostat

These are the rules I use to control a Panasonic heat pump with an OpenTherm thermostat. They are tailored to my installation; use them as inspiration and adapt the settings and integration to your own system.

## Current version: 2610.01

See [CHANGELOG.md](CHANGELOG.md) for the changes in each published version; the latest release is compared with 2609.02.

| File | Purpose |
| --- | --- |
| [HeishaMon_Rules_BlB4.lua](HeishaMon_Rules_BlB4.lua) | Ready-to-load rules without comments |
| [HeishaMon_Rules_BlB4_commented.lua](HeishaMon_Rules_BlB4_commented.lua) | Readable source with explanations; minify before loading |

The `.lua` extension is a filename convention: these files use the **HeishaMon rules language**, including `on ... then`, `@`, `#`, `$` and `?` variables. They are not standard Lua programs.

## My setup

- Panasonic WH-MDC07J3E5 for heating, cooling and domestic hot water with an external tank; radiators and convectors.
- HeishaMon Large. The supplied source identifies firmware builds `Alpha-f7ae839/Alpha-d8af83f` in the 4.0 development series. Use firmware that supports this ruleset's size, OpenTherm integration and `coalesce()` function; compatibility with other builds has not been verified here.
- CZ-TAW1 connected to the proxy port; I do not use it actively.
- Honeywell Evohome with an R8810 OpenTherm bridge, connected through an OpenTherm Gateway.
- Home Assistant with Evohome and OpenTherm Gateway integrations to supply the values that Evohome does not communicate reliably to the boiler.
- Heat-pump settings: `Heating_Mode: 1` (direct), `Cooling_Mode: 1` (direct), `Buffer_Installed: 0`, `DHW_Installed: 1`, `Pump_Flowrate_Mode: 0`, `Optional_PCB: 0`, `Z1_Sensor_Settings: 0`.

## What the rules do

1. Adjust maximum pump duty for heating, cooling, DHW and idle operation.
2. Set Quiet Mode based on compressor frequency, runtime, outside temperature, time of day and operating mode; allow an override through the buffer-tank delta setting.
3. Schedule DHW and sterilisation runs, with additional tank-temperature triggers and restoration of the previous operating mode/state.
4. Synchronise heat-pump temperatures and operating status with OpenTherm.
5. Control heating demand using filtered `chEnable`, room-temperature difference, outside temperature and runtime conditions.
6. Calculate weather compensation and use TaShift with room-temperature PID correction to adjust the heating target and support longer compressor runs.
7. Control cooling using Home Assistant/OpenTherm enable and water-temperature requests.
8. Handle the weekly clock rollover in compressor and thermostat elapsed-time calculations.

## Integration values to check

- `?roomTempSet` supplies the room setpoint, limited by these rules to 10–22 °C.
- `?maxRelativeModulation` is repurposed to communicate room temperature: `RoomTemp = 15 + maxRelativeModulation / 10`. A value of 100 uses the room setpoint as fallback; a decoded temperature of 15 °C blocks a new heating-demand activation.
- `?chEnable` supplies heating demand; short off periods are filtered with a delay greater than 15 minutes.
- `?dhwEnable` enables the rules' DHW control.
- `?CoolingEnable` enables cooling and is smoothed by the rules. Home Assistant supplies `?coolingControl` from its dew-point calculation; the rules apply further water-temperature limits. Configure this external calculation for your installation.
- `@Z2_Heat_Request_Temp` provides a heating-target override: 15–25 corresponds to a −5 to +5 °C shift around 20; values above 25 request a direct temperature.
- `@Buffer_Tank_Delta` below 4 overrides Quiet Mode.
- Review the DHW settings, hardcoded comfort-day condition (`%day == 4`), `#DHWSterilizationDay`, weather-curve settings, hardcoded upper curve temperature (36 °C) and pump settings before use. The `#DHWComfortDay` variable is initialised but the trigger currently uses the hardcoded day.

## Loading and editing

1. Save a copy of your existing rules and check the settings and integration above.
2. Load the contents of `HeishaMon_Rules_BlB4.lua` into the HeishaMon rules editor, without Markdown fences.
3. Check the boot log for `BLB Heishamon_rules_2610.01.lua` and monitor operation in your installation.

Timer 1 adopts the current heat-pump operating mode as `#OMR` 10 seconds after boot. Timer 8 then enforces that requested mode every 30 seconds. This release prevents DHW start re-entry but does not automatically repair a DHW-only mode adopted during initialisation. To recover, stop rules execution, select the intended mode (for example HEAT), then restart the rules and check the log.

For edits, work in `HeishaMon_Rules_BlB4_commented.lua`, then generate the ready-to-load file using the [HeishaMon rules minifier](https://github.com/klaashoekstra94/heishamon_rules_minify). Keep both files in sync.

> Usage is at your own risk. These are personal control rules, including installation-specific heating, cooling and hot-water settings.

Thanks to [HeishaMon](https://github.com/Egyras/HeishaMon), [@CurlyMoo](https://github.com/CurlyMoo) for the rules functionality and [@fbloemhof](https://github.com/fbloemhof) for the documentation inspiration.

Licensed under the [MIT License](LICENSE).

