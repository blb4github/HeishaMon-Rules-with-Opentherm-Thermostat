```LUA
on System#Boot then
	#aDHW = 1;
	#aOTThermostat = 1;
	#aPumpSpeed = 1;
	#aSilentMode = 1;
	#aSoftStart = 1;
	#aSyncOT = 1;
	#aWAR = 1;

	#debug = 1;

	#deltaHeat = 5;
	#legionellaRunDay = 7;
	#maxPumpDuty = 85;
	#maxTa = 40;

	#chE = -1;
	#chEOffTime = -1;
	#chETimeOff = -1;
	#chSetPoint = -1;
	#compRunTime = -1;
	#compStartTime = -1;
	#compState = -1;
	#DHWRun = -1;
	#firstBoot = 1;	#mTT = -1;
	#mildMode = -1;
	#pHPS = -1;
	#pOM = -1;
	#quietMode = -1;
	#roomTempDelta = -1;
	#sSC = -1;
	#sSP = -1;
	#thermostatState = -1;
	#timeRef = -1;

	setTimer(1,60);
	setTimer(2,10);
end

on quietMode then
	if #mildMode > -1 then
		#quietMode = #mildMode;
	else
		#quietMode = #silentMode;
	end
	if @Quiet_Mode_Level != #quietMode then
		@SetQuietMode = #quietMode;
	end
end

on softStart then
	if #aSoftStart == 1 && #compState == 1 then
		$mOT = @Main_Outlet_Temp;
		$chSP = #chSetpoint;
		if #compRunTime < 3 then
			#sSP = 1;
			#sSC = floor($mOT) - 1 - $chSP;
		else
			if #compRunTime < 180 then
				#sSP = 2;
				if @Compressor_Freq < 22 then
					if $chSP <= $mOT then
						#sSC = $mOT + 0 - $chSP;
					end
					if $chSP > $mOT then
						#sSC = $mOT + 1 - $chSP;
					end
					if $chSP > ($mOT + 1.0) then
						#sSC = $mOT + 2 - $chSP;
					end
				else
					if $chSP <= ($mOT + 0.5) then
						#sSC = $mOT - 0.7 - $chSP;
					end
					if $chSP > ($mOT + 0.5) then
						#sSC = $mOT + 1 - $chSP;
					end
				end
			else
				if #sSP == 2 then	#sSP = 3;	setTimer(8,5);	end
			end
		end
		if #sSC > 5 then
			#sSC = 5;
		end
		if #sSC < -7 then
			#sSC = -7;
		end
		#mTT = $chSP + #sSC;
		if #mTT < 24 then
			#mTT = 24;
		end
		if #mTT > 40 then
			#mTT = 40;
		end
		#mTT = floor(#mTT);
		if (#mTT + 2) < $mOT then
			#mTT = #mTT + 1;
		end
		if @Compressor_Freq > 18 && @Compressor_Freq < 25 then
			#mildMode = 0;
			quietMode();
		end
		if #compRunTime < 8 then
			$dH = #deltaHeat - 2;
		else
			$dH = #deltaHeat;
		end
		if @Heat_Delta != $dH then
			@SetFloorHeatDelta = $dH;
		end
	end
end

on OTThermostat then
	if #aOTThermostat == 1 && #DHWRun < 1 && @ThreeWay_Valve_State == 0 then
		if #thermostatState == 1 then
			if ?chSetpoint > 9 then
				if ?chSetpoint < 20 then	#chSetpoint = 20;
				else	#chSetpoint = ?chSetpoint;	end
				if #chSetpoint < 30 && #chE == 1 && #compState == 0 then	#chSetpoint = 30;	end
				if #chSetpoint < 27 && #compState == 1 then	#chSetpoint = 27;	end
				if #chSetpoint > #maxTa then	#chSetpoint = #maxTa;	end
			end
			#mTT = #chSetpoint;
			softStart();
			if #compState == 1	then
				#roomTempDelta = ?roomTempSet - ?roomTemp;
				if ((#roomTempDelta > 0.5 && #chE == 0) || #chEOffTime > 15) && @ThreeWay_Valve_State == 0 && #compRunTime > 30 then
					#mTT = round(@Main_Outlet_Temp - 10);
				end
			end
			if @Z1_Heat_Request_Temp != #mTT then	@SetZ1HeatRequestTemperature = #mTT;	end
			if @Heatpump_State != 1 && #chE == 1 then	@SetHeatpump = 1;	end
			if #chEOffTime > 30 && @ThreeWay_Valve_State == 0 && (#compRunTime > 30 || #compState == 0) && @Outside_Temp > 2 then
				@SetHeatpump = 0;
				#aOTThermostat = 0;
				setTimer(7,600);
			end
			if (#sSP == -1 && #chE == 0) || #sSP > 1 then
				#aOTThermostat = 0;
				setTimer(7,25);
			end
		else
			#mTT = #maxTA;
			if @Z1_Heat_Request_Temp != #mTT then	@SetZ1HeatRequestTemperature = #mTT;	end
			if (%hour > 22 || %hour < 7) && @Heatpump_State == 1 then	@SetHeatpump = 0;	end
			if (%hour < 23 || %hour > 6) && @Heatpump_State == 0 then	@SetHeatpump = 1;	end
			#aOTThermostat = 0;
			setTimer(7,55);
		end
	end
end

on DHW then
	if #aDHW == 1 then
		#aDHW = 0;
		if @ThreeWay_Valve_State == 0 && (@DHW_Temp < 39 || (%hour == 13 && (%day == #LegionellaRunDay || @DHW_Temp < (@DHW_Target_Temp + @DHW_Heat_Delta)))) then
			#DHWRun = 1;
			#pOM = @Operating_Mode_State;
			#pHPS = @Heatpump_State;
			@SetOperationMode = 4;
			if @Heatpump_State != 1 then
				@SetHeatpump = 1;
			end
		end
		if #DHWRun == 1 then
			if %day == #legionellaRunDay && %hour >= 13 && @DHW_Temp > 47 && @Sterilization_State != 1 then
				@SetForceSterilization = 1;
			end
			if @ThreeWay_Valve_State == 0 && @DHW_Temp >= @DHW_Target_Temp && @Defrosting_State == 0 && @Sterilization_State == 0 then
				@SetOperationMode = #pOM;
				if @Heatpump_State != #pHPS then	@SetHeatpump = #pHPS;	end
				#pOM = 4;
				#pHPS = 1;
				#DHWRun = -1;
			end
		end
		setTimer(6,900);
	end
end

on pumpDuty then
	if #aPumpSpeed == 1 then
		#aPumpSpeed = 0;
		$pFM = @Pump_Flowrate_mode;
		if @ThreeWay_Valve_State == 1 then
			$mPD = #maxPumpDuty;
			if @DHW_Temp <= @DHW_Target_Temp then
				if @Max_Pump_Duty != 140 then	$mPD = 140;	end
			else
				if @Max_Pump_Duty != ($mPD + 5) then	$mPD = $mPD + 5;	end
			end
		end
		if @ThreeWay_Valve_State == 0 then
			if @Heatpump_State == 1 then
				$mPD = @Max_Pump_Duty;
				if @Outside_Temp < 10 then	$mPF = 11;
				else	$mPF = 10;	end
				if @Outside_Temp < 5 then	$mPF = 12;	end
				if @Outside_Temp < 2 then	$mPF = 13;	end
				if @Compressor_Freq == 0 then	$mPF = 8;	end
				if $pFM == 1 then
					if @Pump_Flow < $mPF then
						$mPD = $mPD + 5;
					else
						if @Pump_Flow > ($mPF + 1) then	$mPD = $mPD - 1;	end
					end
				else
					$mPD = floor($mPF * 10.5);
				end
				if $mPD > 140 then	$mPD = 140;	end
			else
				$mPD = #maxPumpDuty;
			end
		end
		if @Max_Pump_Duty != $mPD then	@SetMaxPumpDuty = $mPD;	end
		setTimer(5, 60);
	end
end

on silentMode then
	if #aSilentMode == 1 then
		#aSilentMode = 0;
		if @Outside_Temp > 9 then
			#silentMode = 3;
		else
			if @Outside_Temp > 4 then
				#silentMode = 2;
			else
				if @Outside_Temp > 1 then
					if %hour > 22 || %hour < 7 then	#silentMode = 1;
					else	#silentMode = 0;	end
				end
			end
		end
		setTimer(3, 900);
		quietMode();
	end
end

on syncOpenTherm then
	if  #aSyncOT == 1 then
		?outletTemp = @Main_Outlet_Temp;
		?inletTemp = @Main_Inlet_Temp;
		?outsideTemp = @Outside_Temp;
		?dhwTemp = @DHW_Temp;
		?dhwSetpoint = @DHW_Target_Temp;
		if isset(?chEnable) && isset(?chSetpoint) && isset(?roomTempSet) && isset(?roomTemp) && ?roomTempSet != 0 && ?roomTemp != 0 then
			#thermostatState = 1;
		end
		if ?chEnable == 1 then
			#chE = 1;
			if #chETimeOff != -1 then
				#chETimeOff = -1;
				#chEOffTime = -1;
			end
		else
			if #chETimeOff == -1 then	#chETimeOff = #timeRef;	end
			#chEOffTime = #timeRef - #chETimeOff;
			if #chEOffTime < 0 then	#chEOffTime = #timeRef - #chETimeOff + 10080;	end
			if #chEOffTime > 5 || ?chSetpoint == 10 then	#chE = 0;	end
		end
		#dhwEnable = ?dhwEnable;
		if #maxTa != -1 then	?maxTSet = #maxTa;	end
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
	if #aWAR == 1 then
		#aWAR = 0;
		$Ta1 = @Z1_Heat_Curve_Target_Low_Temp;
		$Tb1 = @Z1_Heat_Curve_Outside_High_Temp;
		if @Heating_Mode == 1 then	$Ta2 = 36;
		else	$Ta2 = @Z1_Heat_Curve_Target_High_Temp;	end
		$Tb2 = @Z1_Heat_Curve_Outside_Low_Temp;
		if @Outside_Temp >= $Tb1 then
			#maxTa = $Ta1;
		else
			if @Outside_Temp <= $Tb2 then	#maxTa = $Ta2;
			else	#maxTa = floor(0.9 + $Ta1 + (($Tb1 - @Outside_Temp) * ($Ta2 - $Ta1) / ($Tb1 - $Tb2)));	end
		end
		setTimer(4,1800);
	end
end

on mildMode then
		if #mildMode != #silentMode && #mildMode != -1 && #silentMode != 1 then
			#mildMode = #silentMode;
			quietMode();
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
		#sSP = -1;
		mildMode();
	end
end

on @Compressor_Freq then	compFreq();	end

on @Defrosting_State then
	if @Defrosting_State == 1 then	mildMode();	end
end

on timer=1 then
	if #firstBoot == 1 then
		if @Compressor_Freq > 18 then
			#compStartTime = #timeRef;
			#compState = 1;
		end
		#sSC = 0;
		compFreq();
		WAR();
		syncOpenTherm();
		#firstBoot = 0;
	else
		WAR();
		silentMode();
		syncOpenTherm();
		pumpDuty();
		DHW();
		OTThermostat();
		if #debug == 1 then
			$chEnable = #chE;
			$chEnableTimeOff = #chETimeOff;
			$chEnableOffTime = #chEOffTime;
			$chSetPoint = ?chSetPoint;
			$compRunTime = #compRunTime;
			$compState = #compState;
			$maxTa = #maxTa;
			$mildMode = #mildMode;
			$quietMode = #quietMode;
			$roomTempDelta = #roomTempDelta;
			$softStartCorrection = #sSC;
			$softStartPhase = #sSP;
			$thermostatState = #thermostatState;
			$mainTargetTemp = #mTT;
			$maxPumpDuty = @Max_Pump_Duty;
			$pumpDuty = @Pump_Duty;
		end
	end
	setTimer(1,15);
end

on timer=2 then	#timeRef = %day * 1440 + %hour * 60 + %minute;	setTimer(2,60);	end

on timer=3 then	#aSilentMode = 1;	end

on timer=4 then	#aWAR = 1;	end

on timer=5 then	#aPumpSpeed = 1;	end

on timer=6 then	#aDHW = 1;	end

on timer=7 then	#aOTThermostat  = 1;	end

on timer=8 then
	if #sSC > 1 then	#sSC = #sSC - 1;	setTimer(8,900);	end
end
```
