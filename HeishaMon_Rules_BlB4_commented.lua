-- This is the maintained source file; generate a loadable version with the minify tool. https://github.com/klaashoekstra94/heishamon_rules_minify
-- Requires the HeishaMon Rules build supporting more than 127 variables and GPIO33.

--[[
Overview:	Control a Panasonic WH-MDC07J3E5 for heating, cooling and DHW using HeishaMon, an Evohome OpenTherm thermostat via OTGW and selected Home
		Assistant values. The Rules are tailored to this installation. Validate all assumptions and limits before using them elsewhere.

Interfaces:	@ = heat-pump data or commands; ? = OpenTherm values; # = global Rules state; $ = local Rules variables.

Operation:	Startup state is initialized in timer=1, after required inputs exist. Timer=1 schedules the periodic Rules after initialization. #WCS is the
		weather-compensated baseline; timer=9 computes the room PI correction and TaShift controls the actual heating request.

Installation:	Use the commented file for maintenance. Apply the minify tool when producing the firmware-loadable version.
]]

--[[
System#Boot
Purpose:	Initialize persistent controller state and start the input-readiness check.
Explanation:	Global state variables use -1 where a not-yet-initialized value is useful. The PI integrator and its output start at zero. No heat-pump or
		OpenTherm inputs are read here, because they may not be available immediately after boot. Only timer=1 is started; it will schedule the
		remaining periodic Rules.
Result:		Selected # state variables; starts timer=1.
Called by:	System boot; timer=1 is first scheduled after 10 seconds.
rule 01]]
on System#Boot then
	print('BLB Heishamon_rules_2611.13.lua');
	-- Initialize state without reading unavailable boot-time inputs.
	#chEnableOnMin = -1;					-- Signed minutes: on > 0, off < 0
	#chEnableChangeTime = -1;
	#chEnableTimeOff = -1;
	#CompFreqTarget = -1;
	#CompRunSec = -1;					-- Seconds; -1 means not yet known
	#CompRunMin = -1;					-- Signed running/stopped minutes
	#CoolingEnable = -1;					-- Filtered cooling request
	-- Weekly DHW schedule defaults (1 = Sunday; 7 = Saturday).
	#DHWComfortDay = 4;					-- Optional comfort-day DHW check
	#DHWRun = -1;						-- 0 idle, 1 finishing, 2 Rules DHW, 3 detected DHW
	#DHWSterilizationDay = 7;				-- Saturday by default
	#Heat = -1;
	#OMP = -1;						-- Saved operating mode during DHW
	#QMR = -1;						-- Requested quiet-mode level
	-- Start the PI with no accumulated correction.
	#PIDintegral = 0;
	#RoomTempDelta = 0;					-- Actual room temperature minus setpoint
	#RoomTempControl = 0;
	#TaPIStepTime = -1;					-- -1 = PI handover not active
	setTimer(1,10);
end


--[[
timer=1: Startup initialization
Purpose:	Initialize live state once the required heat-pump and OpenTherm values exist.
Explanation:	Eight required inputs are checked with isset(). If an input is missing, initialization retries after five seconds; the other periodic timers are
		scheduled only on the successful branch. The current operating mode, heat-pump state, room values and baseline target are copied into controller
		state. If the compressor is already running, state 2 and a 1999-second sentinel avoid treating it as a fresh start. A DHW valve state detected
		at startup uses #DHWRun = 3. The existing timer-start order and delays are retained.
Result:		Initial # state from live inputs; schedules timers 2 through 10.
Called by:	System#Boot after 10 seconds; retries every 5 seconds until ready.
rule 02]]
on timer=1 then
	-- Do not start periodic control until these eight required inputs are valid.
	if isset(@Heatpump_State) && isset(@Operating_Mode_State) && isset(@Outside_Temp) && isset(@Z1_Heat_Request_Temp) && isset(@Compressor_Freq) &&
		isset(?roomTempSet) && isset(?roomTemp) && isset(?chEnable) then
		#Time = %day * 1440 + %hour * 60 + %minute;
		#CompStateChangeTime = #Time;
		#chEnableChangeTime = #Time;
		#HPStateR = @Heatpump_State;
		#HPStateP = @Heatpump_State;
		#OMR = @Operating_Mode_State;
		#OutsideTemp = @Outside_Temp;
		#RoomSetpoint = min(max(?roomTempSet, 10), 22);		-- Clamp room setpoint to 10–22 C
		#RoomTemp = ?roomTemp;
		#WCS = @Z1_Heat_Request_Temp;
		-- Recover a run already in progress without applying fresh-start timing.
		if @Compressor_Freq > 18 then
			#CompState = 2;					-- Compressor already running at reload
			#TaPIStepTime = #Time;
			#CompRunSec = 1999;				-- Sentinel: bypass fresh-start phase
		else
			#CompState = 0;
		end
		-- If DHW is active at reload, record it without restarting DHW control.
		if @ThreeWay_Valve_State then
			#DHWRun = 3;					-- DHW already in progress at reload
		end
		#chEnable = ?chEnable;
		#DHWTempP = @DHW_Temp;
		-- Keep the established relative startup delays and Rule ordering.
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
		-- Retry without scheduling dependent Rules.
		print('timer=1: waiting for HP / OT values');
		setTimer(1,5);
	end
