```LUA
on System#Boot then
	print('BLB Heishamon_rules_2602.22d.lua');
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
		setTimer(11,1);
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
		if #CompRunMin < 0 then	#CompRunMin = #Time - #CompStateChangeTime + 10080;end
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
	#DHWTempP = @DHW_Temp;
end

on @Main_Outlet_Temp then
	TaShift();
end

on timer=3 then
	$t3Timer = 60;
	if #CompRunSec < 150 then
		$t3Timer = 15;
	end
	setTimer(3,$t3Timer);
	TaShift();
end

on TaShift then
	#NoDefrost = @Defrosting_State == 0 || (@Pump_Flow > 5 && @Pump_Flow < 30);
	if #Heat && @ThreeWay_Valve_State == 0 && #DHWRun < 2 && #NoDefrost then
		if #CompState > 0 then
			$WCS = #WCS + min(max(@Z2_Heat_Request_Temp - 20,-5), 5);
			#TaDelta = @Main_Outlet_Temp - @Z1_Heat_Request_Temp;
			if #OutsideTemp > 7 && #CompRunSec < 150 && #CompRunSec != -1 then
				#SHifT = ceil(@Main_Outlet_Temp) - 3 - $WCS;
			else
				#SHifT = max(#RoomTempControl,ceil(@Main_Outlet_Temp) - 2 - $WCS);
			end
			if #TaDelta < 2 then
				#TaDeltaTimer = 0;
			elseif #TaDeltaTimer == 0 then
				setTimer(12,10);
			elseif #TaDeltaTimer >= 180 then
				#SHifT = ceil(@Main_Outlet_Temp - 1.8 - $WCS);
			end
			if #TaDelta >= 3 then
				#SHifT = ceil(@Main_Outlet_Temp) - 2 - $WCS;
			end
		elseif (#CompRunMin > (-2 * #OutsideTemp - 30) || %hour < 7 || %hour > 22 || #RoomTempDelta > 0.2) then
			#SHifT = -5;
		else
			#SHifT = 0;
		end
		#SHifT = min(max(#SHifT, -5), 5);
		$Z1HRT = max($WCS + #SHifT,27);
		if @Z2_Heat_Request_Temp > 25 then
			$Z1HRT = @Z2_Heat_Request_Temp;
		end
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
		$chEnableCondition = #chEnable && #chEnableOnMin > 60 && #CompRunMin < -60 && $OverNight != 1;
		$HPOnCondition = (((#RoomTempDelta < 0.3 || %hour == 7) && #OutsideTemp < 11) || (#RoomTempDelta < 1 && #OutsideTemp < 2) || #RoomTempDelta < 0 || ($chEnableCondition && #RoomTempDelta < 2));
		if #chEnable && $HPOnCondition && #HPStateR != 1 then
				#HPStateR = 1;
		elseif $HPOff1Conditions && $HPOff2Conditions && $HPOff3Conditions && $chEnableCondition == 0 && #HPStateR != 0 then
			#HPStateR = 0;
			if #OMR != 0 && #OMR != 3 then
				#OMR = 0;
			end
		end
	end
	$CoolingEnable = max(round(#CoolingEnable),0);
	if $CoolingEnable && #DHWRun < 2 then
		#OMR = 1;
		#HPStateR = 1;
		if #CompState then
			$CoolReqTempMin = min(round(@Main_Outlet_Temp), 19);
		else 
			$CoolReqTempMin = 0;
		end
		if @Z1_Cool_Request_Temp != ?coolingControl then
			@SetZ1CoolRequestTemperature = max(?coolingControl, 12, $CoolReqTempMin);
		end
	elseif $CoolingEnable == 0 && #OMR && #DHWRun < 2 && #CompState == 0 then
		#OMR = 0;
		#HPStateR = 0;
	end
end

on timer=5 then
	setTimer(5,900);
	if @Defrosting_State == 0 && #dhwEnable then
		$DHWTime = 13;
		if (%month > 3 || %month < 9) && %hour == 8 && #OutsideTemp > 20 then
			$DHWTime = 8;
		elseif #OutsideTemp < 4 then
			$DHWTime = 0;
		end
		if @ThreeWay_Valve_State == 0 && (@DHW_Temp < (@DHW_Target_Temp + @DHW_Heat_Delta - 10) || (%hour > 9 && (@DHW_Temp < (@DHW_Target_Temp + @DHW_Heat_Delta - 5) || @DHW_Temp < #DHWTempP - 5 )) || (%hour == $DHWTime && ((%day == #DHWSterilizationDay && @DHW_Temp < 63) || %day == 4 && @DHW_Temp < (@DHW_Target_Temp - 3) || @DHW_Temp < (@DHW_Target_Temp + @DHW_Heat_Delta)))) then
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
		elseif #DHWRun > 0 && #DHWRun < 3 then
			if %day > (#DHWSterilizationDay - 2) && @ThreeWay_Valve_State == 1 && 
				#CompState > 0 && @Sterilization_State != 1 then
				@SetForceSterilization = 1;
				#DHWSterilizationDay = #DHWSterilizationDay + 10;
			elseif @ThreeWay_Valve_State == 0 && @DHW_Temp >= @DHW_Target_Temp && @Defrosting_State == 0 && @Sterilization_State == 1 then
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
		#DHWTempP = @DHW_Temp;
	end
end

on timer=6 then
	setTimer(6, 60);
	$MaxPumpDuty = 102 - 4 * @Heat_Delta;
	if @ThreeWay_Valve_State then
		$MaxPumpDuty = 140;
		if (@Sterilization_State == 0 && @DHW_Temp > @DHW_Target_Temp) || (@Sterilization_State && @DHW_Temp > 57) then
			$MaxPumpDuty = $MaxPumpDuty - 10;
		end
	elseif @Operating_Mode_State then
		$MaxPumpDuty = 92;
	elseif @Heatpump_State then
		if @Compressor_Freq == 0 && @Defrosting_State != 1 then
			$MaxPumpDuty = 102 - 4 * @Heat_Delta;
		else
			$MaxPumpFlow = min(max(ceil(10 + (11 - #OutsideTemp) * 6 / 14), 10), 16);
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
	#CompFreqTarget = min(max(ceil(24 + (6 - #OutsideTemp) * 30 / 9), 24), 54);
	if @Defrosting_State || #CompState < 1 || #CompRunMin < 5 || %hour < 7 || @Operating_Mode_State == 1 then
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
	$QMDHW = 0;
	if #QMR > 0 && @ThreeWay_Valve_State && %hour > 9 && %hour < 17 then
		$QMDHW = -1;
	end
	if @Buffer_Tank_Delta < 4 then
		@SetQuietMode = @Buffer_Tank_Delta;
	elseif #QMR != @Quiet_Mode_Level then
		@SetQuietMode = #QMR + $QMDHW;
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
	#CoolingEnable = #CoolingEnable + 0.1 * (?CoolingEnable - #CoolingEnable);
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
		if @Cool_Power_Consumption > 0 then
			?coolingState = 1;
		else	
			?coolingState = 0;
		end
	else
		?flameState = 0;
		?chState = 0;
		?dhwState = 0;
		?coolingState = 0;
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
		$PIDoutput = 3 * $RoomTempDelta + 0.1 * #PIDintegral + 0.2 * ($RoomTempDelta - #PIDpreverror);
		if $RoomTempDelta == 0 || $RoomTempDelta > #PIDpreverror + 0.2 || $RoomTempDelta < #PIDpreverror - 0.2 then
			#PIDpreverror = $RoomTempDelta;
		end	
		#RoomTempControl = round($PIDoutput);
		#RoomSetpointP = #RoomSetpoint;
	end
end

on timer=10 then
	setTimer(10,1800);
	$Ta2 = 36;
	#WCS = min(max(ceil(@Z1_Heat_Curve_Target_Low_Temp + (@Z1_Heat_Curve_Outside_High_Temp - #OutsideTemp) * ($Ta2 - @Z1_Heat_Curve_Target_Low_Temp) / (@Z1_Heat_Curve_Outside_High_Temp - @Z1_Heat_Curve_Outside_Low_Temp)),@Z1_Heat_Curve_Target_Low_Temp), $Ta2);
end

on timer=11 then
	#CompRunSec = #CompRunSec + 5;
	if #CompRunSec < 1100 then
		setTimer(11,5);
	end
end

on timer=12 then
	$t12Timer = 10;
	if #TaDeltaTimer < 200 && #TaDelta >= 2 then
		#TaDeltaTimer = #TaDeltaTimer + $t12Timer;
		setTimer(12,$t12Timer);
	end
end
```
