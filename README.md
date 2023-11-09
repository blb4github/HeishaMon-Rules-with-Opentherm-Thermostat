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
> Usage of the rules is at your own risk.

## Instructions

You can pick and mix the functions you like. To start you always need the [`System#Boot`](#on-systemboot) section, this is where the basics are configured.

### on System#Boot

This is the first section of the ruleset. Here you can configure some settings and are global variables defined. Default all functions are enabled (the `#allow*` variables), you can disable them by setting `1` to `0`.

The second part of the global variables are mostly helpers. Where possible the are defaulted to `-1` so you can monitor the results of the functions easily.

At the end the first & second timers, `1` & `2`, are set to run after 15 respecively 10 seconds. These timers are also set in this block. The first timer is the global timer that recurs every 15 seconds to handle all the main functions. The second timer is a time reference which is set every minute to be used in other functions.

<details>

<summary>System#Boot</summary>

```LUA
on System#Boot then
	#allowDHW = 1;
	#allowOTThermostat = 1;
	#allowPumpSpeed = 1;
	#allowSilentMode = 1;
	#allowSoftStart = 1;
	#allowSyncOT = 1;
	#allowWAR = 1;

	#chEnable = -1;
	#chEnableOffTime=-1;
	#chEnableTimeOff=-1;
	#chSetPoint = -1;
	#compRunTime = -1;
	#compStartTime = -1;
	#compState = -1;
	#DHWRun = -1;
	#legionellaRunDay = 7;
	#mainTargetTemp = -1;
	#maxPumpDuty = 85;
	#maxTa = -1;
	#mildMode = -1;
	#prevHeatPumpState = -1;
	#prevOperatingMode = -1;
	#quietMode = -1;
	#roomTempDelta = -1;
	#softStartCorrection = 0;
	#softStartPhase = -1;
	#timeRef = -1;
	setTimer(1,10);
	setTimer(2,15);
end

on timer=1 then
	calculateWAR();
	setSilentMode();
	syncOpenTherm();
	setMaxPumpDuty();
	checkDHW();
	OTThermostat();
	setTimer(1,15);
end

on timer=2 then
	#timeRef = %day * 1440 + %hour * 60 + %minute;
	setTimer(2,60);
end
```

</details>

### syncOpenTherm

This function synchronizes the heatpump values with your OpenTherm thermostat.

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

### calculateWAR

This function calculates the target temperature based on the configured Heat Curve. Three values for this calculation are taken from the Heat Pump, the Heat Curve Target High is not taken from the Heat Pump but must be set in the rules block as this value is synced with @Main_Target_Temp in Direct mode. 

When using `syncOpenTherm` the `#maxTa` value will be synced to the thermostat as `?maxTSet`.

This block will be executed once every 15 minutes as set by timer 5.

<details>

<summary>calculateWAR</summary>

```LUA
on calculateWAR then
	if #allowWAR == 1 then
		if isset(@Z1_Heat_Curve_Target_Low_Temp) == 1 && isset(@Z1_Heat_Curve_Outside_High_Temp) == 1 && isset(@Z1_Heat_Curve_Target_High_Temp) == 1 && isset(@Z1_Heat_Curve_Outside_Low_Temp) == 1 then
			$Ta1 = @Z1_Heat_Curve_Target_Low_Temp;
			$Tb1 = @Z1_Heat_Curve_Outside_High_Temp;
			$Ta2 = 36;
			$Tb2 = @Z1_Heat_Curve_Outside_Low_Temp;
			if @Outside_Temp >= $Tb1 then
				#maxTa = $Ta1;
			else
				if @Outside_Temp <= $Tb2 then
					#maxTa = $Ta2;
				else
					#maxTa = 1 + floor(0.9 + $Ta1 + (($Tb1 - @Outside_Temp) * ($Ta2 - $Ta1) / ($Tb1 - $Tb2)));
				end
			end
		end
		#allowWAR = 0;
		setTimer(5,900);
	end
end

on timer=5 then
	#allowWAR = 1;
end
```

</details>

### setSilentMode

This function sets the quiet mode based on a combination of the current time and the value of `@Outside_Temp`. It will limit the frequency of the compressor and the fan speed, reducing the noice from the Heat Pump with reducing the power and efficiency of the Heat Pump as trade off. On the other hand it will help the heatpump running more stable and in low frequencies and reach low frequencies earlier than without QM.

> [!IMPORTANT]  
> Using this function will enable quiet mode which might impact your power usage and the performance of your heatpump. To overcome this quiet mode can be swiched on/off by softStart function, see that function for more details.

<details>

<summary>setSilentMode</summary>

```LUA
on setSilentMode then
	if isset(@Outside_Temp) == 1 && isset(@Heatpump_State) then
		if #allowSilentMode == 1 then
			#allowSilentMode = 0;
			if @Outside_Temp < 10 then
				#silentMode = 2;
			else
				#silentMode = 3;
			end
			if @Outside_Temp < 5 then
				#silentMode = 1;
			end
			if @Outside_Temp < 2 then
				if %hour > 22 || %hour < 7 then
					#silentMode = 1;
				else
					#silentMode = 0;
				end
			end
			setTimer(3, 900);
			setQuietMode();
		end
	end
end

on timer=3 then
	#allowSilentMode = 1;
end

on setQuietMode then
	if #mildMode > -1 then
		#quietMode = #mildMode;
	else
		#quietMode = #silentMode;
	end
	if @Quiet_Mode_Level != #quietMode then
		@SetQuietMode = #quietMode;
	end
end
```

</details>

### setMaxPumpDuty

This function adjust the pump duty based on the state of the heatpump and the outside temperature. This function will run every 60 seconds based on timer 6.

<details>

<summary>setMaxPumpDuty</summary>

```LUA
on setMaxPumpDuty then
	if #allowPumpSpeed == 1 then
		#allowPumpSpeed = 0;
		if @ThreeWay_Valve_State == 1 && @Max_Pump_Duty != 220 then
			@SetMaxPumpDuty = 220;
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
		setTimer(6, 60);
	end
end

on timer=6 then
	#allowPumpSpeed = 1;
end
```

</details>

### checkDHW

This function will check every 15 minutes (based on timer 7) if a DHW or sterilisation run is requied. After this run the Heat Pump will return to the state before the run. It will initiate a DHW run when:
DHWTemp < 39 degrees;
Every day around 13:00u if DHWTemp < DHWTarget + DHWDelta;
On LegionellaRunDay it will perform a sterilisation rum around 13:00u

<details>

<summary>checkDHW</summary>

```LUA
on checkDHW then
	if #allowDHW == 1 then
		#allowDHW = 0;
		if @ThreeWay_Valve_State == 0 && (@DHW_Temp < 39 || (%hour == 13 && (%day == #LegionellaRunDay || @DHW_Temp < @DHW_Target_Temp + @DHW_Heat_Delta))) then
			#prevOperatingMode = @Operating_Mode_State;
			#prevHeatPumpState = @Heatpump_State;
			@SetOperationMode = 3;
			if @Heatpump_State != 1 then
				@SetHeatpump = 1;
			end 
			if %day == #legionellaRunDay then
				@SetForceSterilization = 1;
			end
			#DHWRun = 1;
		end
		if #DHWRun == 1 then
			if @ThreeWay_Valve_State == 0 && @DHW_Temp > 49 then
				@SetOperationMode = #OperatingModeLast;
				if @Heatpump_State != #HeatPumpStateLast then
					@SetHeatpump = #HeatPumpStateLast;
				end
				#OperatingModeLast = 3;
				#HeatPumpStateLast = 1;
				#DHWRun = -1;
			end
		end
		setTimer(7,900);
	end
end

on timer=7 then
	#allowDHW = 1;
end
```
</details>

### OTTThermostat

This function will control Heat settings of the Heat Pump based on the requests from the OpenTherm Thermostat. It will control the Setpoint and it will switch on/of the waterpump based on chEnable.

<details>

<summary>OTTThermostat</summary>

```LUA
on OTThermostat then
	if #allowOTThermostat == 1 && #DHWRun != 1 then
		if @ThreeWay_Valve_State == 0 then
			if ?chSetpoint > 9 then
				#chSetpoint = ?chSetpoint;
				if #chSetpoint < 30 && #compState == 0 then
					#chSetpoint = 30;
				end
				if #chSetpoint < 27 && #compState == 1 then
					#chSetpoint = 27;
				end
				if #chSetpoint > #maxTa then
					#chSetpoint = #maxTa;
				end
			end
			softStart();
			#mainTargetTemp = #chSetpoint + #softStartCorrection;
			if #mainTargetTemp < 27 then
				#mainTargetTemp = 27;
			end
			if #mainTargetTemp > 40 then
				#mainTargetTemp = 40;
			end
			#mainTargetTemp = floor(#mainTargetTemp);
			if #compState == 1 then
				if #mainTargetTemp + 2 < @Main_Outlet_Temp then
					#mainTargetTemp = round(@Main_Outlet_Temp - 1.5);
				end
				#roomTempDelta = ?roomTempSet - ?roomTemp;
				if #roomTempDelta > 1 && #chEnableOffTime > 15 && @ThreeWay_Valve_State == 0 && #compRunTime > 30 then
					#mainTargetTemp = round(@Main_Outlet_Temp - 10);
				end
			end
			if @Z1_Heat_Request_Temp != #mainTargetTemp then
				@SetZ1HeatRequestTemperature = #mainTargetTemp;
			end
			if @Operating_Mode_State != 0 then
				@SetOperationMode = 0;
			end
			if @Heatpump_State != 1 && #chEnable == 1 then
				@SetHeatpump = 1;
			end
		end
		if #chEnableOffTime > 15 && @ThreeWay_Valve_State == 0 && (#compRunTime > 30 || #compState == 0) && @Outside_Temp > 2 then
			@SetHeatpump = 0;
		end
		if #softStartPhase == -1 || #softStartPhase > 1 then
			#allowOTThermostat = 0;
			setTimer(8,25);
		end
	end
end

on timer=8 then
	#allowOTThermostat  = 1;
end

on @Compressor_Freq then
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
		#softStartCorrection = 0;
		#softStartPhase = -1;
		if #mildMode != #silentMode then
			#mildMode = #silentMode;
			setQuietMode();
		end
	end
end
```

</details>

### softStart

This function is an extension to the OTTThermostat function.

<details>

<summary>softStart</summary>

```LUA
on softStart then
	if #allowSoftStart == 1 && #compState == 1 then
		if #compRunTime == -1 then
			#softStartPhase = 0;
		else
			if #compRunTime < 3 then
				#softStartPhase = 1;
				#softStartCorrection = @Main_Outlet_Temp - 1 - #chSetpoint;
			else
				if #compRunTime < 120 then
					#softStartPhase = 2;
					if #chSetpoint <= @Main_Outlet_Temp then
						#softStartCorrection = @Main_Outlet_Temp - 0.7 - #chSetpoint;
					end
					if #chSetpoint > @Main_Outlet_Temp then
						#softStartCorrection = @Main_Outlet_Temp + 1 - #chSetpoint;
					end
				else
					if #softStartPhase == 2 then
						#softStartPhase = 3;
						setTimer(9,5);
					end
				end
			end
		end
		if #softStartCorrection > 5 then
			#softStartCorrection = 5;
		end
		if #softStartCorrection < -5 then
			#softStartCorrection = -5;
		end
		if @Compressor_Freq > 18 && @Compressor_Freq < 26 && #softStartPhase > 1 then
			#mildMode = 0;
			setQuietMode();
		end
	end
	if #allowSoftStart == 1 && #compState == -5 then
		#softStartCorrection = #mainTargetTemp - #chenable;
	end
end

on timer=9 then
	if #softStartCorrection > 0 then
		#softStartCorrection = #softStartCorrection - 1;
		setTimer(9,900);
	end
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
