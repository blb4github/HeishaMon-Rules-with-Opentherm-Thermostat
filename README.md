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

b)	Heishamon Opentherm version, firmware Alpha-f15a0fe;

c)	Central heating system build out of radiators and convectors;

d)	Evohome zone thermostat with opentherm boiler module.


</header>

<!--

-->

## My Requirements for the Rules Set:

1)  Max Pump Speed based on HP status 1) DHW, 2) HEAT/COOL (and the outside temp as well), IDLE flow;
2)  QuiteMode based on time (e.g. at night) & for Heat/Cool at start Compressor until Compressor Frequency < 30 Hz.;
3)  DHW production if DHWTemp <39, every day at fixed time if DHWTemp < DHWTargetTemp + DHWDelta and 1 x per week (at LegionellaRunDay) a legionellarun;
4)  WAR calcuation based on WAR Temperature settings from HP;
5)  Result of WAR calculation used for OT maxTSet (which is used by OT Thermostat as Maximum ?chSetpoint);
6)  Sync OT values with HP values to have correct (status) values from HP communicated to OT Thermostat;
7)  OT Thermostat HP control: 1) sync Main_Target_Temp with ?chSetpoint and 2) switch off HP (wapter pump) when ?chEnable is 0 (for a mimumum time);
8)  Softstart function with 1) minimize Compressor Frequency asap and 2) increase Main_Target_Temp to extend the run time.

# HeishaMon Rules

## Introduction

