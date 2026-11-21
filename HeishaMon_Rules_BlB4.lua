on System#Boot then
	print('BLB Heishamon_rules_2611.15.lua');
	#chStateMin = -1;
	#chEnableChangeTime = -1;
	#otCHOffStartTime = -1;
	#cpFreqTarget = -1;
	#cpRunSec = -1;
	#cpRunMin = -1;
	#clEnable = -1;
	#hwComfortDay = 4;
	#hwState = -1;
	#hwSterilizationDay = 7;
	#hpHeatingMode = -1;
	#hpModePrev = -1;
	#qmReq = -1;
	#piIntegral = 0;
	#rtDelta = 0;
	#piCorrection = 0;
	#piStepTime = -1;
	setTimer(1,10);
end

on timer=1 then
	if isset(@Heatpump_State) && isset(@Operating_Mode_State) && isset(@Outside_Temp) && isset(@Z1_Heat_Request_Temp) && isset(@Compressor_Freq) && isset(?roomTempSet) && isset(?roomTemp) && isset(?chEnable) then
		#Time = %day * 1440 + %hour * 60 + %minute;
		#cpStateChangeTime = #Time;
		#chEnableChangeTime = #Time;
		#hpStateReq = @Heatpump_State;
		#hpStatePrev = @Heatpump_State;
		#hpModeReq = @Operating_Mode_State;
		#hpOutsideTemp = @Outside_Temp;
		#rtSetpoint = min(max(?roomTempSet, 10), 22);
		#rtTemp = ?roomTemp;
		#wcTarget = @Z1_Heat_Request_Temp;
		if @Compressor_Freq > 18 then
			#cpState = 2;
			#piStepTime = #Time;
			#cpRunSec = 1999;
		else
			#cpState = 0;
		end
		if @ThreeWay_Valve_State then
			#hwState = 3;
		end
		#chEnable = ?chEnable;
		#hwTempLast = @DHW_Temp;
		setTimer(2,10);
		setTimer(3,25);
		setTimer(4,30);
		setTimer(5,35);
		setTimer(6,40);
		setTimer(7,45);
		setTimer(8,50);
		setTimer(9,55);
		setTimer(10,22);
	else
		print('timer=1: waiting for HP / OT values');
		setTimer(1,5);
	end
end

