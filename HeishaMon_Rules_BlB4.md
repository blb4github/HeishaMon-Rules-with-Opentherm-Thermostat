```LUA
on System#Boot then
	#allowDHW = 1;
	#allowOTT = 1;
	#allowExtRunTime = 1;
	#allowPumpSpeed = 1;
	#allowSilentMode = 1;
	#allowSyncOT = 1;
	#allowWAR = 1;

	#legionellaRunDay = 7;
	#maxPDuty = 85;
	#maxTa = 40;

	#chE = -1;
	#chEOffTime = -1;
	#chETimeOff = -1;
	#compRunTime = -1;
	#compStartTime = -1;
	#compState = -1;
	#dayTime = -1;
	#DHWRun = -1;
	#firstBoot = 1;
	#operatingMode = -1;
	#prevHPS = -1;
	#prevOM = -1;
	#roomTDelta = -1;
	#silentMode = -1;
	#timeRef = -1;

	setTimer(1,60);
	setTimer(2,10);
end

on eXtRunTime then
	if #allowExtRunTime == 1 then
		#allowExtRunTime = 2;
		$hM = @Heating_Mode;
		$oST = @Outside_Temp;
		$hRT = @Z1_Heat_Request_Temp;
		if $hM == 1 then
			$hRT = $hRT - #maxTA;
		end
		$mOT = @Main_Outlet_Temp;
		$mTT = @Main_Target_Temp;
		if #compState == 1 then
			if $oST > 7 && #compRunTime > 10 then
				if $mOT > (1.6 + $mTT) then
					$hRT = 1 + $hRT;
				else
					if $mOT < (0.5 + $mTT) && $hRT > 0 then
						$hRT = -1 + $hRT;
					end
				end
				if $hRT > 2 then
					$hRT = 2;
				end
				if $hRT < -1 then
					$hRT = -1;
				end
			end
		else
			$hRT = 0;
		end
		if $hM == 1 then
			$hRT = #maxTA + $hRT;
		end
		if $hRT != @Z1_Heat_Request_Temp then
			@SetZ1HeatRequestTemperature = $hRT;
		end
	setTimer(8,60);
	end
end

on OTT then
	if #allowOTT == 1 && #DHWRun < 1 && #3WVS == 0 && @Defrosting_State == 0 then
		if @Heatpump_State != 1 && #chE == 1 then
			@SetHeatpump = 1;
		end
		if #chEOffTime > 30 && #3WVS == 0 && (#compRunTime > 30 || #compState == 0) && @Outside_Temp > 2 then
			@SetHeatpump = 0;
			if  @Operating_Mode_State != 0 then
				@SetOperationMode = 0;
			end
			#allowOTT = 0;
			setTimer(7,600);
		end
		if #chE == 0 then
			#allowOTT = 0;
			setTimer(7,25);
		end
	end
end

on DHW then
	if #allowDHW == 1 then
		#allowDHW = 0;
		if #3WVS == 0 && (@DHW_Temp < 37 || (%hour == 13 && (%day == #legionellaRunDay || @DHW_Temp < (@DHW_Target_Temp + @DHW_Heat_Delta)))) then
			#DHWRun = 1;
			#prevOM = @Operating_Mode_State;
			#prevHPS = @Heatpump_State;
			@SetOperationMode = 4;
			if @Heatpump_State != 1 then
				@SetHeatpump = 1;
			end
		end
		if #DHWRun > 0 then
			if %day == #legionellaRunDay && %hour >= 13 && @DHW_Temp > 47 && @Sterilization_State != 1 then
				@SetForceSterilization = 1;
			end
			if #3WVS == 0 && @DHW_Temp >= @DHW_Target_Temp && @Defrosting_State == 0 && @Sterilization_State == 0 then
				@SetOperationMode = #prevOM;
				if @Heatpump_State != #prevHPS then
					@SetHeatpump = #prevHPS;
				end
				#prevOM = 4;
				#prevHPS = 1;
				#DHWRun = 0;
			end
		end
		#operatingMode = @Operating_Mode_State;
		setTimer(6,900);
	end
end

on pumpDuty then
	if #allowPumpSpeed == 1 then
		#allowPumpSpeed = 0;
		$pFM = @Pump_Flowrate_mode;
		if #3WVS == 1 then
			$mPD = 140;
			$oST = @Outside_Temp;
			if (@Sterilization_State == 0 && @DHW_Temp > @DHW_Target_Temp) || (@Sterilization_State == 1 && @DHW_Temp > 57) then
				$mPD = 10 + #maxPDuty;
			end
		else
			if @Heatpump_State == 1 then
				$mPD = @Max_Pump_Duty;
				if @Compressor_Freq == 0 && @Defrosting_State != 1 then
					$mPF = 8;
				else
					$fH = 10;		$fL = 14;		$tH = 11;		$tL = -3;
					if $oST >= $tH then
						$mPF = $fH;
					else
						if $oST <= $tL then
							$mPF = $fL;
						else
							$mPF = 1 + floor(0.9 + $fH + (($tH - $oST) * ($fL - $fH) / ($tH - $tL)));
						end
					end
				end
				if $pFM == 1 then
					if @Pump_Flow < $mPF then
						$mPD = $mPD + 3;
					else
						if @Pump_Flow > ($mPF + 1) then
							$mPD = $mPD - 1;
						end
					end
				else
					$mPD = 55+ floor($mPF * 3);
				end
			else
				$mPD = #maxPDuty;
			end
		end
		if @Max_Pump_Duty != $mPD then
			@SetMaxPumpDuty = $mPD;
		end
		setTimer(5, 60);
	end
end

on quietMode then
	$qM = @Quiet_Mode_Level;
	if $qM != #silentMode then
		@SetQuietMode = #silentMode;
	end
end

on silentMode then
	if #allowSilentMode == 1 && @Defrosting_State == 0 then
		#allowSilentMode = 2;
		$cF = @Compressor_Freq;
		$qM = @Quiet_Mode_Level;
		if #compRunTime < 3 then
			#silentMode = 3;
		else
			if $cF < 24 || ($qM == 0 && $cF < 27) then
				#silentMode = 0;
			else
				if $cF < 30 || ($qM == 1 && $cF < 33) then
					#silentMode = 1;
				else
					if $cF < 50 || ($qM == 2 && $cF < 53) then
						#silentMode = 2;
					else
						#silentMode = 3;
					end
				end
			end
		end
		if #silentMode > 1 && #3WVS == 1 && #dayTime == 1 then
			#silentMode = -1 + #silentMode;
		end 
		quietMode();
		setTimer(3,120);
	end
end

on syncOT then
	if  #allowSyncOT == 1 then
		?outletTemp = @Main_Outlet_Temp;
		?inletTemp = @Main_Inlet_Temp;
		?outsideTemp = @Outside_Temp;
		?dhwTemp = @DHW_Temp;
		?dhwSetpoint = @DHW_Target_Temp;
		if ?chEnable == 1 then
			#chE = 1;
			if #chETimeOff != -1 then
				#chETimeOff = -1;
				#chEOffTime = -1;
			end
		else
			if #chETimeOff == -1 then
				#chETimeOff = #timeRef;
			end
			#chEOffTime = #timeRef - #chETimeOff;
			if #chEOffTime < 0 then
				#chEOffTime = #timeRef - #chETimeOff + 10080;
			end
			if (#chEOffTime > 5 || ?chSetpoint == 10) then
				#chE = 0;
			end
		end
		?maxTSet = #maxTa;
		if @Compressor_Freq == 0 then
			?flameState = 0;
			?chState = 0;
			?dhwState = 0;
		else
			?flameState = 1;
			if @Defrosting_State == 0 then
				if #3WVS == 0 then
					?chState = 1;
					?dhwState = 0;
				else
					?chState = 0;
					?dhwState = 1;
				end
			else
				?chState = 0;
				?dhwState = 0;
			end
		end
		#roomTDelta = ?roomTempSet - ?roomTemp;
	end
end

on WAR then
	if #allowWAR == 1 then
		#allowWAR = 0;
		$oST = @Outside_Temp;
		$Ta1 = @Z1_Heat_Curve_Target_Low_Temp;
		$Tb1 = @Z1_Heat_Curve_Outside_High_Temp;
		if @Heating_Mode == 1 then
			$Ta2 = 36;
		else
			$Ta2 = @Z1_Heat_Curve_Target_High_Temp;
		end
		$Tb2 = @Z1_Heat_Curve_Outside_Low_Temp;
		if $oST >= $Tb1 then
			#maxTa = $Ta1;
		else
			if $oST <= $Tb2 then
				#maxTa = $Ta2;
			else
				#maxTa = floor(0.9 + $Ta1 + (($Tb1 - $oST) * ($Ta2 - $Ta1) / ($Tb1 - $Tb2)));
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
	end
end

on @Compressor_Freq then
	compFreq();
end

on @Defrosting_State then
	if @Defrosting_State == 1 && #allowSilentMode > 0 then
		#silentMode = 3;
		quietMode();
	end
end

on @Operating_Mode_State then
	$oMS = @Operating_Mode_State;
	if $oMS != #operatingMode && $oMS > 2 && $oMS < 5 then
		#DHWRun = 2;
	end
end

on timer=1 then
	#3WVS = @ThreeWay_Valve_State;
	if #firstBoot == 1 then
		if @Compressor_Freq > 18 then
			#compStartTime = #timeRef;
			#compState = 1;
		end
		if #3WVS == 1 && #allowDHW == 1 then
			#DHWRun = 2;
		end
		compFreq();
		WAR();
		syncOT();
		#firstBoot = 2;
	else
		WAR();
		silentMode();
		syncOT();
		pumpDuty();
		DHW();
		OTT();
		eXtRunTime();
	end
	setTimer(1,15);
end

on timer=2 then
	#timeRef = %day * 1440 + %hour * 60 + %minute;
	if %hour > 9 && %hour < 17 then
		#dayTime = 1;
	else
		#dayTime = 0;
	end
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
	#allowOTT  = 1;
end

on timer=8 then
	#allowExtRunTime  = 1;
end
```
