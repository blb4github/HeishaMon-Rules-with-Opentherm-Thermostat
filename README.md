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

a)	Panasonic Heat Pump WH-MDC07J3E5 used for central heating and DHW (external tank);

b)	Heishamon Large, firmware 3.8;

c)	Central heating system build out of radiators and convectors;

d)	Evohome zone thermostat with opentherm boiler module.


</header>

<!--

-->

## My Requirements for the Rules Set:

1)  Max Pump Speed based on HP status 1) DHW, 2) HEAT/COOL (and the outside temp as well), IDLE flow;
2)  QuiteMode based on time (e.g. at night) & for Heat/Cool at start Compressor until Compressor Frequency < 30 Hz.;
3)  DHW production if DHWTemp <37, every day at fixed time if DHWTemp < DHWTargetTemp + DHWDelta and 1 x per week (at LegionellaRunDay) a legionellarun;
4)  Sync OT values with HP values to have correct (status) values from HP communicated to OT Thermostat;
5)  OT Thermostat HP control: 1) switch on/off HP (wapter pump) when ?chEnable is 0 (for a mimumum time);
6)  TaShift function: 1) adapt Ta based on RoomTempDelta and 2) increases Main_Target_Temp to extend the run time if Heat loss is less than minimum HP Power.

# HeishaMon Rules

## Introduction

