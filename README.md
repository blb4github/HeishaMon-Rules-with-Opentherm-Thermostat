<header>

<!--
  <<< Author notes: Course header >>>
  Include a 1280×640 image, course title in sentence case, and a concise description in emphasis.
  In your repository settings: enable template repository, add your 1280×640 social image, auto delete head branches.
  Add your open source license, GitHub uses MIT license.
-->

# Welcome to HeishaMon-Rules-with-Opentherm-Thermostat



The purpose of this site is to publish the rules I use on my HeishaMon to control my Panasonic Heat Pump in combination with an Opentherm thermostat. I try to keep it as univeral as possible but it is at the end taylored to my situation and needs. You can just copy it and start using it (at your own risk) or, better, you can use is as inspiration for your own rules set.

My setup:

a) Panasonic WH-MDC07J3E5 Heat Pump used for heating, Cooling and DHW (external tank);

b) HeishaMon Large with CZ-TAW1 on proxy port (required for warranty, I don't use this CZ-TAW1 actively);

c) Honeywell Evohome Opentherm Thermostat (R8810 bridge) connected via OpenTherm Gateway;

d) Honeywell Evohome & OpenTherm Gateway integration in Home Assistant to communicate several parameters  to HeishaMon like RoomTemperatureDelta as chSetpoint from Evohome is not reliable, target room temperature and current room temperature are not communicated towards 'boiler';

e) Settings Heat Pump: Operating_Mode_State: 0, Heating_Mode: 1, Cooling_Mode: 1, Buffer_Installed: 0, DHW_Installed: 1, Pump_Flowrate_Mode: 0, Optional_PCB: 0, Z1_Sensor_Settings: 0

f) Central heating system build out of radiators and convectors.


</header>

<!--

-->

## My Requirements for the Rules Set:

1) Max Pump Speed based on HP status 1) DHW, 2) HEAT/COOL (and the outside temp as well), IDLE flow;
2) QuiteMode based on time (e.g. at night) & for Heat/Cool at start Compressor until Compressor Frequency < 30 Hz.;
3) DHW production if DHWTemp is (too) low, every day at fixed time if DHWTemp < DHWTargetTemp + DHWDelta, if day is #DHWComfortDay and 1 x per week (at #DHWSterilizationDay) a Sterilization run;
4) Sync OT values with HP values to have correct (status) values from HP communicated to OT Thermostat;
5) OT Thermostat HP control: 1) switch off HP (water circulation pump) when ?chEnable is 0 (for a certain time) or room temperature too high;
6) TaSHifT function to 1) lower Compressor frequency asap by lowering Ta and increasing HeatDelta, 2) extend the run time if Heat loss is less than minimum HP Power and 3) adapt Ta based on RoomTempDelta.
7) ExternalOverRide function to selectively swith off some functions via Home Assistant;
8) Cooling control via OpenTherm gateway and Home Assistant; HA initiates ?CoolingEnable true with a Switch in Home Assistant and does set ?coolingControl signal based on dewpoint calculation in HA.

# HeishaMon Rules

## Introduction

Here you find a collection of different rules to use with the [HeishaMon](https://github.com/Egyras/HeishaMon). 

Special thanks to [@CurlyMoo](https://github.com/CurlyMoo) for all rules functionality and [@fbloemhof](https://github.com/fbloemhof) for the inspiration how to document on Github.

> [!WARNING]  
> Usage of these rules is at your own risk.






<footer>

<!--
  <<< Author notes: Footer >>>
  Add a link to get support, GitHub status page, code of conduct, license link.
-->

---

</footer>