on timer=2 then
	setTimer(2,60);
	#Time = %day * 1440 + %hour * 60 + %minute;
	$cpElapsedMin = (#Time - #cpStateChangeTime + 10080) % 10080;
	if @Compressor_Freq > 10 then
		#cpRunMin = $cpElapsedMin;
	else
		#cpRunMin = 0 - $cpElapsedMin;
	end
end

on @Compressor_Freq then
	if @Compressor_Freq > 10 && #cpState == 0 then
		#cpStateChangeTime = #Time;
		#cpState = 1;
		#cpRunSec = 0;
		#cpRunMin = 0;
		#piStepTime = -1;
		setTimer(11,1);
	elseif @Compressor_Freq < 10 && #cpState > 0 then
		#cpStateChangeTime = #Time;
		#cpState = 0;
		#cpRunMin = 0;
		#taDeltaSec = 0;
		#piStepTime = -1;
	end
end

on @Main_Outlet_Temp then
	if isset(#Time) then
		TaShift();
	end
end

on timer=3 then
	if #cpRunSec < 150 || #taDeltaSec > 0 then
		setTimer(3,15);
	else
		setTimer(3,60);
	end
	TaShift();
end

on TaShift then
	if @Defrosting_State == 1 then
		#piStepTime = -1;
	end
	#taDefrostAllowed = @Defrosting_State == 0 || (@Pump_Flow > 5 && @Pump_Flow < 30);
	if #hpHeatingMode == 1 && @ThreeWay_Valve_State == 0 && #hwState < 2 && #taDefrostAllowed == 1 then
		if #cpState > 0 then
			$wcAdjusted = #wcTarget + min(max(@Z2_Heat_Request_Temp - 20,-5), 5);
			#taDelta = @Main_Outlet_Temp - @Z1_Heat_Request_Temp;
			if #hpOutsideTemp > 7 && #cpRunSec < 130 && #cpRunSec != -1 then
				#taShift = ceil(@Main_Outlet_Temp) - 3 - $wcAdjusted;
			elseif @Compressor_Freq < 21 && max(#piCorrection,
				ceil(@Main_Outlet_Temp - 1.9 - $wcAdjusted)) < #taShift then
				print('no #taShift required');
			else
				#taShift = max(#piCorrection,ceil(@Main_Outlet_Temp - 1.9 - $wcAdjusted));
			end
			if #taDelta < 2 then
				#taDeltaSec = 0;
			elseif #taDeltaSec == 0 then
				#taDeltaSec = 10;
				setTimer(12,10);
			elseif #taDeltaSec >= 80 then
				#taShift = ceil(@Main_Outlet_Temp - 1.8 - $wcAdjusted);
			end
			if #taDelta >= 3 then
				#taShift = ceil(@Main_Outlet_Temp) - 2 - $wcAdjusted;
			end
		elseif (%hour < 7 || %hour > 22 || #rtDelta > 0.2) then
			#taShift = -5;
		elseif #cpRunMin > (-2 * #hpOutsideTemp - 30) && (#rtDelta > 0.1 || (#rtDelta > 0 && #taShift == -5)) then
			#taShift = -5;
		else
			#taShift = 0;
		end
		#taShift = min(max(#taShift, -5), 5);
		#taZ1ReqTemp = coalesce($wcAdjusted, #wcTarget) + #taShift;
		if #cpState > 0 then
			#taZ1ReqTemp = min(#taZ1ReqTemp, max($wcAdjusted - 5, ceil(@Main_Outlet_Temp) - 1));
		end
		TaShift2($wcAdjusted);
	end
end

on timer=4 then
	setTimer(4,60);
	if @Sterilization_State == 0 && #hwState < 2 then
		if #hpHeatingMode == 1 && @ThreeWay_Valve_State == 0 && @Defrosting_State == 0 then
			$chOverNight = %hour > 22 || %hour < 3;
			$chRestartAllowed = #chEnable && #chStateMin > 60 && #cpRunMin < -60 && $chOverNight != 1;

			if #chEnable == 1 && (((#rtDelta < 0.2 || %hour == 7) && #hpOutsideTemp < 11) || (#rtDelta < 1 && #hpOutsideTemp < 2) || #rtDelta < 0 || ($chRestartAllowed == 1 && #rtDelta < 2)) && #hpStateReq != 1 then
				#hpStateReq = 1;

			elseif ((#rtDelta > 0.2 && %hour > 9) || #rtDelta > 1.5 || (#chEnable == 0 && #chStateMin < -30)) && (#cpRunMin > 60 || #cpState == 0 || $chOverNight) && (#hpOutsideTemp > 4 || (#chEnable == 0 && $chOverNight)) && $chRestartAllowed == 0 && #hpStateReq != 0 then
				#hpStateReq = 0;
				if #hpModeReq != 0 && #hpModeReq != 3 then
					#hpModeReq = 0;
				end
			end
		end

		$clEnable = max(round(#clEnable),0);
		if $clEnable == 1 then
			#hpModeReq = 1;
			#hpStateReq = 1;
			$clOffset = 0;
			if #cpState == 1 then
				$clReqTempMin = min(round(@Main_Outlet_Temp), 19);
			else
				$clReqTempMin = 0;
				if @Main_Outlet_Temp > (@Main_Target_Temp + 3) then
					$clOffset = -2;
				end
			end

			$clReqTemp = max((?coolingControl + $clOffset), 12, $clReqTempMin);
			if @Z1_Cool_Request_Temp != $clReqTemp then
				@SetZ1CoolRequestTemperature = $clReqTemp;
			end
		elseif $clEnable == 0 && #hpModeReq == 1 && #hwState < 2 && #cpState == 0 then
			#hpModeReq = 0;
			#hpStateReq = 0;
		end
	end
end

on timer=5 then
	setTimer(5,900);
	if @Defrosting_State == 0 && ?dhwEnable then
		$hwStartHour = 13;
		if (%month > 3 && %month < 9) && %hour == 8 && #hpOutsideTemp > 20 then
			$hwStartHour = 8;
		elseif #hpOutsideTemp < 4 then
			$hwStartHour = 0;
		end
		$hwDeepLow = @DHW_Temp <= (@DHW_Target_Temp + @DHW_Heat_Delta - 10);
		$hwLowOrDrop = @DHW_Temp <= (@DHW_Target_Temp + @DHW_Heat_Delta - 5) || @DHW_Temp < (#hwTempLast - 5);
		$hwScheduleEligible = (%day == #hwSterilizationDay && @DHW_Temp < 50) || (%day == #hwComfortDay && @DHW_Temp < (@DHW_Target_Temp - 3)) || (@DHW_Temp < (@DHW_Target_Temp + @DHW_Heat_Delta));
		if #hwState < 1 && @ThreeWay_Valve_State == 0 && (($hwDeepLow) || (%hour >= 9 && ($hwLowOrDrop)) || (%hour == $hwStartHour && ($hwScheduleEligible))) then
			#hwState = 2;
			#hpModePrev = @Operating_Mode_State;
			#hpStatePrev = @Heatpump_State;
			if #hpModePrev == 0 then
				#hpModeReq = 4;
			elseif #hpModePrev == 1 then
				#hpModeReq = 5;
			else
				#hpModeReq = 3;
			end
			#hpStateReq = 1;
		elseif #hwState > 0 && #hwState < 3 then
			if %day > (#hwSterilizationDay - 2) && @ThreeWay_Valve_State == 1 && #cpState > 0 && @Sterilization_State != 1 then
				@SetForceSterilization = 1;
				#hwSterilizationDay = #hwSterilizationDay + 10;
			elseif @ThreeWay_Valve_State == 0 && @DHW_Temp >= @DHW_Target_Temp && @Defrosting_State == 0 && @Sterilization_State == 1 then
				#hwState = 1;
			elseif @ThreeWay_Valve_State == 0 && @DHW_Temp >= @DHW_Target_Temp && @Defrosting_State == 0 && @Sterilization_State == 0 then
				#hpModeReq = max(0,#hpModePrev);
				#hpModePrev = @Operating_Mode_State;
				#hpStateReq = #hpStatePrev;
				#hpStatePrev = 1;
				#hwState = 0;
				#piStepTime = -1;
				#taDeltaSec = 0;
				#taDelta = 0;
			end
		end
		if %day == (#hwSterilizationDay - 10) && %hour > 15 then
			#hwSterilizationDay = #hwSterilizationDay - 10;
		end
		#hwTempLast = @DHW_Temp;
	end
end

on timer=6 then
	setTimer(6, 60);
	$puMaxDuty = 102 - 4 * @Heat_Delta;
	if @ThreeWay_Valve_State == 1 then
		$puMaxDuty = 140;
		if (@Sterilization_State == 0 && @DHW_Temp > @DHW_Target_Temp) || (@Sterilization_State == 1 && @DHW_Temp > 57) then
			$puMaxDuty = $puMaxDuty - 10;
		end
	elseif @Operating_Mode_State == 1 then
		$puMaxDuty = 92;
	elseif @Heatpump_State == 1 then
		if @Compressor_Freq == 0 && @Defrosting_State != 1 then
			$puMaxDuty = 112 - 4 * @Heat_Delta;
		else
			$puFlowTarget = min(max(ceil(10 + (11 - #hpOutsideTemp) * 6 / 14), 10), 16);
			if @Pump_Flow > 1 && @Pump_Flow < 8 && $puMaxDuty <= @Max_Pump_Duty then
				$puMaxDuty = @Max_Pump_Duty + 1;
			else
				$puMaxDuty = 55 + floor($puFlowTarget * 3);
				if (@Pump_Speed / @Pump_Flow) > 145 then
					if @Pump_Flow > 8 then
						$puMaxDuty = @Max_Pump_Duty - 1;
					else
						$puMaxDuty = @Max_Pump_Duty;
					end
				end
			end
		end
	end
	$puMaxDuty = max($puMaxDuty, 82);
	if @Max_Pump_Duty != $puMaxDuty then
		@SetMaxPumpDuty = $puMaxDuty;
	end
end

on timer=7 then
	setTimer(7,120);
	#cpFreqTarget = min(max(ceil(24 + (6 - #hpOutsideTemp) * 30 / 9), 24), 54);
	if @Defrosting_State == 1 || #cpState < 1 || #cpRunMin < 5 || %hour < 7 || @Operating_Mode_State == 1 then
		#qmReq = 3;
	elseif @Compressor_Freq < #cpFreqTarget || (#qmReq == 0 && @Compressor_Freq < #cpFreqTarget + 6) then
		#qmReq = 0;
	elseif @Compressor_Freq < #cpFreqTarget + 6 || (#qmReq == 1 && @Compressor_Freq < #cpFreqTarget + 12) then
		#qmReq = 1;
	elseif @Compressor_Freq < #cpFreqTarget + 26 || (#qmReq == 2 && @Compressor_Freq < #cpFreqTarget + 32) then
		#qmReq = 2;
	else
		#qmReq = 3;
	end
	$qmDHWOffset = 0;
	if #qmReq > 0 && @ThreeWay_Valve_State && %hour > 9 && %hour < 17 then
		$qmDHWOffset = -1;
	end
	if @Buffer_Tank_Delta < 4 then
		@SetQuietMode = @Buffer_Tank_Delta;
	elseif #qmReq != @Quiet_Mode_Level then
		@SetQuietMode = #qmReq + $qmDHWOffset;
	end
end

on timer=8 then
	setTimer(8,30);
	?outletTemp = round(@Main_Outlet_Temp);
	?inletTemp = round(@Main_Inlet_Temp);
	?outsideTemp = round(#hpOutsideTemp);
	?dhwTemp = round(@DHW_Temp);
	?dhwSetpoint = @DHW_Target_Temp;
	#clEnable = #clEnable + 0.1 * (?CoolingEnable - #clEnable);
	#rtSetpoint = min(max(?roomTempSet, 10), 22);
	#rtTemp = ?roomTemp;
	#rtDelta = #rtTemp - #rtSetpoint;
	if gpio(33) == 1 then
		#otCHOffStartTime = -1;
		if (#rtDelta < 0 && #chEnable == 0) || (#rtDelta > 0.2 && #chEnable == 1) then
			#chEnable = 1 - #chEnable;
			#chEnableChangeTime = #Time;
		end
	else
		if ?chEnable == 1 then
			#otCHOffStartTime = -1;
			if #chEnable == 0 then
				#chEnableChangeTime = #Time;
				#chEnable = 1;
			end
		else
			if #otCHOffStartTime < 0 then
				#otCHOffStartTime = #Time;
			end
			$otCHOffElapsedMin = (#Time - #otCHOffStartTime + 10080) % 10080;
			if $otCHOffElapsedMin > 15 && #chEnable == 1 then
				#chEnable = 0;
				#chEnableChangeTime = #Time;
			end
		end
	end
	$chElapsedMin = (#Time - #chEnableChangeTime + 10080) % 10080;
	if #chEnable == 1 then
		#chStateMin = $chElapsedMin;
	else
		#chStateMin = 0 - $chElapsedMin;
	end
	?maxTSet = #wcTarget + 5;
	?relativeModulation = round(@Compressor_Current / 15 * 100);
	if #cpState > 0 then
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
	#hpOutsideTemp = (#hpOutsideTemp * 59 + @Outside_Temp) / 60;
	if @Operating_Mode_State != #hpModeReq then
		@SetOperationMode = #hpModeReq;
	end
	if @Heatpump_State != #hpStateReq && #hwState != 3 then
		@SetHeatpump = #hpStateReq;
	end
	if @Operating_Mode_State == 0 || @Operating_Mode_State == 4 then
		#hpHeatingMode = 1;
	else
		#hpHeatingMode = 0;
	end
end

on timer=9 then
	setTimer(9,300);
	$piKp = 1.2;
	$piKi = 0.05;
	$piIMin = -5;
	$piIMax = 5;
	$piMin = -5;
	$piMax = 5;
	if #hwState < 1 && @ThreeWay_Valve_State == 0 && ?roomTempSet > 12 && #rtSetpoint > 12 then
		$piError = #rtSetpoint - #rtTemp;
		$piP = $piKp * $piError;
		if #chEnable == 1 && #hpHeatingMode == 1 && #hwState < 2 && @ThreeWay_Valve_State == 0 && @Defrosting_State == 0 && #rtDelta <= 0.2 then
			$piIntegralNext = min(max(#piIntegral + $piKi * $piError, $piIMin), $piIMax);
			$piCandidate = $piP + $piIntegralNext;
			if ($piCandidate <= $piMax || $piError <= 0) && ($piCandidate >= $piMin || $piError >= 0) then
				#piIntegral = $piIntegralNext;
			end
		end
		$piOutput = $piP + #piIntegral;
		#piCorrection = round(min(max($piOutput, $piMin), $piMax));
	end
end

on timer=10 then
	setTimer(10,1800);
	$wcTargetLow = @Z1_Heat_Curve_Target_Low_Temp;
	$wcTargetHigh = 36;
	$wcOutsideHigh = @Z1_Heat_Curve_Outside_High_Temp;
	$wcOutsideLow = @Z1_Heat_Curve_Outside_Low_Temp;

	#wcTarget = min(max(ceil($wcTargetLow + ($wcOutsideHigh - #hpOutsideTemp) * ($wcTargetHigh - $wcTargetLow) / ($wcOutsideHigh - $wcOutsideLow)), $wcTargetLow), $wcTargetHigh);
end

on timer=11 then
	#cpRunSec = #cpRunSec + 5;
	if #cpRunSec < 1100 then
		setTimer(11,5);
	end
end

on timer=12 then
	if #taDeltaSec < 200 && #taDelta >= 2 then
		#taDeltaSec = #taDeltaSec + 10;
		setTimer(12, 10);
	end
end

on TaShift2($wcAdjusted) then
	if #cpState > 0 && @Defrosting_State == 0 && @Z2_Heat_Request_Temp <= 25 then
		if #piStepTime >= 0 then
			#taZ1ReqTemp = @Z1_Heat_Request_Temp;
		end
		if (#hpOutsideTemp <= 7 || #cpRunSec >= 130 || #cpRunSec == -1) && ((#piStepTime < 0 && (#cpRunMin >= 15 || (#cpRunMin >= 2 && @Compressor_Freq <= #cpFreqTarget))) || (#piStepTime >= 0 && ((#Time - #piStepTime + 10080) % 10080 >= 15 || ((#Time - #piStepTime + 10080) % 10080 >= 10 && @Compressor_Freq <= #cpFreqTarget)))) then
			if $wcAdjusted + #piCorrection > @Z1_Heat_Request_Temp then
				#taZ1ReqTemp = min(@Z1_Heat_Request_Temp + 1, $wcAdjusted + #piCorrection);
			elseif $wcAdjusted + #piCorrection < @Z1_Heat_Request_Temp && @Main_Outlet_Temp <= @Z1_Heat_Request_Temp + 0.8 then
				#taZ1ReqTemp = max(@Z1_Heat_Request_Temp - 1, $wcAdjusted + #piCorrection);
			else
				#taZ1ReqTemp = @Z1_Heat_Request_Temp;
			end
			if #piStepTime < 0 || #taZ1ReqTemp != @Z1_Heat_Request_Temp then
				#piStepTime = #Time;
			end
		end
		if #piStepTime >= 0 then
			if #taDeltaSec >= 80 && ceil(@Main_Outlet_Temp - 1.8) > @Z1_Heat_Request_Temp then
				#taZ1ReqTemp = max(#taZ1ReqTemp, min(@Z1_Heat_Request_Temp + 1, ceil(@Main_Outlet_Temp - 1.8)));
				#piStepTime = #Time;
			end
			if #taDelta >= 3 && ceil(@Main_Outlet_Temp) - 2 > @Z1_Heat_Request_Temp then
				#taZ1ReqTemp = max(#taZ1ReqTemp, min(@Z1_Heat_Request_Temp + 1, ceil(@Main_Outlet_Temp) - 2));
				#piStepTime = #Time;
			end
		end
	end
	if @Z2_Heat_Request_Temp > 25 then
		#taZ1ReqTemp = @Z2_Heat_Request_Temp;
	end
	if #taZ1ReqTemp != @Z1_Heat_Request_Temp then
		@SetZ1HeatRequestTemperature = #taZ1ReqTemp;
	end
end