Here you find a collection of different rules to use with the [HeishaMon](https://github.com/Egyras/HeishaMon). 

Special thanks to [@CurlyMoo](https://github.com/CurlyMoo) for all rules functionality and [@fbloemhof](https://github.com/fbloemhof) for the inspiration how to document on Github.

> [!WARNING]  
> Usage of these rules is at your own risk.

## Instructions

It should be possible to pick and choose the functions you like. To start you always need the [`System#Boot`](#on-systemboot) section, this is where the basics are configured. Also `timer 1` and `timer 2` are part of the basic setup although timer 1 and timer 2 are placed at the end of the rules set.

## System#Boot, timer=1, timer=2

### System#Boot
**Purpose**: 1) define which functions are active (#allow variables), 2) initial values of global variables used in the ruleset and 3) start 2 main timers, 1 for time & day references, the other one to trigger all acitve functions.

**Explanation**: By default all functions are enabled (the #allow* variables), you can disable them by setting 1 to 0. 3 Variables have to be set according needs; #legionellaRunDay = [1..7] defines the day a legionellarun will be performed (1 is Sunday, 7 is Saturday), #maxPDuty = xx defines the maxPumpDuty to be used as start during Heat run and #maxTa = xx sets the default maxTa if WAR function isn't used (#allowWAR = 0). All other global variables are default set to -1 so you can monitor the results of the functions easily. In the System#Boot loop timer 1 is triggered after only 60 seconds to give time to fill all variables from HP, OT and 1W.

**Called by**: system Boot

### timer=1
**Purpose**: to call all functions.

**Explanation**: this function will run first time 1 minute after system Boot to allow all HP & OT variables to sync with HP/OT Thermostat. First Run (#firstBoot = 1) is different to set some values correct and to run some functions in the right order.

**Called by**: System#Boot, timer=1


### timer=2
**Purpose**: time refference

**Explanation**: #chEnableOffTime and #compRunTime are based on #timeRef. As HeishaMon doesn't have time function #timeRef is set to minutes after sunday 00:00u.

**Called by**: 10 seconds after System#Boot, timer=2 (every minute)

<details>

<summary>System#Boot, timer=1, timer=2</summary>

```LUA
on System#Boot then
	
end

on timer=1 then

end

on timer=2 then

end
```

</details>

### eXtRunTime() (ExtendRunTime)
**Purpose**: extend compressor runtime by shifting Target Temp up if TOutlet is higher than Target temp

**Explanation**: at a certain (high) outside Temperature the minimum power of the HP is higher than the heat lost and as a result the compressor will switch off if TOutlet > Target temp + 2 degrees. This can lead to short compressor run times and the purpose of this function is to extend the runtime by shifting the Target Temp up.

**Result**: @SetZ1HeatRequestTemperature set to required value

**Called by**: timer=1

<details>

<summary>eXtRunTime</summary>

```LUA
on eXtRunTime then
	
end
```

</details>



## OTThermostat/compFreq

### OTT() (OpenTherm Thermostat)
**Purpose**: to control the HP Heat prodcution by the Opentherm Thermostat.

**Explanation**: The main control is ?chEnable; chEnable does have similar function as an ON/OFF thermostat (as my Evohome Opentherm thermostat doesn't provide a stable chSetpoint value I'm not using chSetpoint anymore). 

The compressor will be forced OFF if rooomtemperature is 0.5 degrees above setpoint, chEnable is 15 minutes off and the compressor did run for at least 30 minutes. The 0.5 above (room)setpoint is added because evohome could keep chEnable ON if other zones are not yet on targettemperature but is nessesary because not all rooms have TRV's mounted.

The HP will be switched ON if #chEnable == 1 and OFF if chEnable is 30 minutes off except if outside temperature is below 2 degrees (waterpump will continue to run in that situation).
By default this function is checked every 30 seconds except when heatpump is switched off if will run only after 10 minutes.

**Called by**: timer=1

### compFreq()
**Purpose**: 1) determine if Compressor is running (#compState will be set to 1, otherwise 0), 2) set #compRunTime (time the compressor is running).

**Result**: #compState, #CompRunTime   

**Called by**: Timer=1 (firstBoot = 1), @Compressor_Freq

<details>

<summary>OTThermostat/compFreq</summary>

```LUA
on OTT then
	
end

on compFreq then
	
end

on @Compressor_Freq then
	compFreq();
end

on timer=7 then
	#allowOTThermostat  = 1;
end
```

</details>

### DHW()
**Purpose**: 1) to have hot water available & 2) to do weekly legionella run.

**Explanation**: Every day between  13 and 14 hour (efficient time of day) a check is performed if DHW temp is below threshold. In that case a DHW run is performed and a legionella run if day is legionellaRunDay. As a safeguard a DHW run will be performed as well if DHW temp drops below 37 degrees. OM 4 is used to give the HP the option to produce heat during legionella run on external element.

After the DHW run the previous OM and HPState will be restored. Defrost state is checked to prevent returning back from DHW run to previous OM if Defrost is performed during DHW run. This function runs every 15 minutes

**Called by**: timer=1

<details>

<summary>DHW</summary>

```LUA
on DHW then
	
end

on timer=6 then
	#allowDHW = 1;
end
```
</details>

### PumpDuty()
**Purpose**: to set the (max)PumpSpeed depening in the Operation Mode (Heat/Cool, DHW or Idle) and for Heat/Cool the speed will depend on the outside temperature as well to make sure enough heat can be transported. The main reason for this function is to avoid water running sounds in the piping an radiators.

**Explanation**: During DHW run the maxPumpDuty will be high (140) to allow high power transport to the boiler & during DHW run the piping doesn't produce noice. Almost at the end of the run the maxPumpSpeed is reduced (to 90) to avoid short noice peak when 3way valve returs back to 0. If @Pump_Flowrate_mode == 1 (direct) maxPumpDuty will be set based on actual water flow (see below), else the actual water flow will not be used as feedback as the HP controls pump duty itselfs based on dT.
During Heat maxPumpDuty will be set in such way the water flow will 10 to 13 liter per minute depending on the outside temperature.
During Idle maxPumpDuty will be set in such way the water flow will be 8 liter per minute.
When HP switches off maxPumpDuty will be set back to default value.

**Called by**: timer=1

<details>
<summary>maxPumpDuty</summary>

```LUA
on pumpDuty then
	
end

				
on timer=5 then
	#allowPumpSpeed = 1;
end
```
</details>


## quietMode / silentMode

### quietMode()
**Purpose**: execute @SetQuietMode command

**Called by**: silentMode, @Defrosting_State


### silentMode()
**Purpose**: to define #silentMode value based on outside temperature and time of day. 

**Explanation**: #ilentMode/Quiet Mode is used for 2 reasons: 1) to limit the noice from the HP during night time, 2) to limit the startup power (which comes with noice as well) to prevent short runs. During DHW mode in dayTime the QM level will be 1 step reduced to have more power available. This function runs every 2 minutes.

**Called by**: timer=1

<details>
<summary>siletMode / quietmode</summary>

```LUA


on silentMode then
	
end
				
on timer=3 then
	#allowSilentMode = 1;
end
```
</details>


### syncOT() (synchOpenTherm)
**Purpose**: 1) synchronizes several ?opentherm values with their corresponding @heatpump values and vice versa, 2) sync #chEnable with ?chEnable, 3) set #chEnableTimeOff variable.

**Explanation**: Most of the sync is straight forward, ?chEnable is sometime switched off for a short moment, the logic keeps #chEnable 1 as long as ?chEnable is 0 for less than 5 minutes or ?chSetpoint = 10. #chEnableTimeOff is used in OTTThermostat to swich off compressor and/or water pump. ?maxTSet is only cynch with #maxTA when #maxTA is set. During Defrost both ?chState & DHWState are set to 0. This function runs every 15 seconds (in same pace as Timer=1)

**Result**: #chE(nable), #chETimeOff

**Called by**: timer=1


<details>

<summary>syncOpenTherm</summary>

```LUA
on syncOT then
	
end
```

</details>

### WAR()
**Purpose**: to calculate the required T_Outlet as function of the outside temperature using a compensation curve. If @Heating_Mode == 1 (direct) Z1_Heat_Curve_Target_High_Temp is set in this function as @Z1_Heat_Curve_Target_High_Temp is set to @SetZ1HeatRequestTemperature during direct mode. This function runs every 30 minutes.

**Result**: #maxTA which is used in the OTTThermostat function.

**Called by**: timer=1

<details>

<summary>WAR</summary>

```LUA
on WAR then
	
end
				
on timer=4 then
	#allowWAR = 1;
end
```

</details>




<footer>

<!--
  <<< Author notes: Footer >>>
  Add a link to get support, GitHub status page, code of conduct, license link.
-->

---

</footer>