Here you find a collection of different rules to use with the [HeishaMon](https://github.com/Egyras/HeishaMon). 

Special thanks to [@CurlyMoo](https://github.com/CurlyMoo) for all rules functionality and [@fbloemhof](https://github.com/fbloemhof) for the inspiration how to document on Github.

> [!WARNING]  
> Usage of these rules is at your own risk.

## Instructions

You can pick the functions you like. To start you always need the [`System#Boot`](#on-systemboot) section, this is where the basics are configured. Also `timer 1` and `timer 2` are part of the basic setup although timer 1 and timer 2 are placed at the end of the rules set.

## System#Boot, timer=1, timer=2

### System#Boot
**Purpose**: 1) define which functions are active (#allow variables), 2) initial values of global variables used in the ruleset and 3) start 2 main timers, 1 for time reference, the other one to trigger all acitve functions.

**Explanation**: By default all functions are enabled (the #allow* variables), you can disable them by setting 1 to 0. 2 Variables have to be set according needs; #legionellaRunDay = [1..7] defines the day a legionellarun will be performed (1 is Sunday, 7 is Saturday) and #maxPumpDuty = xx defines the maxPumpDuty to be used as start during Heat run. All other global variables are default set to -1 so you can monitor the results of the functions easily. In the System#Boot loop timer 1 is triggered after only 60 seconds to give time to fill all variables from HP, OT and 1W.

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
	#allowDHW = 1;
	#allowOTThermostat = 1;
	#allowPumpSpeed = 1;
	#allowSilentMode = 1;
	#allowSoftStart = 1;
	#allowSyncOT = 1;
	#allowWAR = 1;

	#debug = 1;

	#legionellaRunDay = 7;
	#maxPumpDuty = 85;

	#chEnable = -1;
	#chEnableOffTime = -1;
	#chEnableTimeOff = -1;
	#chSetPoint = -1;
	#compRunTime = -1;
	#compStartTime = -1;
	#compState = -1;
	#DHWRun = -1;
	#firstBoot = 1;
	#heatPumpState = -1;
	#mainTargetTemp = -1;
	#maxTa = -1;
	#mildMode = -1;
	#operatingMode = -1;
	#prevHeatPumpState = -1;
	#prevOperatingMode = -1;
	#quietMode = -1;
	#roomTempDelta = -1;
	#sSC = -1;
	#softStartPhase = -1;
	#thermostatState = -1;
	#timeRef = -1;
	setTimer(1,60);
	setTimer(2,10);
end

on timer=1 then
	if #firstBoot == 1 then
		#firstBoot = 0;
		#heatPumpState = @Heatpump_State;
		#operatingMode = @Operating_Mode_State;
		#sSC = 0;
		compFreq();
		WAR();
		syncOpenTherm();
	else
		WAR();
		silentMode();
		syncOpenTherm();
		pumpDuty();
		DHW();
		OTThermostat();
		if #debug == 1 then
			$chEnable = #chEnable;
			$chEnableTimeOff = #chEnableTimeOff;
			$chSetPoint = #chSetPoint;
			$compRunTime = #compRunTime;
			$compState = #compState;
			$maxTa = #maxTa;
			$mildMode = #mildMode;
			$quietMode = #quietMode;
			$roomTempDelta = #roomTempDelta;
			$sSC = #sSC;
			$softStartPhase = #softStartPhase;
			$thermostatState = #thermostatState;
			$mainTargetTemp = #mainTargetTemp;
			$maxPumpDuty = #maxPumpDuty;
		end
	end
	setTimer(1,15);
end

on timer=2 then
	#timeRef = %day * 1440 + %hour * 60 + %minute;
	setTimer(2,60);
end
```

</details>


## softStart/quietMode
### quietMode
**Purpose**: 1) to limit the noice from the HP during night time, 2) to limit the startup power (which comes with noice as well) to prevent short runs and 3) to limit the fan noice when the compressor goes to OFF.

**Result**: @SetQuietMode set to required value

**Called by**: softStart, silentMode and compFreq


### softstart
**Purpose**: 1) reduce noice, 2)  avoid overshoot of Ta and 3) improve efficiency & minimize compressor start/stops by forcing long runs on low power with low Ta (which gives high COP).

**Explanation**: This function tries to reduce the compressor frequency asap after startup of the compressor (#softStartPhase = 1) by setting QuietMode and reducing target temp to temp below current water temp. After this startup behavour it increases the target temp to prevent switch off compressor for a set time (2 hours, #softStartPhase = 2). After this phase it will gradualy reduce the correction value which will most likely lead to compressor off, #softStartPhase = 3). Some safeguard measures are in place to prevent @sSC above 5 and below -5 and to avoid #mainTargetTemp bolow 27 and above 40. It also prevents to set #mainTargetTemp more than 2 degrees below @MainOutlet_Temp to avoid compressor tuning OFF due to Ta too high above setpoint.  

**Result**: manipulated #mainTargetTemp

**Called by**: OTThermostat

<details>

<summary>quietMode/softStart</summary>

```LUA
on quietMode then
	if #mildMode > -1 then
		#quietMode = #mildMode;
	else
		if #chEnable == 0 && #compState == 1 then
			#quietMode = 3;
		else
			#quietMode = #silentMode;
		end
	end
	if @Quiet_Mode_Level != #quietMode then
		@SetQuietMode = #quietMode;
	end
end

on softStart then
	if #allowSoftStart == 1 && #compState == 1 then
		if #compRunTime < 3 then
			#softStartPhase = 1;
			#sSC = @Main_Outlet_Temp - #chSetpoint;
		else
			if #compRunTime < 180 then
				#softStartPhase = 2;
				if @Compressor_Freq < 22 then
					#sSC = @Main_Outlet_Temp - #chSetpoint;
				else
					if #chSetpoint <= @Main_Outlet_Temp then
						#sSC = @Main_Outlet_Temp - 0.7 - #chSetpoint;
					end
				end
				if #chSetpoint > @Main_Outlet_Temp then
					#sSC = @Main_Outlet_Temp + 1 - #chSetpoint;
				end
			else
				if #softStartPhase == 2 then
					#softStartPhase = 3;
					setTimer(8,5);
				end
			end
		end
		if #sSC > 5 then
			#sSC = 5;
		end
		if #sSC < -5 then
			#sSC = -5;
		end
		#mainTargetTemp = #chSetpoint + #sSC;
		if #mainTargetTemp < 27 then
			#mainTargetTemp = 27;
		end
		if #mainTargetTemp > 40 then
			#mainTargetTemp = 40;
		end
		#mainTargetTemp = floor(#mainTargetTemp);
		if #mainTargetTemp + 2 < @Main_Outlet_Temp then
			#mainTargetTemp = #mainTargetTemp + 1;
		end
		if @Compressor_Freq > 18 && @Compressor_Freq < 25 then
			#mildMode = 0;
			quietMode();
		end
	end
end	
						
on timer=3 then						
	#allowSilentMode = 1;					
end
```

</details>

## OTThermostat/compFreq

### OTThermostat
**Purpose**: to control the HP Heat prodcution by the Opentherm Thermostat.

**Explenation**: The main controls are ?chEnable and ?chSetpoint. To avoid unwanted target values a number of checks are build in to keep the target temp between 30 and #maxTa if compressor is OFF and between 27 and #maxTa if compressor is ON. The minimum target temp is higher if compressor is OFF to reach the condition to turm on the compressor earlier.

The compressor will be forced OFF if rooomtemperature is 0.5 degrees above setpoint, chEnable is 15 minutes off and the compressor did run for at least 30 minutes. The 0.5 above (room)setpoint is added because evohome could keep chEnable ON if other zones are not yet on targettemperature but is nessesary because not all rooms have TRV's mounted.

The HP will be switched ON if #chEnable == 1 and OFF if chEnable is 30 minutes off except if outside temperature is below 2 degrees (waterpump will continue to run in that situation).
This function is checked every 30 seconds except in softStartPhase 1 when it will run every 15 seconds.

If the OT Thermostat is not functioning a safeguard routine will set the MainTargetTemp to #maxTa and switch the HP ON during day time and OFF during night time. In this case this function will be checked every minute.

**Called by**: timer=1

### compFreq
**Purpose**: 1) determine if Compressor is running (#compState will be set to 1, otherwise 0), 2) set #compRunTime (time the compressor is running), 3) set back #sSC, #softStartPhase and #mildMode to default values and calls QuietMode function when compressor goes OFF

**Result**: #compState, #CompRunTime   

**Called by**: Timer=1 (firstBoot = 1), @Compressor_Freq

<details>

<summary>OTThermostat/compFreq</summary>

```LUA
on OTThermostat then
	if #allowOTThermostat == 1 && #DHWRun < 1 && @ThreeWay_Valve_State == 0 then
		if #thermostatState == 1 then
			if ?chSetpoint > 9 then
				if ?chSetpoint < 20 then
					#chSetpoint = 20;
				else
					#chSetpoint = ?chSetpoint;
				end
				if #chSetpoint < 30 && #chEnable == 1 && #compState == 0 then
					#chSetpoint = 30;
				end
				if #chSetpoint < 27 && #compState == 1 then
					#chSetpoint = 27;
				end
				if #chSetpoint > #maxTa then
					#chSetpoint = #maxTa;
				end
			end
			#mainTargetTemp = #chSetpoint;
			softStart();
			if #compState == 1 then
				#roomTempDelta = ?roomTempSet - ?roomTemp;
				if ((#roomTempDelta > 0.5 && #chEnable == 0) || #chEnableOffTime > 15) && @ThreeWay_Valve_State == 0 && #compRunTime > 30 then
					#mainTargetTemp = round(@Main_Outlet_Temp - 10);
				end
			end
			if @Z1_Heat_Request_Temp != #mainTargetTemp then
				@SetZ1HeatRequestTemperature = #mainTargetTemp;
				$mTT1 = #mainTargetTemp;
			end
			if @Heatpump_State != 1 && #chEnable == 1 then
				@SetHeatpump = 1;
			end
			if #chEnableOffTime > 30 && @ThreeWay_Valve_State == 0 && (#compRunTime > 30 || #compState == 0) && @Outside_Temp > 2 then
				@SetHeatpump = 0;
				#allowOTThermostat = 0;
				setTimer(7,600);
			end
			if #softStartPhase == -1 || #softStartPhase > 1 then
				#allowOTThermostat = 0;
				setTimer(7,25);
			end
		else
			#mainTargetTemp = #maxTA;
			if @Z1_Heat_Request_Temp != #mainTargetTemp then
				@SetZ1HeatRequestTemperature = #mainTargetTemp;
			end
			if (%hour > 22 || %hour < 7) && @Heatpump_State == 1 then
				@SetHeatpump = 0;
			end
			if (%hour < 23 || %hour > 6) && @Heatpump_State == 0 then
				@SetHeatpump = 1;
			end
			#allowOTThermostat = 0;
			setTimer(7,55);
		end
	end
end

on compFreq then
	if @Compressor_Freq > 18 then
		if #compState < 1 then
			#compStartTime = #timeRef;
			#compState = 1;
		end
		#compRunTime = #timeRef - #compStartTime;
		if #compRunTime < 0 then
			#compRunTime = #timeRef - #compStartTime + 10080;
		end
	else
		#compState = 0;
		#compStartTime = -1;
		#compRunTime = -1;
		#sSC = 0;
		#softStartPhase = -1;
		if #mildMode != #silentMode && #mildMode != -1 && #silentMode != 1 then
			#mildMode = #silentMode;
			QuietMode();
		end
	end
end

on @Compressor_Freq then
	compFreq();
end

on timer=7 then
	#allowOTThermostat  = 1;
end
```

</details>

### DHW
**Purpose**: 1) to have hot water available & 2) to do weekly legionella run.

**Explanation**: Every day between  13 and 14 hour (efficient time of day) a check is performed if DHW temp is below threshold. In that case a DHW run is performed and a legionella run if day is legionellaRunDay. As a safeguard a DHW run will be performed as well if DHW temp drops below 39 degrees. OM 4 is used to give the HP the option to produce heat during legionella run on external element.

After the DHW run the previous OM and HPState will be restored. Defrost state is checked to prevent returning back from DHW run to previous OM if Defrost is performed during DHW run. This function runs every 15 minutes

**Called by**: timer=1

<details>

<summary>DHW</summary>

```LUA
on DHW then
	if #allowDHW == 1 then
		#allowDHW = 0;
		if @ThreeWay_Valve_State == 0 && (@DHW_Temp < 39 || (%hour == 13 && (%day == #LegionellaRunDay || @DHW_Temp < @DHW_Target_Temp + @DHW_Heat_Delta))) then
			#DHWRun = 1;
			#prevOperatingMode = @Operating_Mode_State;
			#prevHeatPumpState = @Heatpump_State;
			@SetOperationMode = 4;
			if @Heatpump_State != 1 then
				@SetHeatpump = 1;
			end
			if %day == #legionellaRunDay && %hour >= 13 && @DHW_Temp > 47 && @Sterilization_State != 1 then
				@SetForceSterilization = 1;
			end
		end
		if #DHWRun == 1 then
			if @ThreeWay_Valve_State == 0 && @DHW_Temp >= @DHW_Target_Temp && @Defrosting_State == 0 && @Sterilization_State == 0 then
				@SetOperationMode = #prevOperatingMode;
				if @Heatpump_State != #prevHeatPumpState then
					@SetHeatpump = #prevHeatPumpState;
				end
				#prevOperatingMode = 4;
				#prevHeatPumpState = 1;
				#DHWRun = -1;
			end
		end
		setTimer(6,900);
	end
end

on timer=6 then
	#allowDHW = 1;
end
```
</details>

### maxPumpDuty

**Purpose**: to set the (max)PumpSpeed depening in the Operation Mode (Heat/Cool, DHW or Idle) and for Heat/Cool the speed will depend on the outside temperature as well to make sure enough heat can be transported. The main reason for this function is to avoid water running sounds in the piping an radiators.

**Explanation**: During DHW run the maxPumpDuty will be high (220) to allow high power transport to the boiler & during DHW run the piping doesn't produce noice. Almost at the end of the run the maxPumpSpeed is reduced (to 85) to avoid short noice peak when 3way valve returs back to 0.
During Heat maxPumpDuty will be set in such way the water flow will 10 to 13 liter per minute depending on the outside temperature.
During Idle maxPumpDuty will be set in such way the water flow will be 8 liter per minute.
As a saveguard a check is performed to avoid maxPumpDuty will be above 140 (during Heat or Idle). This function runs every minute.

**Called by**: timer=1

<details>
<summary>maxPumpDuty</summary>

```LUA
on pumpDuty then
	if #allowPumpSpeed == 1 then
		#allowPumpSpeed = 0;
		if @ThreeWay_Valve_State == 1 then
			if @DHW_Temp <= @DHW_Target_Temp then
				if @Max_Pump_Duty != 220 then
					@SetMaxPumpDuty = 220;
				end
			else
				if @Max_Pump_Duty != 85 then
					@SetMaxPumpDuty = 85;
				end
			end
		end
		if @ThreeWay_Valve_State == 0 && @Heatpump_State == 1 then
			if @Outside_Temp < 10 then
				$MPF = 11;
			else
				$MPF = 10;
			end
			if @Outside_Temp < 5 then
				$MPF = 12;
			end
			if @Outside_Temp < 2 then
				$MPF = 13;
			end
			if @Compressor_Freq == 0 then
				$MPF = 8;
			end
			if @Pump_Flow < $MPF then
				#maxPumpDuty = #maxPumpDuty + 5;
			else
				if @Pump_Flow > $MPF + 1 then
					#maxPumpDuty = #maxPumpDuty - 1;
				end
			end
			if #maxPumpDuty > 140 then
				#maxPumpDuty = 140;
			end
			if @Max_Pump_Duty != #maxPumpDuty then
				@SetMaxPumpDuty = #maxPumpDuty;
			end
		end
		setTimer(5, 60);
	end
end
				
on timer=5 then
	#allowPumpSpeed = 1;
end
```
</details>


### silentMode
**Purpose**: to define #silentMode value based on outside temperature and time of day. 

**Explanation**: #silentmode will be - together with #mildmode - used as basis for #quietMode. Quiet Mode is used for 3 reasons: 1) to limit the noice from the HP during night time, 2) to limit the startup power (which comes with noice as well) to prevent short runs and 3) to limit the fan noice when the compressor goes to OFF. This function runs every 15 minutes.

**Called by**: timer=1

<details>
<summary>siletMode</summary>

```LUA
on silentMode then
	if #allowSilentMode == 1 then
		#allowSilentMode = 0;
		if @Outside_Temp > 9 then
			#silentMode = 3;
		else
			if @Outside_Temp > 4 then
				#silentMode = 2;
			else
				if @Outside_Temp > 1 then
					if %hour > 22 || %hour < 7 then
						#silentMode = 1;
					else
						#silentMode = 0;
					end
				end
			end
		end
		setTimer(3, 900);
		quietMode();
	end
end
				
on timer=3 then
	#allowSilentMode = 1;
end
```
</details>


### syncOpenTherm
**Purpose**: 1) synchronizes several ?opentherm values with their corresponding @heatpump values and vice versa, 2) sync #chEnable with ?ch Enable, 3) detect if Opentherm Thermostat is active and 4) set #chEnableTimeOff variable.

**Explanation**: Most of the sync is straight forward, ?chEnable is sometime switched off for a short moment, the logic keeps #chEnable 1 as long as ?chEnable is 0 for less than 5 minutes. #chEnableTimeOff is used in OTTThermostat to swich off compressor and/or water pump. ?maxTSet is only cynch with #maxTA when #maxTA is set. This function runs every 15 seconds (in same pace as Timer=1)

**Result**: #chEnable, #chEnableTimeOff

**Called by**: timer=1

<details>

<summary>syncOpenTherm</summary>

```LUA
on syncOpenTherm then
	if  #allowSyncOT == 1 then
		?outletTemp = @Main_Outlet_Temp;
		?inletTemp = @Main_Inlet_Temp;
		?outsideTemp = @Outside_Temp;
		?dhwTemp = @DHW_Temp;
		?dhwSetpoint = @DHW_Target_Temp;
		if isset(?chEnable) && isset(?chSetpoint) && isset(?roomTempSet) && isset(?roomTemp) && ?roomTempSet != 0 && ?roomTemp != 0 then
			#thermostatState = 1;
		end
		if ?chEnable == 1 then
			#chEnable = 1;
			if #chEnableTimeOff != -1 then
				#chEnableTimeOff = -1;
				#chEnableOffTime = -1;
			end
		else
			if #chEnableTimeOff == -1 then
				#chEnableTimeOff = #timeRef;
			end
			#chEnableOffTime = #timeRef - #chEnableTimeOff;
			if #chEnableOffTime < 0 then
				#chEnableOffTime = #timeRef - #chEnableTimeOff + 10080;
			end
			if #chEnableOffTime > 5 then
				#chEnable = 0;
			end
		end
		#dhwEnable = ?dhwEnable;
		if #maxTa != -1 then
			?maxTSet = #maxTa;
		end
		if @Compressor_Freq == 0 then
			?flameState = 0;
			?chState = 0;
			?dhwState = 0;
		else
			?flameState = 1;
			if @ThreeWay_Valve_State == 0 then
				?chState = 1;
				?dhwState = 0;
			else
				?chState = 0;
				?dhwState = 1;
			end
		end
	end
end
```

</details>

### WAR

**Purpose**: to calculate the required T_Outlet as function of the outside temperature using a compensation curve. All values except @Z1_Heat_Curve_Target_High_Temp are use as @Z1_Heat_Curve_Target_High_Temp must be set during direct mode. The Target_Low temp is set with variable $Ta2 in this function. This function runs every 30 minutes.

**Result**: #maxTA which is used in the OTTThermostat function.

**Called by**: timer=1

<details>

<summary>calculateWAR</summary>

```LUA
on WAR then
	if #allowWAR == 1 then
		#allowWAR = 0;
		$Ta1 = @Z1_Heat_Curve_Target_Low_Temp;
		$Tb1 = @Z1_Heat_Curve_Outside_High_Temp;
		$Ta2 = 36;
		$Tb2 = @Z1_Heat_Curve_Outside_Low_Temp;
		if @Outside_Temp >= $Tb1 then
			#maxTa = $Ta1;
		else
			if @Outside_Temp <= $Tb2 then	#maxTa = $Ta2;
			else
				#maxTa = 1 + floor(0.9 + $Ta1 + (($Tb1 - @Outside_Temp) * ($Ta2 - $Ta1) / ($Tb1 - $Tb2)));
			end
		end
		setTimer(4,1800);
	end
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
