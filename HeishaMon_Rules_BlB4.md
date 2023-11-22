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

on mildMode then
		if #mildMode != #silentMode && #mildMode != -1 && #silentMode != 1 then
			#mildMode = #silentMode;
			quietMode();
		end
end

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
		mildMode();
	end
end

on @Compressor_Freq then
	compFreq();
end

on @Defrosting_State then
	if @Defrosting_State == 1 then
		mildMode();
	end
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

on timer=3 then
	#allowSilentMode = 1;
end

on timer=4 then
	#allowWAR = 1;
end

on timer=5 then
	#allowPumpSpeed = 1;
end

on timer=6 then
	#allowDHW = 1;
end

on timer=7 then
	#allowOTThermostat  = 1;
end

on timer=8 then
	if #sSC > 1 then
		#sSC = #sSC - 1;
		setTimer(8,900);
	end
end
```
