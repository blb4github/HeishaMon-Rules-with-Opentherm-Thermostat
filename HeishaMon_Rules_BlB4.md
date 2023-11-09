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
	#firstBoot = 1;
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
	setTimer(1,60);
	setTimer(2,10);
end

on timer=1 then
	if #firstBoot == 1 then
		#firstBoot = 0;
		compressorFreq();
		calculateWAR();
		syncOpenTherm();
	else
		calculateWAR();
		setSilentMode();
		syncOpenTherm();
		setMaxPumpDuty();
		checkDHW();
		OTThermostat();
	end
	setTimer(1,15);
end

on timer=2 then
	#timeRef = %day * 1440 + %hour * 60 + %minute;
	setTimer(2,60);
end

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

on softStart then
	if #allowSoftStart == 1 && #compState == 1 then
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
		if #softStartCorrection > 5 then
			#softStartCorrection = 5;
		end
		if #softStartCorrection < -5 then
			#softStartCorrection = -5;
		end
		if @Compressor_Freq > 18 && @Compressor_Freq < 26 then
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

on @Compressor_Freq then
	compressorFreq();
end

on compressorFreq then
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
		if #mildMode != #silentMode && #mildMode != -1 && #silentMode != 1 then
			#mildMode = #silentMode;
			setQuietMode();
		end
	end
end
```