```LUA
on System#Boot then
	print('BLB Heishamon_rules20250816b.lua');
	#chEnable = -1;
	#chEnableOffTime = -1;
	#chEnableTimeOff = -1;
	#CompFreqTarget = -1;
	#CompRunSec = -1;
	#CompRunTime = -1;
	#CoolingEnable = -1;
	#DHWComfortDay = 4;
	#dhwEnable = -1;
	#DHWRun = -1;
	#DHWSterilizationDay = 7;
	#ExternalOverRide = 0;
	#Heat = -1;
	#LastCRTUpdate = -1;
	#MaxPumpDuty = -1;
	#MOT = -1;
	#OMP = -1;
	#QMR = -1;
	#PIDKp		 = 2;
	#PIDKi		 = 0.1;
	#PIDKd		 = 0.2;
	#PIDpreverror	 = 0;
	#PIDintegral	 = 0;
	#PIDoutput	 = 0;
	#RoomTempDelta = 0;
	#RoomTempControl = 0;
	#SHifT = 0;
	#SoftStartControl = 0;
	#Time = -1;
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
		setTimer(11,5);
	elseif @Compressor_Freq < 10 && #CompState > 0 then
		#CompStateChangeTime = #Time;
		#CompState = 0;
	end
end

on timer=1 then
	setTimer(1,60);
	#Time = %day * 1440 + %hour * 60 + %minute;
	if @Compressor_Freq > 10 then
		#CompRunTime = #Time - #CompStateChangeTime;
		if #CompRunTime < 0 then	#CompRunTime = #Time - #CompStateChangeTime + 10080;end
	else	#CompRunTime = #CompStateChangeTime - #Time;end
end

on timer=2 then
	#CompStateChangeTime	 = #Time;
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
	if @ThreeWay_Valve_State then #DHWRun = 2;end
end

on timer=3 then
	setTimer(3,30);
	$NoDefrost = @Defrosting_State == 0 || (@Pump_Flow > 5 && @Pump_Flow < 30);
	if #Heat && @ThreeWay_Valve_State == 0 && $NoDefrost && #DHWRun < 1 then
		#SHifT = @Z1_Heat_Request_Temp - #WCS;
		if #CompState > 0 then
			if #OutsideTemp < 8 then
				if #RoomTempDelta > 1 || %hour < 3 then
					#SHifT = -3;
				elseif #CompRunSec < 1080 then
					#SoftStartControl = floor((#CompRunSec ^ 0.5 - 28) / 5.16);
					#SHifT = #SoftStartControl;
					if #RoomTempControl < 0 then
						#SHifT = #SoftStartControl + #RoomTempControl;
					end
				elseif #RoomTempControl > #SHifT || @Compressor_Freq > 21 then
					#SHifT = #RoomTempControl;
				else
					#SHifT = #SHifT;
				end
			else
				if (@Main_Outlet_Temp - 1.8) > (#RoomTempControl + #WCS) && #CompRunTime < 30 then
					#SHifT = ceil(@Main_Outlet_Temp - 1.8 - #WCS);
				else
					#SHifT = #RoomTempControl;
				end
			end
		else
			$StopConditions = #CompRunTime > (-2 * #OutsideTemp - 30) || %hour < 7 || %hour > 22 || #RoomTempDelta < 0.2;
			if #CompState == 0 && $StopConditions && #CompRunTime < 2 then
				#SHifT = -5;
			else
				#SHifT = 0;
			end
		end
		#SHifT = min(max(#SHifT, -5), 5);
		if #ExternalOverRide == -2 then $Z1HRT = #WCS;else $Z1HRT = #SHifT + #WCS;end
		if $Z1HRT != @Z1_Heat_Request_Temp && #ExternalOverRide < 1 then
			@SetZ1HeatRequestTemperature = $Z1HRT;
		end
	end
end

on timer=4 then
	setTimer(4,60);
	if #Heat && @ThreeWay_Valve_State == 0 && @Defrosting_State == 0 && #ExternalOverRide < 3 && #DHWRun < 1 then
		$HPOff1Conditions = (#RoomTempDelta > 0.7 && %hour > 9) || #RoomTempDelta > 1.5 || #chEnableOffTime > 30;
		$HPOff2Conditions = #CompRunTime > 60 || #CompState == 0 || %hour > 22 || %hour < 3;
		$HPOff3Conditions = #OutsideTemp > 4 || (#chEnable == 0 && (%hour > 22 || %hour < 3));
		$HPOnCondition = (((#RoomTempDelta < 0.3 || %hour == 7) && #OutsideTemp < 11) || (#RoomTempDelta < 1 && #OutsideTemp < 2) || #RoomTempDelta < 0);
		if #chEnable && $HPOnCondition && #HPStateR != 1 then
				#HPStateR = 1;
		elseif $HPOff1Conditions && $HPOff2Conditions && $HPOff3Conditions && #HPStateR != 0 then
			#HPStateR = 0;
			if #OMR != 0 && #OMR != 3 then	#OMR = 0;end

		end
	end
	$CoolingEnable = max(round(#CoolingEnable),0);
	if $CoolingEnable && #DHWRun < 1 then
		#OMR = 1;
		#HPStateR = 1;
		if #CompState then $CoolReqTempMin = min(round(@Main_Outlet_Temp), 19);else $CoolReqTempMin = 0;end
		if @Z1_Cool_Request_Temp != ?coolingControl then
			@SetZ1CoolRequestTemperature = max(?coolingControl, 12, $CoolReqTempMin);end
	elseif $CoolingEnable == 0 && #OMR && #DHWRun < 1 && #CompState == 0 then
		#OMR = 0;
		#HPStateR = 0;
	end
end

on timer=5 then
	setTimer(5,900);
	if @Defrosting_State == 0 && #ExternalOverRide < 4 && #dhwEnable then
		if @ThreeWay_Valve_State == 0 && (@DHW_Temp < (@DHW_Target_Temp + @DHW_Heat_Delta - 10)|| 
			(%hour > 9 && @DHW_Temp < (@DHW_Target_Temp + @DHW_Heat_Delta - 5))|| 
			(%hour == 13 && (%day == #DHWSterilizationDay || %day == #DHWComfortDay || 
			@DHW_Temp < (@DHW_Target_Temp + @DHW_Heat_Delta)))) then
			#DHWRun = 1;
			#OMP = @Operating_Mode_State;
			#HPStateP = @Heatpump_State;
			if #OMP == 0 then	#OMR = 4;
			elseif #OMP then	#OMR = 5;
			else	#OMR = 3;
			end
			#HPStateR = 1;
		end
		if #DHWRun == 1 then
			if %day > (#DHWSterilizationDay - 2) && %hour > 10 && @DHW_Temp > 47 && @Sterilization_State != 1 then
				@SetForceSterilization = 1;
				#DHWSterilizationDay = #DHWSterilizationDay + 10;
			end
			if @ThreeWay_Valve_State == 0 && @DHW_Temp >= @DHW_Target_Temp && @Defrosting_State == 0 && @Sterilization_State == 0 then
				#OMR = max(0,#OMP);
				#OMP = @Operating_Mode_State;
				#HPStateR = #HPStateP;
				#HPStateP = 1;
				#DHWRun = 0;
			end
		end
		if %day == (#DHWSterilizationDay - 10) && %hour > 15 then #DHWSterilizationDay = #DHWSterilizationDay - 10;end
	end
end

on timer=6 then
	setTimer(6, 60);
	if #ExternalOverRide < 5 then
		#MaxPumpDuty = 82;
		if @ThreeWay_Valve_State then
			#MaxPumpDuty = 140;
			if (@Sterilization_State == 0 && @DHW_Temp > @DHW_Target_Temp) || (@Sterilization_State && @DHW_Temp > 57) then
				#MaxPumpDuty = #MaxPumpDuty - 10;
			end
		elseif @Operating_Mode_State then	#MaxPumpDuty = 92;
		elseif @Heatpump_State then
			if @Compressor_Freq == 0 && @Defrosting_State != 1 then	#MaxPumpDuty = 82;
			else
				$QFH = 10;$QFL = 16;$tH = 11;$tL = -3;
				if #OutsideTemp >= $tH then	$MaxPumpFlow = $QFH;
				elseif #OutsideTemp <= $tL then	$MaxPumpFlow = $QFL;
				else	$MaxPumpFlow = ceil($QFH + ($tH - #OutsideTemp) * ($QFL - $QFH) / ($tH - $tL));
				end
				if @Pump_Flow > 1 && @Pump_Flow < 8 && #MaxPumpDuty <= @Max_Pump_Duty then
					#MaxPumpDuty = @Max_Pump_Duty + 1;
				else
					#MaxPumpDuty = 55 + floor($MaxPumpFlow * 3);
					if (@Pump_Speed / @Pump_Flow) > 145 then
						if @Pump_Flow > 8 then	#MaxPumpDuty = @Max_Pump_Duty - 1;
						else	#MaxPumpDuty = @Max_Pump_Duty;
						end
					end
				end
			end
		end
		#MaxPumpDuty = max(#MaxPumpDuty, 82);
		if @Max_Pump_Duty != #MaxPumpDuty then @SetMaxPumpDuty = #MaxPumpDuty;end
	end
end

on timer=7 then
	setTimer(7,120);
	if @Defrosting_State == 0 && #ExternalOverRide < 2 then
		if #OutsideTemp < 4 || (#OutsideTemp < 6 && #CompFreqTarget == 34) then	#CompFreqTarget = 34;
		else	#CompFreqTarget = 24;
		end
		if #CompRunTime < 3 && @Compressor_Freq > 33 then	#QMR = 3;
		elseif @Compressor_Freq < #CompFreqTarget || (#QMR == 0 && @Compressor_Freq < #CompFreqTarget + 6) then	#QMR = 0;
		elseif @Compressor_Freq < #CompFreqTarget + 6 || (#QMR && @Compressor_Freq < #CompFreqTarget + 12) then	#QMR = 1;
		elseif @Compressor_Freq < #CompFreqTarget + 26 || (#QMR == 2 && @Compressor_Freq < #CompFreqTarget + 32) then	#QMR = 2;
		else	#QMR = 3;
		end
		if #QMR > 0 && @ThreeWay_Valve_State && %hour > 9 && %hour < 17 then $QMDHW = -1;else $QMDHW = 0;end
		if @Defrosting_State || #CompState < 1 || #CompRunTime < 5 || %hour < 7 || @Operating_Mode_State == 1 then #QMR = 3;end
		if #QMR != @Quiet_Mode_Level then @SetQuietMode = #QMR + $QMDHW;end
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
		#chEnable = 1;
		if #chEnableTimeOff != -1 then
			#chEnableTimeOff = -1;
			#chEnableOffTime = -1;
		end
	else
		if #chEnableTimeOff == -1 then	#chEnableTimeOff = #Time;end
		#chEnableOffTime = #Time - #chEnableTimeOff;
		if #chEnableOffTime > 15 then	#chEnable = 0;end
	end
	?maxTSet = min(#WCS + 5,33);
	?relativeModulation = round(@Compressor_Current / 15 * 100);
	if #CompState > 0 then
		?flameState = 1;
		if @Heat_Power_Consumption > 0 then	?chState = 1;else	?chState = 0;end
		if @DHW_Power_Consumption > 0 then	?dhwState = 1;else	?dhwState = 0;end
		if @Cool_Power_Consumption > 0 then	?coolingState = 1;else	?coolingState = 0;end
	else
		?flameState = 0;
		?chState = 0;
		?dhwState = 0;
		?coolingState = 0;
	end
	#RoomSetpoint = min(max(?roomTempSet, 10), 22);
	if ?maxRelativeModulation != 100 then #RoomTemp = 15 + ?maxRelativeModulation / 10;
	else #RoomTemp = #RoomSetpoint;							
	end
	#RoomTempDelta = #RoomTemp - #RoomSetpoint;
	#OutsideTemp = (#OutsideTemp * 59 + @Outside_Temp) / 60;
	#ExternalOverRide = @Z2_Heat_Request_Temp - 30;
	if #ExternalOverRide < 6 then
		if @Operating_Mode_State != #OMR then @SetOperationMode = #OMR;end
		if @Heatpump_State != #HPStateR && #ExternalOverRide != -1 && #DHWRun != 3 then @SetHeatpump = #HPStateR;end
	end
	if @Operating_Mode_State == 0 || @Operating_Mode_State == 4 then	#Heat = 1;else	#Heat = 0;end
end

on timer=9 then
	setTimer(9,300);
	$RoomTempDelta = #RoomTempDelta * -1;
	if (#RoomSetpoint > #RoomSetpointP && #RoomTempDelta < 0) || (#RoomSetpoint < #RoomSetpointP && #RoomTempDelta > 0) then
		#PIDintegral = 0;
	else
		#PIDintegral = min(max((#PIDintegral + $RoomTempDelta), -50), 50);
	end
	$P = #PIDKp * $RoomTempDelta;$I = #PIDKi * #PIDintegral;$D = #PIDKd * ($RoomTempDelta - #PIDpreverror);
	#PIDoutput = $P + $I + $D;
	if $RoomTempDelta == 0 || $RoomTempDelta > #PIDpreverror + 0.2 || $RoomTempDelta < #PIDpreverror - 0.2 then
		#PIDpreverror = $RoomTempDelta;
	end	
	#RoomTempControl = round(#PIDoutput);
	#RoomSetpointP = #RoomSetpoint;
end

on timer=10 then
	setTimer(10,1800);
	$Ta1 = @Z1_Heat_Curve_Target_Low_Temp;
	$Tb1 = @Z1_Heat_Curve_Outside_High_Temp;
	$Ta2 = 34;
	$Tb2 = @Z1_Heat_Curve_Outside_Low_Temp;
	if #OutsideTemp >= $Tb1 then #WCS = $Ta1;
	elseif #OutsideTemp <= $Tb2 then #WCS = $Ta2;
	else #WCS = ceil($Ta1 + (($Tb1 - #OutsideTemp) * ($Ta2 - $Ta1) / ($Tb1 - $Tb2)));
	end
end

on timer=11 then
	#CompRunSec = #CompRunSec + 5;
	if #CompRunSec < 1100 then	setTimer(11,5);end
end
```