end


--[[
timer=2: Time reference and compressor duration
Purpose:	Maintain the week-relative time reference and signed compressor run duration.
Explanation:	#Time uses day, hour and minute; 10080 is the number of minutes in a week. The modulo expression handles the weekly wrap. #CompRunMin is
		positive while the compressor runs and negative while it is stopped. The reference time for each compressor-state change is set by the
		@Compressor_Freq event Rule.
Result:		#Time and #CompRunMin, expressed in minutes.
Called by:	Scheduled from timer=1 after 10 seconds; repeats every 60 seconds.
rule 03]]
on timer=2 then
	setTimer(2,60);
	#Time = %day * 1440 + %hour * 60 + %minute;
	-- Correct the elapsed duration for the wrap at the end of a week.
	$CompElapsed = (#Time - #CompStateChangeTime + 10080) % 10080;
	if @Compressor_Freq > 10 then
		#CompRunMin = $CompElapsed;
	else
		#CompRunMin = 0 - $CompElapsed;			-- Negative duration indicates compressor OFF
	end
end


--[[
@Compressor_Freq: Compressor transitions
Purpose:	Detect compressor start/stop transitions and maintain related timing state.
Explanation:	A frequency above 10 Hz changes an idle compressor to running state 1. A frequency below 10 Hz changes a running compressor to stopped state 0.
		At startup, timer=1 may use state 2 for an already-running compressor. Starting a new run resets its counters and the controlled PI-step phase,
		and schedules timer=11. Stopping resets the overshoot and PI-step timers.
Result:		#CompState, #CompStateChangeTime, run counters and PI-step state.
Called by:	Every @Compressor_Freq update.
rule 04]]
on @Compressor_Freq then
	-- A hysteresis gap at exactly 10 Hz avoids treating that value as a transition.
	if @Compressor_Freq > 10 && #CompState == 0 then
		#CompStateChangeTime = #Time;
		#CompState = 1;					-- Compressor started after Rules boot
		#CompRunSec = 0;
		#CompRunMin = 0;
		#TaPIStepTime = -1;
		setTimer(11,1);
	elseif @Compressor_Freq < 10 && #CompState > 0 then
		#CompStateChangeTime = #Time;
		#CompState = 0;
		#CompRunMin = 0;
		#TaDeltaTimer = 0;				-- Clear outlet overshoot tracking
		#TaPIStepTime = -1;
	end
end


--[[
@Main_Outlet_Temp: Immediate TaShift check
Purpose:	Apply TaShift promptly when the measured outlet temperature updates.
Explanation:	TaShift is called only after #Time exists, avoiding execution before the initial heat-pump/OpenTherm state has been established by timer=1.
Result:		Calls TaShift when initialized.
Called by:	Every @Main_Outlet_Temp update.
rule 05]]
on @Main_Outlet_Temp then
	-- The event may arrive before startup initialization has completed.
	if isset(#Time) then
		TaShift();
	end
end


--[[
timer=3: Periodic TaShift check
Purpose:	Provide a periodic fallback trigger for the TaShift controller.
Explanation:	The interval is 15 seconds while compressor startup is in progress or the outlet-temperature overshoot timer is active; otherwise it is 60
		seconds. This supplements the event-driven @Main_Outlet_Temp trigger.
Result:		Schedules itself and calls TaShift.
Called by:	Scheduled from timer=1 after 25 seconds; repeats every 15 or 60 seconds.
rule 06]]
on timer=3 then
	-- Check more frequently during compressor startup and sustained overshoot.
	if #CompRunSec < 150 || #TaDeltaTimer > 0 then
		setTimer(3,15);
	else
		setTimer(3,60);
	end
	TaShift();
end


--[[
TaShift: Heating target management (part 1 of 2)
Purpose:	Validate heating conditions and calculate the initial zone-1 request.
Explanation:	Preserves the original 2611.11 DHW/defrost gate, compressor-start logic, WAR-adjusted $WCS, outlet overshoot protection and baseline request.
		$WCS is calculated once while the compressor runs and passed unchanged to TaShift2. With the compressor stopped, $WCS is NULL.
		The short TaShift2 call removes the oversized conditional jump while preserving the original decision sequence.
Result:		#SHifT and preliminary #Z1HRT; invokes TaShift2($WCS) in valid heating conditions.
Called by:	@Main_Outlet_Temp and timer=3.
rule 07]]
on TaShift then
	-- After defrost, require a new PI handover rather than reusing the old phase.
	if @Defrosting_State == 1 then
		#TaPIStepTime = -1;						-- Restart PI handover after defrost
	end
	-- This gate also permits TaShift during defrost if pump flow is 5–30 l/min.
	#NoDefrost = @Defrosting_State == 0 || (@Pump_Flow > 5 && @Pump_Flow < 30);
	if #Heat == 1 && @ThreeWay_Valve_State == 0 && #DHWRun < 2 && #NoDefrost == 1 then
		if #CompState > 0 then
			-- Zone-2 request can adjust the WAR reference by at most +/-5 C.
			$WCS = #WCS + min(max(@Z2_Heat_Request_Temp - 20,-5), 5);
			#TaDelta = @Main_Outlet_Temp - @Z1_Heat_Request_Temp;
			-- During a warm-weather compressor start, reduce the target shift briefly.
			if #OutsideTemp > 7 && #CompRunSec < 130 && #CompRunSec != -1 then
				#SHifT = ceil(@Main_Outlet_Temp) - 3 - $WCS;
			-- Hold the previous shift when the compressor is slow and no increase is needed.
			elseif @Compressor_Freq < 21 && max(#RoomTempControl,
				ceil(@Main_Outlet_Temp - 1.9 - $WCS)) < #SHifT then
				print('no #SHifT required');
			else
				#SHifT = max(#RoomTempControl,ceil(@Main_Outlet_Temp - 1.9 - $WCS));
			end
			-- Monitor sustained outlet temperature above the current heating request.
			if #TaDelta < 2 then
				#TaDeltaTimer = 0;
			elseif #TaDeltaTimer == 0 then
				#TaDeltaTimer = 10;
				setTimer(12,10);
			elseif #TaDeltaTimer >= 80 then
				#SHifT = ceil(@Main_Outlet_Temp - 1.8 - $WCS);
			end
			-- Protect immediately against a larger outlet-temperature overshoot.
			if #TaDelta >= 3 then
				#SHifT = ceil(@Main_Outlet_Temp) - 2 - $WCS;
			end
		-- When the compressor is off, force low target or neutral target by conditions.
		elseif (%hour < 7 || %hour > 22 || #RoomTempDelta > 0.2) then
			#SHifT = -5;
		elseif #CompRunMin > (-2 * #OutsideTemp - 30) && (#RoomTempDelta > 0.1 || (#RoomTempDelta > 0 && #SHifT == -5)) then
			#SHifT = -5;
		else
			#SHifT = 0;
		end
		-- Keep the generic shift within the supported +/-5 C range.
		#SHifT = min(max(#SHifT, -5), 5);
		#Z1HRT = coalesce($WCS, #WCS) + #SHifT;				-- Use #WCS when local $WCS is unset
		if #CompState > 0 then
			#Z1HRT = min(#Z1HRT, max($WCS - 5, ceil(@Main_Outlet_Temp) - 1));
		end
		TaShift2($WCS);
	end
end


--[[
timer=4:	OpenTherm thermostat (heating and cooling)
Purpose:	Control the requested heat-pump state and operating mode for heating and cooling.
Explanation:	Heating uses filtered #chEnable, room-temperature deviation, compressor run/off time, outside temperature and time-of-day conditions. #Heat, DHW
		and defrost conditions determine whether heating control is allowed. $OverNight covers 23:00–02:59. $chEnableCondition avoids prolonged
		inactivity when heating is requested and the compressor has been off for more than 60 minutes. Cooling follows #CoolingEnable (filtered in
		timer=8). Cooling setpoints are limited by the requested temperature and outlet-temperature safeguards. #HPStateR and #OMR are requests; timer=8
		sends them to the heat pump.
Result:		#HPStateR, #OMR, possibly @SetZ1CoolRequestTemperature.
Called by:	Scheduled from timer=1 after 30 seconds; repeats every 60 seconds.
rule 08]]
on timer=4 then
	setTimer(4,60);
	-- Avoid thermostat control during sterilization and active DHW operation.
	if @Sterilization_State == 0 && #DHWRun < 2 then
		-- Heating control is permitted only in normal room-heating conditions.
		if #Heat == 1 && @ThreeWay_Valve_State == 0 && @Defrosting_State == 0 then
			$OverNight = %hour > 22 || %hour < 3;					-- Night period: 23:00–02:59
			$chEnableCondition = #chEnable && #chEnableOnMin > 60 && #CompRunMin < -60 && $OverNight != 1;

			-- Start heating when heat is requested and at least one room/outside temperature condition is met.
			if #chEnable == 1 && (((#RoomTempDelta < 0.2 || %hour == 7) && #OutsideTemp < 11) ||
				(#RoomTempDelta < 1 && #OutsideTemp < 2) || #RoomTempDelta < 0 || ($chEnableCondition == 1 && #RoomTempDelta < 2)) &&
				#HPStateR != 1 then
				#HPStateR = 1;							-- Request heat pump ON

			-- Stop heating only when room-demand and compressor timing conditions
			-- permit it; avoid unnecessary circulation-pump stops in cold weather.
			elseif ((#RoomTempDelta > 0.2 && %hour > 9) || #RoomTempDelta > 1.5 || (#chEnable == 0 && #chEnableOnMin < -30)) &&
				(#CompRunMin > 60 || #CompState == 0 || $OverNight) && (#OutsideTemp > 4 || (#chEnable == 0 && $OverNight)) &&
				$chEnableCondition == 0 && #HPStateR != 0 then
				#HPStateR = 0;							-- Request heat pump OFF
				if #OMR != 0 && #OMR != 3 then
					#OMR = 0;						-- Return to heating mode unless in DHW-only mode
				end
			end
		end

		-- Cooling is handled separately from the heating conditions above.
		$CoolingEnable = max(round(#CoolingEnable),0);					-- Use filtered cooling request
		if $CoolingEnable == 1 then
			#OMR = 1;								-- Request cooling mode
			#HPStateR = 1;								-- Keep heat pump ON
			$CoolForce = 0;
			if #CompState == 1 then
				$CoolReqTempMin = min(round(@Main_Outlet_Temp), 19);
			else
				$CoolReqTempMin = 0;
				if @Main_Outlet_Temp > (@Main_Target_Temp + 3) then
					$CoolForce = -2;					-- Lower cooling request when outlet is too warm
				end
			end

			-- Apply the cooling request only when the target actually changes.
			$CoolingControl = max((?coolingControl + $CoolForce), 12, $CoolReqTempMin);
			if @Z1_Cool_Request_Temp != $CoolingControl then
				@SetZ1CoolRequestTemperature = $CoolingControl;
			end
		elseif $CoolingEnable == 0 && #OMR == 1 && #DHWRun < 2 && #CompState == 0 then
			#OMR = 0;								-- Leave cooling mode when compressor has stopped
			#HPStateR = 0;								-- Request heat pump OFF
		end
	end
end


--[[
timer=5: Domestic hot water and sterilization
Purpose:	Schedule DHW production and the weekly sterilization opportunity.
Explanation:	The regular DHW check is at 13:00, moved to 08:00 during specified warm summer conditions or 00:00 when outside temperature is below 4 C.
		Additional temperature thresholds can start DHW immediately or after 09:00. On the comfort day a lower threshold applies; on the sterilization
		day a DHW run is requested if the tank is below 50 C. When a Rules-initiated DHW run starts, the prior operating mode and heat-pump state are
		saved. Sterilization may be advanced to the preceding day; adding 10 to #DHWSterilizationDay marks it as already requested for that week. After
		DHW completion, previous operating settings are restored.
Result:		#DHWRun, #OMP, #OMR, #HPStateR and DHW/sterilization commands.
Called by:	Scheduled from timer=1 after 35 seconds; repeats every 900 seconds.
rule 09]]
on timer=5 then
	setTimer(5,900);
	-- Do not manage DHW while defrosting or when DHW is disabled.
	if @Defrosting_State == 0 && ?dhwEnable then
		-- Default scheduled run, with summer and cold-weather time overrides.
		$DHWTime = 13;
		if (%month > 3 && %month < 9) && %hour == 8 && #OutsideTemp > 20 then
			$DHWTime = 8;						-- Summer morning schedule
		elseif #OutsideTemp < 4 then
			$DHWTime = 0;						-- Cold-weather midnight schedule
		end
		-- Extra DHW opportunities when tank temperature is substantially low.
		$DHW10Condition = @DHW_Temp <= (@DHW_Target_Temp + @DHW_Heat_Delta - 10);
		$DHW9hCondition = @DHW_Temp <= (@DHW_Target_Temp + @DHW_Heat_Delta - 5) || @DHW_Temp < (#DHWTempP - 5);
		-- Scheduled request considers the sterilization day and comfort day.
		$DHWTimeCondition = (%day == #DHWSterilizationDay && @DHW_Temp < 50) ||
				(%day == #DHWComfortDay && @DHW_Temp < (@DHW_Target_Temp - 3)) || (@DHW_Temp < (@DHW_Target_Temp + @DHW_Heat_Delta));
		-- Start a new Rules-controlled DHW run only if the valve is in heating position.
		if #DHWRun < 1 && @ThreeWay_Valve_State == 0 && ( ($DHW10Condition) || (%hour >= 9 && ($DHW9hCondition)) ||
			(%hour == $DHWTime && ($DHWTimeCondition)) ) then
			#DHWRun = 2;						-- Rules-initiated DHW run
			-- Save operating state and heat-pump state for restoration after DHW.
			#OMP = @Operating_Mode_State;
			#HPStateP = @Heatpump_State;
			if #OMP == 0 then
				#OMR = 4;
			elseif #OMP == 1 then
				#OMR = 5;
			else
				#OMR = 3;
			end
			#HPStateR = 1;
		elseif #DHWRun > 0 && #DHWRun < 3 then
			-- Mark an early sterilization request by adding 10 to the configured day.
			if %day > (#DHWSterilizationDay - 2) && @ThreeWay_Valve_State == 1 && #CompState > 0 && @Sterilization_State != 1 then
				@SetForceSterilization = 1;
				#DHWSterilizationDay = #DHWSterilizationDay + 10;
			elseif @ThreeWay_Valve_State == 0 && @DHW_Temp >= @DHW_Target_Temp && @Defrosting_State == 0 && @Sterilization_State == 1 then
				#DHWRun = 1;					-- DHW finished; sterilization still active
			elseif @ThreeWay_Valve_State == 0 && @DHW_Temp >= @DHW_Target_Temp && @Defrosting_State == 0 && @Sterilization_State == 0 then
				#OMR = max(0,#OMP);
				#OMP = @Operating_Mode_State;
				#HPStateR = #HPStateP;
				#HPStateP = 1;
				#DHWRun = 0;					-- DHW cycle fully finished
				-- Start heating after DHW with a fresh PI handover and overshoot state.
				#TaPIStepTime = -1;
				#TaDeltaTimer = 0;
				#TaDelta = 0;
			end
		end
		if %day == (#DHWSterilizationDay -10) && %hour > 15 then
			#DHWSterilizationDay = #DHWSterilizationDay - 10;
		end
		#DHWTempP = @DHW_Temp;
	end
end


--[[
timer=6: Maximum circulation-pump duty
Purpose:	Adapt maximum pump duty to operating mode and hydraulic conditions.
Explanation:	DHW permits a high pump duty, with a small reduction near the end of a run. Cooling uses a fixed duty. When the heat pump is on but the
		compressor is idle, duty is based on @Heat_Delta. During heating, desired flow depends on outside temperature. Low flow may request a small
		increase to avoid E62; otherwise the calculated flow and pump-speed/flow ratio govern adjustment. The resulting duty has a minimum of 82 and is
		sent only if different.
Result:		Possibly @SetMaxPumpDuty; local $MaxPumpDuty and $MaxPumpFlow.
Called by:	Scheduled from timer=1 after 40 seconds; repeats every 60 seconds.
rule 10]]
on timer=6 then
	setTimer(6, 60);
	$MaxPumpDuty = 102 - 4 * @Heat_Delta;
	-- DHW circulation requires high pump duty but less duty near completion.
	if @ThreeWay_Valve_State == 1 then
		$MaxPumpDuty = 140;				-- DHW circulation
		if (@Sterilization_State == 0 && @DHW_Temp > @DHW_Target_Temp) || (@Sterilization_State == 1 && @DHW_Temp > 57) then
			$MaxPumpDuty = $MaxPumpDuty - 10;
		end
	-- Cooling uses a fixed maximum pump duty.
	elseif @Operating_Mode_State == 1 then
		$MaxPumpDuty = 92;				-- Cooling
	-- For heating, distinguish compressor idle from active circulation.
	elseif @Heatpump_State == 1 then
		if @Compressor_Freq == 0 && @Defrosting_State != 1 then
			$MaxPumpDuty = 112 - 4 * @Heat_Delta;
		else
			-- Desired heating flow increases as outside temperature falls.
			$MaxPumpFlow = min(max(ceil(10 + (11 - #OutsideTemp) * 6 / 14), 10), 16);
			-- Increase duty when flow is low; otherwise use the flow target.
			if @Pump_Flow > 1 && @Pump_Flow < 8 && $MaxPumpDuty <= @Max_Pump_Duty then
				$MaxPumpDuty = @Max_Pump_Duty + 1;
			else
				$MaxPumpDuty = 55 + floor($MaxPumpFlow * 3);
				-- Pump speed/flow ratio can limit further duty reduction.
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
	-- Do not reduce duty below 82 (hydraulic safeguard).
	$MaxPumpDuty = max($MaxPumpDuty, 82);
	if @Max_Pump_Duty != $MaxPumpDuty then
		@SetMaxPumpDuty = $MaxPumpDuty;
	end
end


--[[
timer=7: Quiet-mode selection
Purpose:	Select compressor quiet mode according to load, temperature and operating state.
Explanation:	The temperature-dependent compressor-frequency reference is limited to 24–54 Hz. Defrost, startup, compressor-off, early night/morning and
		cooling conditions force quiet mode level 3. Otherwise frequency thresholds with hysteresis select levels 0–3. Daytime DHW may reduce the
		selected level by one. @Buffer_Tank_Delta below 4 overrides the normal selection.
Result:		#CompFreqTarget, #QMR and possibly @SetQuietMode.
Called by:	Scheduled from timer=1 after 45 seconds; repeats every 120 seconds.
rule 11]]
on timer=7 then
	setTimer(7,120);
	-- Outside-temperature reference for compressor frequency (24–54 Hz).
	#CompFreqTarget = min(max(ceil(24 + (6 - #OutsideTemp) * 30 / 9), 24), 54);
	-- Conditions where compressor limitation takes precedence.
	if @Defrosting_State == 1 || #CompState < 1 || #CompRunMin < 5 || %hour < 7 || @Operating_Mode_State == 1 then
		#QMR = 3;					-- Maximum compressor limitation
	-- Select mode from frequency thresholds with hysteresis.
	elseif @Compressor_Freq < #CompFreqTarget || (#QMR == 0 && @Compressor_Freq < #CompFreqTarget + 6) then
		#QMR = 0;
	elseif @Compressor_Freq < #CompFreqTarget + 6 || (#QMR == 1 && @Compressor_Freq < #CompFreqTarget + 12) then
		#QMR = 1;
	elseif @Compressor_Freq < #CompFreqTarget + 26 || (#QMR == 2 && @Compressor_Freq < #CompFreqTarget + 32) then
		#QMR = 2;
	else
		#QMR = 3;					-- Maximum compressor limitation
	end
	-- Relax quiet mode by one level for daytime DHW when applicable.
	$QMDHW = 0;
	if #QMR > 0 && @ThreeWay_Valve_State && %hour > 9 && %hour < 17 then
		$QMDHW = -1;					-- Relax one level during daytime DHW
	end
	-- The buffer-tank setting has priority over computed quiet mode.
	if @Buffer_Tank_Delta < 4 then
		@SetQuietMode = @Buffer_Tank_Delta;
	elseif #QMR != @Quiet_Mode_Level then
		@SetQuietMode = #QMR + $QMDHW;
	end
end


--[[
timer=8: OpenTherm and heat-pump synchronization
Purpose:	Exchange operating values and synchronize requested heat-pump state.
Explanation:	Publishes measured temperatures, estimated modulation and heating/DHW/ cooling status to OpenTherm. Filters the cooling request and outside
		temperature; the latter uses a 59/60 + 1/60 update every 30 seconds. With GPIO33 = 1, room-temperature hysteresis sets #chEnable independently
		of Evohome. Otherwise the OpenTherm ?chEnable OFF state must persist for more than 15 minutes before #chEnable is cleared. Its elapsed duration
		is tracked with sign (+ enabled, - disabled) and a weekly wrap correction. Requests for operating mode and heat-pump ON/OFF are sent only when
		needed. During a detected external DHW run (#DHWRun = 3), HP state is not overwritten.
Result:		OpenTherm status outputs, filtered # state and heat-pump commands.
Called by:	Scheduled from timer=1 after 50 seconds; repeats every 30 seconds.
rule 12]]
on timer=8 then
	setTimer(8,30);
	-- Publish measured heat-pump temperatures to OpenTherm.
	?outletTemp = round(@Main_Outlet_Temp);
	?inletTemp = round(@Main_Inlet_Temp);
	?outsideTemp = round(#OutsideTemp);
	?dhwTemp = round(@DHW_Temp);
	?dhwSetpoint = @DHW_Target_Temp;
	-- Low-pass filter cooling requests to suppress short glitches.
	#CoolingEnable = #CoolingEnable + 0.1 * (?CoolingEnable - #CoolingEnable);
	#RoomSetpoint = min(max(?roomTempSet, 10), 22);
	#RoomTemp = ?roomTemp;
	#RoomTempDelta = #RoomTemp - #RoomSetpoint;
	-- HEMS Dim: ignore Evohome chEnable and use room-temperature hysteresis.
	if gpio(33) == 1 then
		#chEnableTimeOff = -1;
		if (#RoomTempDelta < 0 && #chEnable == 0) || (#RoomTempDelta > 0.2 && #chEnable == 1) then
			#chEnable = 1 - #chEnable;					-- Toggle with room-temperature hysteresis
			#chEnableChangeTime = #Time;
		end
	else
		-- Normal mode: tolerate short Evohome chEnable-off intervals.
		if ?chEnable == 1 then
			#chEnableTimeOff = -1;
			if #chEnable == 0 then
				#chEnableChangeTime = #Time;
				#chEnable = 1;
			end
		else
			if #chEnableTimeOff < 0 then
				#chEnableTimeOff = #Time;
			end
			$chEnableOffElapsed = (#Time - #chEnableTimeOff + 10080) % 10080;
			if $chEnableOffElapsed > 15 && #chEnable == 1 then		-- Require >15 minutes continuously OFF
				#chEnable = 0;
				#chEnableChangeTime = #Time;
			end
		end
	end
	-- Signed duration of filtered chEnable, with weekly rollover correction.
	$chEnableElapsed = (#Time - #chEnableChangeTime + 10080) % 10080;
	if #chEnable == 1 then
		#chEnableOnMin = $chEnableElapsed;
	else
		#chEnableOnMin = 0 - $chEnableElapsed;
	end
	-- Publish setpoint cap and operating status to OpenTherm.
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
	-- Smooth outside temperature on every 30-second timer call.
	#OutsideTemp = (#OutsideTemp * 59 + @Outside_Temp)/60;
	-- Issue heat-pump commands only when the actual and requested states differ.
	if @Operating_Mode_State != #OMR then
		@SetOperationMode = #OMR;
	end
	if @Heatpump_State != #HPStateR && #DHWRun != 3 then
		@SetHeatpump = #HPStateR;
	end
	-- Mode 0 or 4 means space-heating logic may be used.
	if @Operating_Mode_State == 0 || @Operating_Mode_State == 4 then
		#Heat = 1;
	else
		#Heat = 0;
	end
end


--[[
timer=9: PI room correction for TaShift
Purpose:	Calculate room-temperature PI correction relative to #WCS.
Explanation:	#RoomTempDelta is actual room temperature minus setpoint; positive $RoomError means the room is too cold. Kp = 1.2; Ki = 0.05 per five minutes.
		#PIDintegral is the I contribution in degrees C, not accumulated room error. Both integral and total PI output are limited to +/-5 C. The entire
		PI calculation pauses during DHW or while Evohome's temporary 12 C OFF setpoint is active; the previous output and integral are held. Normal
		room demand resumes only when the valve is back in heating position and the normal setpoint returns. Conditional integration limits windup;
		during other temporary heating interruptions, the P output still follows room error while the I contribution is held.
Result:		#PIDintegral and #RoomTempControl (degrees C).
Called by:	Scheduled from timer=1 after 55 seconds; repeats every 300 seconds.
rule 13]]
on timer=9 then
	setTimer(9,300);
	-- Independent controller parameters and correction limits (in C).
	$Kp = 1.2;									-- Proportional gain
	$Ki = 0.05;									-- Integral gain per five-minute sample
	$Ilimit = 5;									-- Maximum I contribution in C
	$PIlimit = 5;									-- Maximum total PI correction in C
	-- Evohome is temporarily OFF (12 C) during DHW: hold both I state and PI output.
	-- Resume only after the valve is back, DHW has finished and the normal setpoint is restored.
	if #DHWRun < 1 && @ThreeWay_Valve_State == 0 && ?roomTempSet > 12 && #RoomSetpoint > 12 then
		$RoomError = #RoomTempDelta * -1;
		$PIp = $Kp * $RoomError;
		-- Integrate only while room heating is considered available.
		if #chEnable == 1 && #Heat == 1 && #DHWRun < 2 && @ThreeWay_Valve_State == 0 && @Defrosting_State == 0 && #RoomTempDelta <= 0.2 then
			-- Store the I contribution itself, always limited to +/-5 C.
			$PIintegralNext = min(max(#PIDintegral + $Ki * $RoomError, $Ilimit * -1), $Ilimit);
			$PIcandidate = $PIp + $PIintegralNext;
			-- Conditional anti-windup allows unwinding but blocks further saturation.
			if ($PIcandidate <= $PIlimit || $RoomError <= 0) && ($PIcandidate >= $PIlimit * -1 || $RoomError >= 0) then
				#PIDintegral = $PIintegralNext;
			end
		end
		-- The I contribution is held during interruptions and setpoint changes.
		$PIoutput = $PIp + #PIDintegral;
		#RoomTempControl = round(min(max($PIoutput, $PIlimit * -1), $PIlimit));		-- Rounded correction for TaShift
	end
end


--[[
timer=10:	Weather Compensation
Purpose:	Calculate the weather-compensated heating baseline (#WCS).
Explanation:	The baseline follows a linear heating curve with two outside-temperature points. Ta1/Ta2 are the heating targets at outside temperatures Tb1/Tb2
		respectively. Ta2 is fixed at 36 C because the heat pump uses Direct mode; the corresponding heat-pump curve target cannot be used as a stable
		input in this configuration. The result is rounded up and limited to the interval Ta1–Ta2. TaShift subsequently applies its own adjustments. The
		configuration assumes Tb1 and Tb2 are different.
Result:		#WCS, weather-compensated heating target in C.
Called by:	Scheduled from timer=1 after 22 seconds; repeats every 1800 seconds.
rule 14]]
on timer=10 then
	setTimer(10,1800);
	$Ta1 = @Z1_Heat_Curve_Target_Low_Temp;			-- Target at Tb1
	$Ta2 = 36;						-- Target at Tb2 (Direct mode)
	$Tb1 = @Z1_Heat_Curve_Outside_High_Temp;		-- Higher outside-temperature point
	$Tb2 = @Z1_Heat_Curve_Outside_Low_Temp;			-- Lower outside-temperature point

	-- Interpolate between the two curve points; round up and clamp the result.
	#WCS = min(max(ceil($Ta1 + ($Tb1 - #OutsideTemp) * ($Ta2 - $Ta1) / ($Tb1 - $Tb2)), $Ta1), $Ta2);
end


--[[
timer=11: Compressor start-duration counter
Purpose:	Track elapsed seconds during an observed compressor startup.
Explanation:	The counter starts after the compressor-start event. It advances by five seconds while below 1100, then stops scheduling itself. If the
		compressor was already running when Rules loaded, timer=1 uses a sentinel value of 1999. TaShift uses this value to distinguish early startup
		from steady running.
Result:		#CompRunSec, expressed in seconds.
Called by:	@Compressor_Freq schedules the first call after 1 second; then every 5 seconds.
rule 15]]
on timer=11 then
	#CompRunSec = #CompRunSec + 5;
	-- The threshold is 1100 seconds, not ten minutes.
	if #CompRunSec < 1100 then
		setTimer(11,5);
	end
end


--[[
timer=12: Sustained outlet-temperature overshoot counter
Purpose:	Accumulate time during a persistent outlet/target temperature difference.
Explanation:	TaShift starts this timer once #TaDelta reaches 2 C and uses its value for overshoot protection. It advances in 10-second increments up to 200
		seconds while #TaDelta remains at least 2 C. TaShift or a compressor stop can reset #TaDeltaTimer to zero.
Result:		#TaDeltaTimer, expressed in seconds.
Called by:	Started by TaShift; repeats every 10 seconds while its conditions hold.
rule 16]]
on timer=12 then
	-- Only count persistent overshoot, stopping at 200 seconds.
	if #TaDeltaTimer < 200 && #TaDelta >= 2 then
		#TaDeltaTimer = #TaDeltaTimer + 10;
		setTimer(12, 10);
	end
end


--[[
TaShift2: Heating target management (part 2 of 2)
Purpose:	Apply PI handover, 1 C target steps, outlet safety corrections and the zone-2 priority; send the zone-1 request.
Explanation:	Receives $WCS from TaShift rather than recalculating it. The existing 10/15-minute PI step timing and original 2611.11
		control expressions are retained. $WCS is only used when #CompState > 0; the compressor-off path uses the precomputed #Z1HRT.
Result:		Final #Z1HRT, possible @SetZ1HeatRequestTemperature and PI-step state updates.
Called by:	TaShift via TaShift2($WCS) when heating is eligible.
rule 17]]
on TaShift2($WCS) then
	-- Handover from startup to PI-controlled targets; Z2 direct override bypasses it.
	if #CompState > 0 && @Defrosting_State == 0 && @Z2_Heat_Request_Temp <= 25 then
		-- An active PI phase holds the current request until a step is approved.
		if #TaPIStepTime >= 0 then
			#Z1HRT = @Z1_Heat_Request_Temp;
		end
		-- Each accepted PI step is capped at 1 C; the 15-minute escape restarts per step.
		if (#OutsideTemp <= 7 || #CompRunSec >= 130 || #CompRunSec == -1) && ((#TaPIStepTime < 0 &&
				(#CompRunMin >= 15 || (#CompRunMin >= 2 && @Compressor_Freq <= #CompFreqTarget))) || (#TaPIStepTime >= 0 &&
				((#Time - #TaPIStepTime + 10080) % 10080 >= 15 || ((#Time - #TaPIStepTime + 10080) % 10080 >= 10 &&
				@Compressor_Freq <= #CompFreqTarget)))) then
			if $WCS + #RoomTempControl > @Z1_Heat_Request_Temp then
				#Z1HRT = min(@Z1_Heat_Request_Temp + 1, $WCS + #RoomTempControl);
			elseif $WCS + #RoomTempControl < @Z1_Heat_Request_Temp && @Main_Outlet_Temp <= @Z1_Heat_Request_Temp + 0.8 then
				#Z1HRT = max(@Z1_Heat_Request_Temp - 1, $WCS + #RoomTempControl);
			else
				#Z1HRT = @Z1_Heat_Request_Temp;
			end
			-- Reset the wait interval only when PI starts or a target step is accepted.
			if #TaPIStepTime < 0 || #Z1HRT != @Z1_Heat_Request_Temp then
				#TaPIStepTime = #Time;
			end
		end
		if #TaPIStepTime >= 0 then
			if #TaDeltaTimer >= 80 && ceil(@Main_Outlet_Temp - 1.8) > @Z1_Heat_Request_Temp then
				#Z1HRT = max(#Z1HRT, min(@Z1_Heat_Request_Temp + 1, ceil(@Main_Outlet_Temp - 1.8)));
				#TaPIStepTime = #Time;
			end
			if #TaDelta >= 3 && ceil(@Main_Outlet_Temp) - 2 > @Z1_Heat_Request_Temp then
				#Z1HRT = max(#Z1HRT, min(@Z1_Heat_Request_Temp + 1, ceil(@Main_Outlet_Temp) - 2));
				#TaPIStepTime = #Time;
			end
		end
	end
	-- A direct zone-2 request takes priority over PI target management.
	if @Z2_Heat_Request_Temp > 25 then
		#Z1HRT = @Z2_Heat_Request_Temp;
	end
	if #Z1HRT != @Z1_Heat_Request_Temp then
		@SetZ1HeatRequestTemperature = #Z1HRT;
	end
end
