```LUA
on System#Boot then
	print('BLB Heishamon_rules20241125h.txt');
	print('my environment: Panasonic WH-MDC07J3E5 HeishaMon Large with CZ-TAW1 on proxy port Honeywell Evohome Opentherm Thermostat (R8810 bridge) connected via OpenTherm Gateway.');
	print('Honeywell Evohome & OpenTherm Gateway integration in Home Assistant to communicate RoomTemperatureDelta to HeishaMon rules as chSetpoint from Evohome is not reliable. Settings Heat Pump:');
	print('Operating_Mode_State: 0, Heating_Mode: 0, Cooling_Mode: 1, Buffer_Installed: 0, DHW_Installed: 1, Pump_Flowrate_Mode: 0, Optional_PCB: 0, Z1_Sensor_Settings: 0');

	#allowDHW = 1;
	#allowOTT = 1;
	#allowTaShift= 1;
	#allowPumpDuty = 1;
	#allowQuietMode = 1;
	#allowSynchHP = 1;
	#allowSyncOT = 1;
	#chEnable = -1;
	#chEnableOffTime = -1;
	#chEnableTimeOff = -1;
	#CompFreqTarget = -1;
	#CompRunTime = -1;
	#CompRunSec = -1;
	#CompState = -1;
	#CompStateChangeTime = -1;
	#Debug = 1;
	#DHWRun = -1;
	#FirstBoot = 1;
	#Heat = -1;
	#HPStateP = -1;
	#HPStateR = -1;
	#LegionellaRunDay = 7;
	#MaxPumpDuty = -1;
	#MaxPumpFlow = -1;
	#OMP = -1;
	#OMR = -1;
	#QMR = -1;
	#RemoteOverRide = -1;
	#RoomTempDelta = -1;
	#RoomTempSet  = -1;
	#RoomTempControl = -1;
	#SHifT = -1;
	#Time = -1;
	#SoftStartControl = -1;
	setTimer(1,60);
	setTimer(2,10);
end

on TaShift then
	#allowTaShift = #allowTaShift + 1;
	if #allowTaShift > 20 then #allowTaShift = 2; end
	if (#CompRunTime < 15 || #allowTaShift == 2) && #DHWRun < 1 && @ThreeWay_Valve_State == 0 then
		if #Debug > 10 then $com = 'basic conditions for TaShift fullfilled'; end
		#SHifT = @Z1_Heat_Request_Temp;
		if #CompState > 0 then
			if #Debug > 1 || #RemoteOverRide > 0 then	print('TaShift if Compressor is running');	end
			TaShift2();
		else
			$StopTime = - 2 * @Outside_Temp - 30;
			if  #CompState == 0 && #CompRunTime > $StopTime && #CompRunTime < 2 then
				if #Debug > 10 then $com = 'if compressor is off for a relative short time (depending on outside temperature) SHifT to -5 to avoid short cycle'; end
				#SHifT = -5;
			else
				if #Debug > 10 then $com = 'SHifT back to 0 when compressor is off and $StopTime is over '; end
				#SHifT = 0;
			end
		end
		if (%hour > 22 || %hour < 7) && @Outside_Temp < 3 && #SHifT > -3 && (@Main_Outlet_Temp - @Z1_Water_Target_Temp) < 0.5 && #CompState > 0 then
			if #Debug > 10 then $com = 'Between 23h and 7h SHifT -1 to switch off compressor a bit earlier'; end
			#SHifT = -1 + #SHifT;
		end

		if #Debug > 10 then $com = 'shift Z1HRT if required but not outside the range -5 to +5'; end
		#SHifT = min(max(#SHifT, -5), 5);
		if #SHifT != @Z1_Heat_Request_Temp && #RemoteOverRide < 1 then @SetZ1HeatRequestTemperature = #SHifT; end
	end
end

on TaShift2 then
	$WarTemp = @Z1_Water_Target_Temp - @Z1_Heat_Request_Temp;
	if #CompRunSec < 180 && #CompState == 1 then
		#SoftStartControl = ceil(@Main_Outlet_Temp - 4 + ceil(#CompRunSec / 60)) - $WarTemp;
		$a = 1; $b = ', CRS < 180';
	elseif #CompRunTime < (180 -  3 * @Outside_Temp) then
		#SoftStartControl = ceil(@Main_Outlet_Temp - 1.8) - $WarTemp;
		$a = 2; $b = concat(', CRT < ', (30 - @Outside_Temp));
	elseif #SoftStartControl > 0 && #CompRunTime / 60 == round(#CompRunTime / 60) then
		#SoftStartControl = #SoftStartControl - 1;
		$a = 3; $b = ', Back to 0';
	end
	#RoomTempControl = round(#RoomTempDelta * -3);
	#SHifT = #SoftStartControl + #RoomTempControl;

	if $a > 1 && (@Main_Outlet_Temp - $WarTemp + #SHifT) > 1.8 then
		#SHifT = ceil(@Main_Outlet_Temp - 1.8) - $WarTemp;
		$a = $a + 10; $b = ' ( limit #SHifT)';
	end
	#SHifT = min(#SHifT, 2);
end

on HeatPumpState($a) then
	if @Heatpump_State != #HPStateR && #RemoteOverRide != -1 then
		print('HeatPumpState, origin: ', $a);
		@SetHeatpump = #HPStateR;
	end
end
	
on OperatingMode then
	if @Operating_Mode_State != #OMR then @SetOperationMode = #OMR; end
end

on OpenThermThermostat then
	if #allowOTT == 1 && #RemoteOverRide < 3 && #DHWRun < 1 && @ThreeWay_Valve_State == 0 && @Defrosting_State == 0 then
		if #chEnable == 1 && #RoomTempDelta < 0.3 then
			#HPStateR = 1;
			HeatPumpState('OTTon');
		end

		if (#RoomTempDelta > 0.7 || #chEnableOffTime > 30 || (#chEnableOffTime > 15 && #CompressorRunTime < -15) || (#chEnableOffTime > 5 && %hour > 22)) && #3WayValve == 0 && (#CompressorRunTime > 60 || #CompressorState == 0) && #OutsideTemp > -5 then
			if @ThreeWay_Valve_State == 0 && (#CompRunTime > 90 || #CompState == 0) && @Outside_Temp > -5 && #HPStateR != 0 then
				#HPStateR = 0;
				HeatPumpState('OTToff');
				if  @Operating_Mode_State != 0 then @SetOperationMode = 0; end
				#allowOTT = 2;
				setTimer(7,600);
			end
			if #chEnable == 0 && #allowOTT != 2 then
				#allowOTT = 3;
				setTimer(7,25);
			end
		end
	end
end

on DHW then
	if #allowDHW == 1 && #RemoteOverRide < 4 then
		#allowDHW = 2;
		if @ThreeWay_Valve_State == 0 && (@DHW_Temp < (@DHW_Target_Temp + @DHW_Heat_Delta - 5) || (%hour == 13 && (%day == #LegionellaRunDay || @DHW_Temp < (@DHW_Target_Temp + @DHW_Heat_Delta)))) then
			#DHWRun = 1;
			#OMP = @Operating_Mode_State;
			#HPStateP = @Heatpump_State;
			if #OMP == 0 then 
				#OMR = 4;
			elseif #OMP == 1 then
				#OMR = 5;
			else
				#OMR = 3;
			end
			OperatingMode();
			#HPStateR = 1;
			HeatPumpState('DHWon');
		end
		if #DHWRun > 0 then
			if %day > 5 && %hour > 10 && @DHW_Temp > 47 && @Sterilization_State != 1 then
				@SetForceSterilization = 1;
				#LegionellaRunDay = 8;
			end
			if @ThreeWay_Valve_State == 0 && @DHW_Temp >= @DHW_Target_Temp && @Defrosting_State == 0 && @Sterilization_State == 0 then
				@SetOperationMode = max(0, #OMP);
				if @Heatpump_State != #HPStateP then
					#HPStateR = #HPStateP;
					HeatPumpState('DHWoff');
				end
				#OMP = @Operating_Mode_State;
				#HPStateP = 1;
				#DHWRun = 0;
			end
		end
		if %day == 7 && #LegionellaRunDay == 8 then #LegionellaRunDay = 7; end
		setTimer(6,900);
	end
end

on pumpDuty then
	if #allowPumpDuty == 1 && #RemoteOverRide < 5 then
		#allowPumpDuty = 2;
		#MaxPumpDuty = 85;
		if @ThreeWay_Valve_State == 1 then
			#MaxPumpDuty = 140;
			if (@Sterilization_State == 0 && @DHW_Temp > @DHW_Target_Temp) || (@Sterilization_State == 1 && @DHW_Temp > 57) then
				#MaxPumpDuty = 10 + #MaxPumpDuty;
			end
		elseif @Heatpump_State == 1 then
			if @Compressor_Freq == 0 && @Defrosting_State != 1 then
				#MaxPumpDuty = 82;
			elseif @Operating_Mode_State != 1 then
				$QFH = 10;		$QFL = 14;		$tH = 11;		$tL = -3;
				if @Outside_Temp >= $tH then
					#MaxPumpFlow = $QFH;
				elseif @Outside_Temp <= $tL then
					#MaxPumpFlow = $QFL;
				else
					#MaxPumpFlow = ceil($QFH + ($tH - @Outside_Temp) * ($QFL - $QFH) / ($tH - $tL));
				end
				if @Pump_Flow > 1 && @Pump_Flow < 8 && #MaxPumpDuty <= @Max_Pump_Duty then
					#MaxPumpDuty = @Max_Pump_Duty + 1;
				else
					#MaxPumpDuty = 55 + floor(#MaxPumpFlow * 3);
					if (@Pump_Speed / @Pump_Flow) > 145 then
						if @Pump_Flow > 8 then
							#MaxPumpDuty = @Max_Pump_Duty - 1;
						else
							#MaxPumpDuty = @Max_Pump_Duty;
						end
					end
				end
			else
				#MaxPumpDuty = 92;
			end
		end
		#MaxPumpDuty = max(#MaxPumpDuty, 82);
		if @Max_Pump_Duty != #MaxPumpDuty then @SetMaxPumpDuty = #MaxPumpDuty; end
		setTimer(5, 60);
	end
end

on QuietMode then
	if #allowQuietMode == 1 && #RemoteOverRide < 2 && @Defrosting_State == 0 then
		#allowQuietMode = 2;
		if @Outside_Temp < 3 || (@Outside_Temp < 5 && #CompFreqTarget == 34) then
			#CompFreqTarget = 34;
		else
			#CompFreqTarget = 24;
		end
		if #CompRunTime < 3 && @Compressor_Freq > 33 then
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
		if #QMR > 1 && @ThreeWay_Valve_State == 1 && %hour > 9 && %hour < 17 then #QMR = -1 + #QMR; end 
		setTimer(3,120);
	end
	if (@Defrosting_State == 1 && #allowQuietMode > 0 || #CompState < 1 || #CompRunTime < 5) || %hour < 7 then #QMR = 3; end
	if #QMR != @Quiet_Mode_Level then @SetQuietMode = #QMR; end
end

on syncOT then
	if  #allowSyncOT == 1 then
		?outletTemp = round(@Main_Outlet_Temp);
		?outsideTemp = #OutsideTemp;
		?dhwTemp = round(@DHW_Temp);
		?dhwSetpoint = @DHW_Target_Temp;
		if ?chEnable == 1 then
			#chEnable = 1;
			if #chEnableTimeOff != -1 then
				#chEnableTimeOff = -1;
				#chEnableOffTime= -1;
			end
		else
			if #chEnableTimeOff == -1 then #chEnableTimeOff = #Time; end
			#chEnableOffTime= #Time - #chEnableTimeOff;
			if #chEnableOffTime> 5 then #chEnable = 0; end
		end
		?maxTSet = @Z1_Water_Target_Temp + 5;
		if #CompState > 0 then
			?flameState = 1;
			if @Heat_Power_Consumption > 0 then ?chState = 1; else ?chState = 0; end
			if @DHW_Power_Consumption > 0 then ?dhwState = 1; else ?dhwState = 0; end
			if @Cool_Power_Consumption > 0 then ?coolingState = 1; else ?coolingState = 0; end
		else
			?flameState = 0;
			?chState = 0;
			?dhwState = 0;
			?coolingState = 0;
		end
		if #RoomTempSet == -1 then #RoomTempSet = ?roomTempSet; end
		if ?roomTempSet != 0 then
			if #Debug > 10 then $com = ('set RoomTempDeta with some safeguards around ?roomTempSet (not zero and change < 1)'); end
			#RoomTempSet = round(?roomTempSet * 10) / 10;
			#RoomTempDelta = max(min(20 - #RoomTempSet, 5), -5);
		end
	end
end

on syncHP then
	if #allowSynchHP == 1 then
		#allowSynchHP = 2;
		if @Operating_Mode_State == 0 || @Operating_Mode_State ==  4 then
			#Heat = 1;
		else
			#Heat = 0;
		end
		#RemoteOverRide = @Z2_Heat_Request_Temp;
		setTimer(9,30);
	end
end

on @Compressor_Freq then
	if @Compressor_Freq > 18 && #CompState == 0 then
		#CompStateChangeTime = #Time;
		#CompState = 1;
		#CompRunSec = 0;
		setTimer(10,5);
	elseif @Compressor_Freq < 18 && #CompState > 0 then
		#CompStateChangeTime = #Time;
		#CompState = 0;
	end
end

on @Main_Outlet_Temp then
	#allowTaShift = 1;
end

on @Z1_Water_Target_Temp then
	#allowTaShift = 1;
end

on timer=1 then
	setTimer(1,15);
	if #FirstBoot == 1 then
		#CompStateChangeTime= #Time;
		#RoomTempDelta = 0;
		if @Compressor_Freq > 18 then
			#CompState = 2;
		else
			#CompState = 0;
			@SetZ1HeatRequestTemperature = 0;
		end
		#SHifT = @Z1_Heat_Request_Temp;
		if @ThreeWay_Valve_State == 1 && #allowDHW == 1 then #DHWRun = 2; end
		#FirstBoot = 2;
	else
		syncHP();
		syncOT();
		QuietMode();
		pumpDuty();
		DHW();
		if #Heat ==  1 then
			OpenThermThermostat();
			TaShift();
		end
	end
end

on timer=2 then
	#Time = %day * 1440 + %hour * 60 + %minute;
	if @Compressor_Freq > 18 then
		#CompRunTime = #Time - #CompStateChangeTime;
		if #CompRunTime< 0 then
			#CompRunTime = #Time - #CompStateChangeTime + 10080;
		end
	else
		#CompRunTime = #CompStateChangeTime - #Time;
	end
	setTimer(2,60);
end

on timer=3 then #allowQuietMode = 1; end
on timer=5 then #allowPumpDuty = 1; end
on timer=6 then #allowDHW = 1; end
on timer=7 then #allowOTT  = 1; end
on timer=9 then #allowSynchHP = 1; end

on timer=10 then
	#CompRunSec = #CompRunSec + 5;
	if #CompRunSec < 600 then	setTimer(10,5);	end
end
```
