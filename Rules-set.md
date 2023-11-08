# Rules set for HeishaMon


function | Rules | Description
:--- | --- | ---
ALL|on System#Boot then|
DHW|	#allowDHW = 1;|allow DHW function (0/1)
OTT|	#allowOTThermostat = 1;|allow OTT Thermostat function (0/1)
PS|	#allowPumpSpeed = 1;|allow PumpSpeed function (0/1)
SM|	#allowSilentMode = 1;|allow SilentMode function (0/1)
SS|	#allowSoftStart = 1;|allow SoftStart function (0/1)
SyncOT|	#allowSyncOT = 1;|allow Sync OT function (0/1)
WAR|	#allowWAR = 1;|allow WAR function (0/1)
ALL||
SyncOT|	#chEnable = -1;|#chEnable is clean ?chEnable 
SyncOT OTT|	#chEnableOffTime = -1;|Time?chEnable goes off
SyncOT|	#chEnableTimeOff = -1;|?chEnable Off Timer
OTT|	#chSetPoint = -1;|copy of ?chEnable
OTT|	#compRunTime = -1;|Time the compressor is running
OTT|	#compStartTime = -1;|Time the compressor starts running
OTT|	#compState = -1;|compressor state (0/1)
DHW|	#DHWRun = -1;|DHWrun state (0/1)
DHW|	#legionellaRunDay = 7;|1 (Monday) .. 7 (Saturday)
OTT|	#mainTargetTemp = -1;|Water Temperature target for HEAT
PS|	#maxPumpDuty = 85;|value which fits my installation (~ 11l/m)
WAR SyncOT|	#maxTa = -1;|
SM|	#mildMode = -1;|
DHW|	#prevHeatPumpState = -1;|
DHW|	#prevOperatingMode = -1;|
SM|	#quietMode = -1;|
SyncOT OTT|	#roomTempDelta = -1;|delta between room setpoint and temp
OTT SS|	#softStartCorrection = 0;|
SS|	#softStartPhase = -1;|
SyncOT OTT SM SS|	#timeRef = -1;|
ALL|	setTimer(1,10);|main timer which calls all functions
SyncOT OTT|	setTimer(2,15);|timer for time reference
ALL|end|
ALL||
ALL|on timer=1 then|main timer which calls all functions
WAR|	calculateWAR();|not required to remove them if you
SM|	checkSilentMode();|don't need them, this is done with
SyncOT|	syncOpenTherm();|the allow variable in the on boot
PS|	maxPumpDuty();|block
DHW|	checkDHW();|
OTT|	OTThermostat();|
ALL|	setTimer(1,15);|run this function every 15 seconds
ALL|end|
SyncOT OTT SS||
SyncOT OTT SS|on timer=2 then|timer for time reference
SyncOT OTT SS|	#timeRef = %day * 1440 + %hour * 60 + %minute;|sync #timeRef with current time 
SyncOT OTT SS|	setTimer(2,60);|run this function every  minute
SyncOT OTT SS|end|
SM||
SM|on checkSilentMode then|SilentMode function
SM|	if isset(@Outside_Temp) == 1 && isset(@Heatpump_State) then|Sets #silentmode value depending on
SM|		if #allowSilentMode == 1 then|outside temperature and time of day
SM|			#allowSilentMode = 0;|
SM|			if @Outside_Temp < 10 then|
SM|				#silentMode = 2;|
SM|			else|
SM|				#silentMode = 3;|
SM|			end|
SM|			if @Outside_Temp < 5 then|
SM|				#silentMode = 1;|
SM|			end|
SM|			if @Outside_Temp < 2 then|
SM|				if %hour > 22 || %hour < 7 then|
SM|					#silentMode = 1;|
SM|				else|
SM|					#silentMode = 0;|
SM|				end|
SM|			end|
SM|			setTimer(3, 900);|this function runs every 15 minutes
SM|			setQuietMode();|
SM|		end|
SM|	end|
SM|end|
SM||
SM|on timer=3 then|reset allow parameter
SM|	#allowSilentMode = 1;|
SM|end|
SM||
SM|on setQuietMode then|Set QuietMode variable
SM|	if #mildMode > -1 then|QuietMode will be #mildMode if 
SM|		#quietMode = #mildMode;|#mildMode is set, otherwise 
SM|	else|#silentMode
SM|		#quietMode = #silentMode;|
SM|	end|
SM|	if @Quiet_Mode_Level != #quietMode then|
SM|		@SetQuietMode = #quietMode;|
SM|	end|
SM|end|
SyncOT||
SyncOT|on syncOpenTherm then|Sync OT variable
SyncOT|	if #allowSyncOT == 1 then|
SyncOT|		?outletTemp = @Main_Outlet_Temp;|
SyncOT|		?inletTemp = @Main_Inlet_Temp;|
SyncOT|		?outsideTemp = @Outside_Temp;|
SyncOT|		?dhwTemp = @DHW_Temp;|
SyncOT|		?dhwSetpoint = @DHW_Target_Temp;|
#REF!
SyncOT|		if ?chEnable == 1 then|keep #chEnable 1 if ?chEnable is 0 for 
SyncOT|			#chEnable = 1;|only a short (5 minute) time
SyncOT|			if #chEnableTimeOff != -1 then|
SyncOT|				#chEnableTimeOff = -1;|
SyncOT|				#chEnableOffTime = -1;|
SyncOT|			end|
SyncOT|		else|
SyncOT|			if #chEnableTimeOff == -1 then|
SyncOT|				#chEnableTimeOff = #timeRef;|
SyncOT|			end|#chEnableOffTime gives time in 
SyncOT|			#chEnableOffTime = #timeRef - #chEnableTimeOff;|minutes ?chEnable = 0
SyncOT|			if #chEnableOffTime < 0 then|
SyncOT|				#chEnableOffTime = #timeRef - #chEnableTimeOff + 10080;|
SyncOT|			end|#chEnable goes to 0 after 5 minutes
SyncOT|			if #chEnableOffTime > 5 then|
SyncOT|				#chEnable = 0;|
SyncOT|			end|
SyncOT|		end|
SyncOT|		#dhwEnable = ?dhwEnable;|sync ?maxTa with result of the WAR
SyncOT|		if #maxTa != -1 then|function
SyncOT|			?maxTSet = #maxTa;|
SyncOT|		end|
SyncOT|		if @Compressor_Freq == 0 then|
SyncOT|			?flameState = 0;|
SyncOT|			?chState = 0;|
SyncOT|			?dhwState = 0;|
SyncOT|		else|
SyncOT|			?flameState = 1;|
SyncOT|			if @ThreeWay_Valve_State == 0 then|
SyncOT|				?chState = 1;|
SyncOT|				?dhwState = 0;|
SyncOT|			else|
SyncOT|				?chState = 0;|
SyncOT|				?dhwState = 1;|
SyncOT|			end|
SyncOT|		end|
SyncOT|	end|
WAR|end|
WAR||Calculate WAR setpoint function
WAR|on calculateWAR then|
WAR|	if #allowWAR == 1 then|
WAR|		if isset(@Z1_Heat_Curve_Target_Low_Temp) == 1 && isset(@Z1_Heat_Curve_Outside_High_Temp) == 1 && isset(@Z1_Heat_Curve_Target_High_Temp) == 1 && isset(@Z1_Heat_Curve_Outside_Low_Temp) == 1 then|
WAR|			$Ta1 = @Z1_Heat_Curve_Target_Low_Temp;|
WAR|			$Tb1 = @Z1_Heat_Curve_Outside_High_Temp;|
WAR|			$Ta2 = 36;|
WAR|			$Tb2 = @Z1_Heat_Curve_Outside_Low_Temp;|
WAR|			if @Outside_Temp >= $Tb1 then|
WAR|				#maxTa = $Ta1;|
WAR|			else|
WAR|				if @Outside_Temp <= $Tb2 then|
WAR|					#maxTa = $Ta2;|
WAR|				else|
WAR|					#maxTa = 1 + floor(0.9 + $Ta1 + (($Tb1 - @Outside_Temp) * ($Ta2 - $Ta1) / ($Tb1 - $Tb2)));|
WAR|				end|
WAR|			end|
WAR|		end|
WAR|		#allowWAR = 0;|this function runs every 15 minutes
WAR|		setTimer(5,900);|
WAR|	end|
WAR|end|
WAR||
WAR|on timer=5 then|
WAR|	#allowWAR = 1;|
PS|end|
PS||MaxPumpDuty function
PS|on maxPumpDuty then|Sets (water)pump speed depending on
PS|	if #allowPumpSpeed == 1 then|
PS|		#allowPumpSpeed = 0;|OM and compressor running or not
PS|		if @ThreeWay_Valve_State == 1 && @Max_Pump_Duty != 220 then|if production is HEAT or COOL the
PS|			@SetMaxPumpDuty = 220;|pumpspeed will depend on
PS|		end|@Outside_Temp as well
PS|		if @ThreeWay_Valve_State == 0 && @Heatpump_State == 1 then|
PS|			if @Outside_Temp < 10 then|
PS|				$MPF = 11;|
PS|			else|
PS|				$MPF = 10;|
PS|			end|
PS|			if @Outside_Temp < 5 then|
PS|				$MPF = 12;|
PS|			end|
PS|			if @Outside_Temp < 2 then|
PS|				$MPF = 13;|
PS|			end|
PS|			if @Compressor_Freq == 0 then|
PS|				$MPF = 8;|
PS|			end|
PS|			if @Pump_Flow < $MPF then|
PS|				#maxPumpDuty = #maxPumpDuty + 5;|
PS|			else|
PS|				if @Pump_Flow > $MPF + 1 then|
PS|					#maxPumpDuty = #maxPumpDuty - 1;|
PS|				end|
PS|			end|
PS|			if #maxPumpDuty > 140 then|
PS|				#maxPumpDuty = 140;|
PS|			end|
PS|			if @Max_Pump_Duty != #maxPumpDuty then|
PS|				@SetMaxPumpDuty = #maxPumpDuty;|
PS|			end|
PS|		end|this function runs every minute
PS|		setTimer(6, 60);|
PS|	end|
PS|end|
PS||
PS|on timer=6 then|
PS|	#allowPumpSpeed = 1;|
DHW|end|
DHW||DHW function
DHW|on checkDHW then|DHW production will start if:
DHW|	if #allowDHW == 1 then|- DHW_Temp < 39;
DHW|		#allowDHW = 0;|- DHW_Temp < DHW_Target +
DHW|		if @ThreeWay_Valve_State == 0 && (@DHW_Temp < 39 || (%hour == 13 && (%day == #LegionellaRunDay || @DHW_Temp < @DHW_Target_Temp + @DHW_Heat_Delta))) then|   DHW_Delta and %hour = 13;
DHW|			#prevOperatingMode = @Operating_Mode_State;|On Legionelladay a Legionella run
DHW|			#prevHeatPumpState = @Heatpump_State;|will be done if %hour = 13.
DHW|			@SetOperationMode = 3;|
DHW|			if @Heatpump_State != 1 then|
DHW|				@SetHeatpump = 1;|
DHW|			end|
DHW|			if %day == #legionellaRunDay then|
DHW|				@SetForceSterilization = 1;|
DHW|			end|
DHW|			#DHWRun = 1;|
DHW|		end|
DHW|		if #DHWRun == 1 then|
DHW|			if @ThreeWay_Valve_State == 0 && @DHW_Temp > 49 then|
DHW|				@SetOperationMode = #OperatingModeLast;|
DHW|				if @Heatpump_State != #HeatPumpStateLast then|
DHW|					@SetHeatpump = #HeatPumpStateLast;|
DHW|				end|
DHW|				#OperatingModeLast = 3;|
DHW|				#HeatPumpStateLast = 1;|
DHW|				#DHWRun = -1;|
DHW|			end|
DHW|		end|this function runs every 15 minutes minute
DHW|		setTimer(7,900);|
DHW|	end|
DHW|end|
DHW||
DHW|on timer=7 then|
DHW|	#allowDHW = 1;|
OTT|end|
OTT||Opentherm Thermostat function
OTT|on OTThermostat then|Switch HP on/off based on ?chEnable
OTT|	if #allowOTThermostat == 1 && #DHWRun != 1 then|& Sync HP_Target with ?chSetpoint
OTT|		if @ThreeWay_Valve_State == 0 then|Prevent update setpoint if due to some
OTT|			if ?chSetpoint > 9 then|glitches ?chSetpoint = 0 which happens
OTT|				#chSetpoint = ?chSetpoint;|sometimes.
OTT|				if #chSetpoint < 30 && #compState == 0 then|Run softStart function (if allowed)
OTT|					#chSetpoint = 30;|set #mainTargetTemp based on 
OTT|				end|#chSetpoint and #softStartCorrection
OTT|				if #chSetpoint < 27 && #compState == 1 then|(if any). Safegards to prevent Target 
OTT|					#chSetpoint = 27;|below 20 and above 40 degrees.
OTT|				end|
OTT|				if #chSetpoint > #maxTa then|
OTT|					#chSetpoint = #maxTa;|
OTT|				end|
OTT|			end|
OTT|			softStart();|
OTT|			#mainTargetTemp = #chSetpoint + #softStartCorrection;|
OTT|			if #mainTargetTemp < 27 then|
OTT|				#mainTargetTemp = 27;|
OTT|			end|
OTT|			if #mainTargetTemp > 40 then|
OTT|					#mainTargetTemp = 40;|
OTT|			end|
OTT|			#mainTargetTemp = floor(#mainTargetTemp);|
OTT|			if #compState == 1 then|safegard to prevent Target way below
OTT|				if #mainTargetTemp + 2 < @Main_Outlet_Temp then|@Main_outlet_Temp to prevent
OTT|					#mainTargetTemp = round(@Main_Outlet_Temp - 1.5);|compressor switch off.
OTT||
OTT|				end|
OTT|				if #roomTempDelta > 1 && #chEnableOffTime > 15 && @ThreeWay_Valve_State == 0 && #compRunTime > 30 then|
OTT|					#mainTargetTemp = round(@Main_Outlet_Temp - 10);|
OTT|				end|
OTT|			end|
OTT|			if @Z1_Heat_Request_Temp != #mainTargetTemp then|
OTT|				@SetZ1HeatRequestTemperature = #mainTargetTemp;|
OTT|			end|Set OM to HEAT
OTT|			if @Operating_Mode_State != 0 then|
OTT|				@SetOperationMode = 0;|
OTT|			end|Set HP on if #chEnable = 1
OTT|			if @Heatpump_State != 1 && #chEnable == 1 then|
OTT|				@SetHeatpump = 1;|
OTT|			end|
OTT|		end|Set HP off if #chEnable is off for
OTT|		if #chEnableOffTime > 15 && @ThreeWay_Valve_State == 0 && (#compRunTime > 30 || #compState == 0) && @Outside_Temp > 2 then|15 minutes & compressor is off or 
SS|			@SetHeatpump = 0;|on for more than 30 minutes
SS|		end|
SS|		if #softStartPhase == -1 || #softStartPhase > 1 then|this function runs every 30 seconds
SS|			#allowOTThermostat = 0;|(trigger from timer 1 every 15 sec.)
SS|			setTimer(8,25);|except in sSSP 0, then 15 sec.
SS|		end|
SS|	end|
SS|end|
SS||
SS|on timer=8 then|
SS|		#allowOTThermostat = 1;|
SS|end|
SS||softStart function
SS|on softStart then|This function tries to reduce the
SS|	if #allowSoftStart == 1 && #compState == 1 then|compressor frequency asap by setting
SS|		if #compRunTime == -1 then|QuietMode and reducing target temp
SS|			#softStartPhase = 0;|to temp below current water temp.
SS|		else|After this startup behavour it increases
SS|			if #compRunTime < 3 then|the target temp to prevent switch off
SS|				#softStartPhase = 1;|compressor for a set time (2 hours)
SS|				#softStartCorrection = @Main_Outlet_Temp - 1 - #chSetpoint;|After this phase it will gradualy reduce
SS|			else|the correction value which will most 
SS|				if #compRunTime < 120 then|likely lead to compressor off.
SS|					#softStartPhase = 2;|
SS|					if #chSetpoint <= @Main_Outlet_Temp then|
SS|						#softStartCorrection = @Main_Outlet_Temp - 0.7 - #chSetpoint;|
SS|					end|
SS|					if #chSetpoint > @Main_Outlet_Temp then|
SS|						#softStartCorrection = @Main_Outlet_Temp + 1 - #chSetpoint;|
SS|					end|
SS|				else|
SS|					if #softStartPhase == 2 then|
SS|						#softStartPhase = 3;|
SS|						setTimer(9,5);|
SS|					end|
SS|				end|
SS|			end|
SS|		end|
SS|		if #softStartCorrection > 5 then|
SS|			#softStartCorrection = 5;|
SS|		end|
SS|		if #softStartCorrection < -5 then|
SS|			#softStartCorrection = -5;|
SS|		end|Set @QuietMode back to 0 when
SS|		if @Compressor_Freq > 18 && @Compressor_Freq < 26 && #softStartPhase > 1 then|compressor < xx Hz
SS|			#mildMode = 0;|
SS|			setQuietMode();|
SS|		end|
SS|	end|correction when ?chenable goes to 10
SS|	if #allowSoftStart == 1 && #compState == -5 then|
SS|		#softStartCorrection = #mainTargetTemp - #chenable;|
SS|	end|
SS|end|
SS||
SS|on timer=9 then|
SS|	if #softStartCorrection > 0 then|
SS|		#softStartCorrection = #softStartCorrection - 1;|
SS|		setTimer(9,900);|
SS|	end|
OTT SS|end|
OTT SS||
OTT SS|on @Compressor_Freq then|
OTT SS|	if @Compressor_Freq > 18 then|
OTT SS|		if #compState < 1 then|
OTT SS|			#compStartTime = #timeRef;|
OTT SS|			#compState = 1;|
OTT SS|		end|
OTT SS|		#compRunTime = #timeRef - #compStartTime;|
OTT SS|		if #compRunTime < 0 then|
OTT SS|			#compRunTime = #timeRef - #compStartTime + 10080;|
OTT SS|		end|
OTT SS|	else|
OTT SS|		#compState = 0;|
OTT SS|		#softStartCorrection = 0;|
OTT SS|		#softStartPhase = -1;|Set @quietMode back to #silentmode value
OTT SS|		if #mildMode != #silentMode then|once compressor stops
OTT SS|			#mildMode = #silentMode;|
OTT SS|			setQuietMode();|
OTT SS|		end|
OTT SS|	end|
