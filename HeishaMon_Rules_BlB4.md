```LUA
on System#Boot then
	print('BLB Heishamon_rules_2512.02.lua');
	#chEnableOnMin = -1;
	#chEnableChangeTime = -1;
	#chEnableTimeOff = -1;
	#CompFreqTarget = -1;
	#CompRunSec = -1;
	#CompRunMin = -1;
	#CoolingEnable = -1;
	#DHWComfortDay = 4;
	#dhwEnable = -1;
	#DHWRun = -1;
	#DHWSterilizationDay = 7;
	#Heat = -1;
	#OMP = -1;
	#QMR = -1;
	#PIDpreverror	 = 0;
	#PIDintegral	 = 0;
	#RoomTempDelta = 0;
	#RoomTempControl = 0;
	setTimer(1,10);
	setTimer(2,30);
	setTimer(3,35);
	setTimer(4,40);
	setTimer(5,45);
	setTimer(6,50);
	setTimer(7,55);
	setTimer(8,60);
	setTimer(9,65);
	setTimer(10,32);
end

on @Compressor_Freq then
	if @Compressor_Freq > 10 && #CompState == 0 then
		#CompStateChangeTime = #Time;
		#CompState = 1;
		#CompRunSec = 0;
		#CompRunMin = 0;
		setTimer(11,5);
	elseif @Compressor_Freq < 10 && #CompState > 0 then
		#CompStateChangeTime = #Time;
		#CompState = 0;
		#CompRunMin = 0;
		#TaDeltaTimer = 0;
	end
end

on timer=1 then
	setTimer(1,60);
	#Time = %day * 1440 + %hour * 60 + %minute;
	if @Compressor_Freq > 10 then
		#CompRunMin = #Time - #CompStateChangeTime;
	else
		#CompRunMin = #CompStateChangeTime - #Time;
	end
end

on timer=2 then
	#CompStateChangeTime	 = #Time;
	#chEnableChangeTime	 = #Time;
	#HPStateR = @Heatpump_State;
	#HPStateP = @Heatpump_State;
	#OMR 	 = @Operating_Mode_State;
	#OutsideTemp = @Outside_Temp;
	#RoomSetpoint = min(max(?roomTempSet, 10), 22);
	#RoomSetpointP = #RoomSetpoint;
	#RoomTemp = 15 + ?maxRelativeModulation / 10;
	#WCS 	 = @Z1_Heat_Request_Temp;
	if @Compressor_Freq > 18 then
		#CompState = 2;
		#CompRunSec = 1999;
	else
		#CompState = 0;
	end
	if @ThreeWay_Valve_State then
		#DHWRun = 3;
	end
	#chEnable = ?chEnable;
end

on @Main_Outlet_Temp then
	if @ThreeWay_Valve_State == 0 && #CompState > 0 then
		$MOT = @Main_Outlet_Temp;
		$TaDelta = @Main_Outlet_Temp - @Z1_Heat_Request_Temp;
		if $TaDelta >= 3 then
			@SetZ1HeatRequestTemperature = ceil(@Main_Outlet_Temp) - 2;
		end
	end
end

on timer=3 then
	setTimer(3,15);
	$NoDefrost = @Defrosting_State == 0 || (@Pump_Flow > 5 && @Pump_Flow < 30);
	if #Heat && @ThreeWay_Valve_State == 0 && $NoDefrost && #DHWRun < 2 then
		$WCS = #WCS + min(max(@Z2_Heat_Request_Temp - 30,0), 5);
		#SHifT = @Z1_Heat_Request_Temp - $WCS;
		if #CompState > 0 then
			if #OutsideTemp < 8 then
				if #RoomTempDelta > 2 || %hour < 3 then
					#SHifT = -3;
				elseif #CompRunSec < 1080 then
					#SHifT = floor((#CompRunSec ^ 0.5 - 28) / 5.16);
					if #RoomTempControl < 0 then
						#SHifT = #SHifT + #RoomTempControl;
					end
				elseif #RoomTempControl > #SHifT || @Compressor_Freq > 21 then
					#SHifT = #RoomTempControl;
				end
			else
				$TaDelta = @Main_Outlet_Temp - @Z1_Heat_Request_Temp;
				if $TaDelta < 2 then
					#TaDeltaTimer = 0;
				else
					#TaDeltaTimer = #TaDeltaTimer + 1;
				end
				if $TaDelta >= 3 then
					#SHifT = ceil(@Main_Outlet_Temp) - 2 - $WCS;
				elseif #TaDeltaTimer < 5 then
					#TaDeltaTimer = #TaDeltaTimer;
				elseif (@Main_Outlet_Temp - 1.8) > (#RoomTempControl + $WCS) && (#CompRunMin < 30 || #RoomTempDelta < 0 || #chEnable == 1) then
					#SHifT = ceil(@Main_Outlet_Temp - 1.8 - $WCS);
				else
					#SHifT = #RoomTempControl;
				end
			end
		else
			$StopConditions = #CompRunMin > (-2 * #OutsideTemp - 30) || %hour < 7 || %hour > 22 || #RoomTempDelta < 0.2;
			if #CompState == 0 && $StopConditions && #CompRunMin < 2 then
				#SHifT = -5;
			else
				#SHifT = 0;
			end
		end
		#SHifT = min(max(#SHifT, -5), 5);
		$Z1HRT = $WCS + #SHifT;
		if $Z1HRT != @Z1_Heat_Request_Temp then
			@SetZ1HeatRequestTemperature = $Z1HRT;
		end
	end
end

on timer=4 then
	setTimer(4,60);
	if #Heat && @ThreeWay_Valve_State == 0 && @Defrosting_State == 0 && #DHWRun < 2 then
		$OverNight = %hour > 22 || %hour < 3;
		$HPOff1Conditions = (#RoomTempDelta > 0.7 && %hour > 9) || #RoomTempDelta > 1.5 || #chEnableOnMin < -30;
		$HPOff2Conditions = #CompRunMin > 60 || #CompState == 0 || $OverNight;
		$HPOff3Conditions = #OutsideTemp > 4 || (#chEnable == 0 && $OverNight);
		$chEnableCondition = #chEnable && #chEnableOnMin > 60 && (#CompRunMin < -60 || #CompRunMin < 60) && $OverNight != 1;
		$HPOnCondition = (((#RoomTempDelta < 0.3 || %hour == 7) && #OutsideTemp < 11) || (#RoomTempDelta < 1 && #OutsideTemp < 2) || #RoomTempDelta < 0 || $chEnableCondition);
		if #chEnable && $HPOnCondition && #HPStateR != 1 then
				#HPStateR = 1;
		elseif $HPOff1Conditions && $HPOff2Conditions && $HPOff3Conditions && $chEnableCondition == 0 && #HPStateR != 0 then
			#HPStateR = 0;
			if #OMR != 0 && #OMR != 3 then
				#OMR = 0;
			end
		end
	end
	if  #OMR && #DHWRun < 2 && #CompState == 0 then
		#OMR = 0;
		#HPStateR = 0;
	end
end

on timer=5 then
	setTimer(5,900);
	if @Defrosting_State == 0 && #dhwEnable then
		if (%month > 3 || %month < 9) && %hour == 8 && #OutsideTemp > 20 then
			$DHWTime = 8;
		else
			$DHWTime = 13;
		end
		$DHWT = %hour == $DHWTime;
		if @ThreeWay_Valve_State == 0 && (@DHW_Temp < (@DHW_Target_Temp + @DHW_Heat_Delta - 10) || (%hour > 9 && @DHW_Temp < (@DHW_Target_Temp + @DHW_Heat_Delta - 5)) || (%hour == $DHWTime && (%day == #DHWSterilizationDay || %day == 4 && @DHW_Temp < (@DHW_Target_Temp - 3) || @DHW_Temp < (@DHW_Target_Temp + @DHW_Heat_Delta)))) then
			#DHWRun = 2;
			#OMP = @Operating_Mode_State;
			#HPStateP = @Heatpump_State;
			if #OMP == 0 then
				#OMR = 4;
			elseif #OMP then
				#OMR = 5;
			else
				#OMR = 3;
			end
			#HPStateR = 1;
		end
		if #DHWRun > 0 && #DHWRun < 3 then
			if %day > (#DHWSterilizationDay - 2) && %hour > 10 && @DHW_Temp > 47 && @Sterilization_State != 1 then
				@SetForceSterilization = 1;
				#DHWSterilizationDay = #DHWSterilizationDay + 10;
			end
			if @ThreeWay_Valve_State == 0 && @DHW_Temp >= @DHW_Target_Temp && @Defrosting_State == 0 && @Sterilization_State == 1 then
				#DHWRun = 1;
			elseif @ThreeWay_Valve_State == 0 && @DHW_Temp >= @DHW_Target_Temp && @Defrosting_State == 0 && @Sterilization_State == 0 then
				#OMR = max(0,#OMP);
				#OMP = @Operating_Mode_State;
				#HPStateR = #HPStateP;
				#HPStateP = 1;
				#DHWRun = 0;
			end
		end
		if %day == (#DHWSterilizationDay - 10) && %hour > 15 then
			#DHWSterilizationDay = #DHWSterilizationDay - 10;
		end
	end
end

on timer=6 then
	setTimer(6, 60);
	$MaxPumpDuty = 82;
	if @ThreeWay_Valve_State then
		$MaxPumpDuty = 140;
		if (@Sterilization_State == 0 && @DHW_Temp > @DHW_Target_Temp) || (@Sterilization_State && @DHW_Temp > 57) then
			$MaxPumpDuty = $MaxPumpDuty - 10;
		end
	elseif @Operating_Mode_State then
		$MaxPumpDuty = 92;
	elseif @Heatpump_State then
		if @Compressor_Freq == 0 && @Defrosting_State != 1 then
			$MaxPumpDuty = 82;
		else
			$QFH = 10;
			$QFL = 16;
			$tH = 11;
			$tL = -3;
			if #OutsideTemp >= $tH then
				$MaxPumpFlow = $QFH;
			elseif #OutsideTemp <= $tL then
				$MaxPumpFlow = $QFL;
			else
				$MaxPumpFlow = ceil($QFH + ($tH - #OutsideTemp) * ($QFL - $QFH) / ($tH - $tL));
			end
			if @Pump_Flow > 1 && @Pump_Flow < 8 && $MaxPumpDuty <= @Max_Pump_Duty then
				$MaxPumpDuty = @Max_Pump_Duty + 1;
			else
				$MaxPumpDuty = 55 + floor($MaxPumpFlow * 3);
				if (@Pump_Speed / @Pump_Flow) > 145 then
					if @Pump_Flow > 8 then
						$MaxPumpDuty = @Max_Pump_Duty - 1;
					else
						$MaxPumpDuty = @Max_Pump_Duty;
					end
				end
			end
		end
	end
	$MaxPumpDuty = max($MaxPumpDuty, 82);
	if @Max_Pump_Duty != $MaxPumpDuty then
		@SetMaxPumpDuty = $MaxPumpDuty;
	end
end

on timer=7 then
	setTimer(7,120);
	if @Defrosting_State == 0 then
		if #OutsideTemp < 4 || (#OutsideTemp < 6 && #CompFreqTarget == 34) then
			#CompFreqTarget = 34;
		else
			#CompFreqTarget = 24;
		end
		if @Defrosting_State || #CompState < 1 || #CompRunMin < 10 || %hour < 7 || @Operating_Mode_State == 1 then
			#QMR = 3;
		elseif @Compressor_Freq < #CompFreqTarget || (#QMR == 0 && @Compressor_Freq < #CompFreqTarget + 6) then
			#QMR = 0;
		elseif @Compressor_Freq < #CompFreqTarget + 6 || (#QMR == 1 && @Compressor_Freq < #CompFreqTarget + 12) then
			#QMR = 1;
		elseif @Compressor_Freq < #CompFreqTarget + 26 || (#QMR == 2 && @Compressor_Freq < #CompFreqTarget + 32) then
			#QMR = 2;
		else
			#QMR = 3;
		end
		if #QMR > 0 && @ThreeWay_Valve_State && %hour > 9 && %hour < 17 then
			$QMDHW = -1;
		else
			$QMDHW = 0;
		end
		if #QMR != @Quiet_Mode_Level then
			@SetQuietMode = #QMR + $QMDHW;
		end
	end
end

on timer=8 then
	setTimer(8,30);
	?outletTemp = round(@Main_Outlet_Temp);
	?inletTemp = round(@Main_Inlet_Temp);
	?outsideTemp = round(#OutsideTemp);
	?dhwTemp = round(@DHW_Temp);
	?dhwSetpoint = @DHW_Target_Temp;
	#dhwEnable = ?dhwEnable;
	if ?chEnable then
		if #chEnable == 0 then
			#chEnableChangeTime = #Time;
		end
		#chEnableTimeOff = -1;
		#chEnable = 1;
	else
		if #chEnableTimeOff < 0 then
			#chEnableTimeOff = #Time;
		end
		if  #Time - #chEnableTimeOff > 15 && #chEnable then
			#chEnable = 0;
			#chEnableChangeTime = #Time;
		end
	end
	if #chEnable then
		#chEnableOnMin = #Time - #chEnableChangeTime;
	else
		#chEnableOnMin = #chEnableChangeTime - #Time;
	end
	?maxTSet = #WCS + 5;
	?relativeModulation = round(@Compressor_Current / 15 * 100);
	if #CompState > 0 then
		?flameState = 1;
		if @Heat_Power_Consumption > 0 then
			?chState = 1;
		else
			?chState = 0;
		end
		if @DHW_Power_Consumption > 0 then
			?dhwState = 1;
		else
			?dhwState = 0;
		end

	else
		?flameState = 0;
		?chState = 0;
		?dhwState = 0;
	end
	#RoomSetpoint = min(max(?roomTempSet, 10), 22);
	if ?maxRelativeModulation != 100 then
		#RoomTemp = 15 + ?maxRelativeModulation / 10;
	else
		#RoomTemp = #RoomSetpoint;
	end
	#RoomTempDelta = #RoomTemp - #RoomSetpoint;
	#OutsideTemp = (#OutsideTemp * 59 + @Outside_Temp) / 60;
	if @Operating_Mode_State != #OMR then
		@SetOperationMode = #OMR;
	end
	if @Heatpump_State != #HPStateR && #DHWRun != 3 then
		@SetHeatpump = #HPStateR;
	end
	if @Operating_Mode_State == 0 || @Operating_Mode_State == 4 then
		#Heat = 1;
	else
		#Heat = 0;
	end
end

on timer=9 then
	setTimer(9,300);
	if #DHWRun < 1 then
		$RoomTempDelta = #RoomTempDelta * -1;
		if (#RoomSetpoint > #RoomSetpointP && #RoomTempDelta < 0) || (#RoomSetpoint < #RoomSetpointP && #RoomTempDelta < -1) then
			#PIDintegral = 0;
		else
			#PIDintegral = min(max((#PIDintegral + $RoomTempDelta), -50), 50);
		end
		$PIDKp = 3;$PIDKi = 0.1;$PIDKd = 0.2;
		$P = $PIDKp * $RoomTempDelta;$I = $PIDKi * #PIDintegral;$D = $PIDKd * ($RoomTempDelta - #PIDpreverror);
		$PIDoutput = $P + $I + $D;
		if $RoomTempDelta == 0 || $RoomTempDelta > #PIDpreverror + 0.2 || $RoomTempDelta < #PIDpreverror - 0.2 then
			#PIDpreverror = $RoomTempDelta;
		end	
		#RoomTempControl = round($PIDoutput);
		#RoomSetpointP = #RoomSetpoint;
	end
end

on timer=10 then
	setTimer(10,1800);
	$Ta1 = @Z1_Heat_Curve_Target_Low_Temp;
	$Tb1 = @Z1_Heat_Curve_Outside_High_Temp;
	$Ta2 = 34;
	$Tb2 = @Z1_Heat_Curve_Outside_Low_Temp;
	if #OutsideTemp >= $Tb1 then
		#WCS = $Ta1;
	elseif #OutsideTemp <= $Tb2 then
		#WCS = $Ta2;
	else
		#WCS = ceil($Ta1 + (($Tb1 - #OutsideTemp) * ($Ta2 - $Ta1) / ($Tb1 - $Tb2)));
	end
end

on timer=11 then
	#CompRunSec = #CompRunSec + 5;
	if #CompRunSec < 1100 then
		setTimer(11,5);
	end
end
```
