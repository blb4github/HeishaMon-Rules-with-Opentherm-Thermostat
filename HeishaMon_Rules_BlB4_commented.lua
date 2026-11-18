-- This is the maintained source file; generate a loadable version with the minify tool. https://github.com/klaashoekstra94/heishamon_rules_minify
-- Version: 2611.16 (target stability: compressor-off hysteresis and guarded PI target reductions)
-- Requires the HeishaMon Rules build supporting more than 127 variables and GPIO33.

--[[
Overview:	Control a Panasonic WH-MDC07J3E5 for heating, cooling and DHW using HeishaMon, an Evohome OpenTherm thermostat via OTGW and selected Home
		Assistant values. The Rules are tailored to this installation. Validate all assumptions and limits before using them elsewhere.

Interfaces:	@ = heat-pump data or commands; ? = OpenTherm values; # = global Rules state; $ = local Rules variables.

Operation:	Startup state is initialized in timer=1, after required inputs exist. Timer=1 schedules the periodic Rules after initialization. #wcTarget is the
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
	print('BLB Heishamon_rules_2611.16.lua');
	-- Initialize state without reading unavailable boot-time inputs.
	#chStateMin = -1;					-- Signed minutes: on > 0, off < 0
	#chEnableChangeTime = -1;
	#otCHOffStartTime = -1;
	#cpFreqTarget = -1;
	#cpRunSec = -1;						-- Seconds; -1 means not yet known
	#cpRunMin = -1;						-- Signed running/stopped minutes
	#clEnable = -1;						-- Filtered cooling request
	-- Weekly DHW schedule defaults (1 = Sunday; 7 = Saturday).
	#hwComfortDay = 4;					-- Optional comfort-day DHW check
	#hwState = -1;						-- 0 idle, 1 finishing, 2 Rules DHW, 3 detected DHW
	#hwSterilizationDay = 7;				-- Saturday by default
	#hpHeatingMode = -1;
	#hpModePrev = -1;					-- Saved operating mode during DHW
	#qmReq = -1;						-- Requested quiet-mode level
	-- Start the PI with no accumulated correction.
	#piIntegral = 0;
	#rtDelta = 0;						-- Actual room temperature minus setpoint
	#piCorrection = 0;
	#piStepTime = -1;					-- -1 = PI handover not active
	setTimer(1,10);
end


--[[
timer=1: Startup initialization
Purpose:	Initialize live state once the required heat-pump and OpenTherm values exist.
Explanation:	Eight required inputs are checked with isset(). If an input is missing, initialization retries after five seconds; the other periodic timers are
		scheduled only on the successful branch. The current operating mode, heat-pump state, room values and baseline target are copied into controller
		state. If the compressor is already running, state 2 and a 1999-second sentinel avoid treating it as a fresh start. A DHW valve state detected
		at startup uses #hwState = 3. The existing timer-start order and delays are retained.
Result:		Initial # state from live inputs; schedules timers 2 through 10.
Called by:	System#Boot after 10 seconds; retries every 5 seconds until ready.
rule 02]]
on timer=1 then
	-- Do not start periodic control until these eight required inputs are valid.
	if isset(@Heatpump_State) && isset(@Operating_Mode_State) && isset(@Outside_Temp) && isset(@Z1_Heat_Request_Temp) && isset(@Compressor_Freq) &&
		isset(?roomTempSet) && isset(?roomTemp) && isset(?chEnable) then
		#Time = %day * 1440 + %hour * 60 + %minute;
		#cpStateChangeTime = #Time;
		#chEnableChangeTime = #Time;
		#hpStateReq = @Heatpump_State;
		#hpStatePrev = @Heatpump_State;
		#hpModeReq = @Operating_Mode_State;
		#hpOutsideTemp = @Outside_Temp;
		#rtSetpoint = min(max(?roomTempSet, 10), 22);		-- Clamp room setpoint to 10–22 C
		#rtTemp = ?roomTemp;
		#wcTarget = @Z1_Heat_Request_Temp;
		-- Recover a run already in progress without applying fresh-start timing.
		if @Compressor_Freq > 18 then
			#cpState = 2;					-- Compressor already running at reload
			#piStepTime = #Time;
			#cpRunSec = 1999;				-- Sentinel: bypass fresh-start phase
		else
			#cpState = 0;
		end
		-- If DHW is active at reload, record it without restarting DHW control.
		if @ThreeWay_Valve_State then
			#hwState = 3;					-- DHW already in progress at reload
		end
		#chEnable = ?chEnable;
		#hwTempLast = @DHW_Temp;
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
Explanation:	#Time uses day, hour and minute; 10080 is the number of minutes in a week. The modulo expression handles the weekly wrap. #cpRunMin is
		positive while the compressor runs and negative while it is stopped. The reference time for each compressor-state change is set by the
		@Compressor_Freq event Rule.
Result:		#Time and #cpRunMin, expressed in minutes.
Called by:	Scheduled from timer=1 after 10 seconds; repeats every 60 seconds.
rule 03]]
on timer=2 then
	setTimer(2,60);
	#Time = %day * 1440 + %hour * 60 + %minute;
	-- Correct the elapsed duration for the wrap at the end of a week.
	$cpElapsedMin = (#Time - #cpStateChangeTime + 10080) % 10080;
	if @Compressor_Freq > 10 then
		#cpRunMin = $cpElapsedMin;
	else
		#cpRunMin = 0 - $cpElapsedMin;			-- Negative duration indicates compressor OFF
	end
end


--[[
@Compressor_Freq: Compressor transitions
Purpose:	Detect compressor start/stop transitions and maintain related timing state.
Explanation:	A frequency above 10 Hz changes an idle compressor to running state 1. A frequency below 10 Hz changes a running compressor to stopped state 0.
		At startup, timer=1 may use state 2 for an already-running compressor. Starting a new run resets its counters and the controlled PI-step phase,
		and schedules timer=11. Stopping resets the overshoot and PI-step timers.
Result:		#cpState, #cpStateChangeTime, run counters and PI-step state.
Called by:	Every @Compressor_Freq update.
rule 04]]
on @Compressor_Freq then
	-- A hysteresis gap at exactly 10 Hz avoids treating that value as a transition.
	if @Compressor_Freq > 10 && #cpState == 0 then
		#cpStateChangeTime = #Time;
		#cpState = 1;					-- Compressor started after Rules boot
		#cpRunSec = 0;
		#cpRunMin = 0;
		#piStepTime = -1;
		setTimer(11,1);
	elseif @Compressor_Freq < 10 && #cpState > 0 then
		#cpStateChangeTime = #Time;
		#cpState = 0;
		#cpRunMin = 0;
		#taDeltaSec = 0;				-- Clear outlet overshoot tracking
		#piStepTime = -1;
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
	if #cpRunSec < 150 || #taDeltaSec > 0 then
		setTimer(3,15);
	else
		setTimer(3,60);
	end
	TaShift();
end


--[[
TaShift: Heating target management (part 1 of 2)
Purpose:	Validate heating conditions and calculate the initial zone-1 request.
Explanation:	Preserves the original 2611.11 DHW/defrost gate, compressor-start logic, WAR-adjusted $wcAdjusted, outlet overshoot protection and baseline request.
		$wcAdjusted is calculated once while the compressor runs and passed unchanged to TaShift2. With the compressor stopped, $wcAdjusted is NULL.
		The short TaShift2 call removes the oversized conditional jump while preserving the original decision sequence.
Result:		#taShift and preliminary #taZ1ReqTemp; invokes TaShift2($wcAdjusted) in valid heating conditions.
Called by:	@Main_Outlet_Temp and timer=3.
rule 07]]
on TaShift then
	-- After defrost, require a new PI handover rather than reusing the old phase.
	if @Defrosting_State == 1 then
		#piStepTime = -1;									-- Restart PI handover after defrost
	end
	-- This gate also permits TaShift during defrost if pump flow is 5–30 l/min.
	#taDefrostAllowed = @Defrosting_State == 0 || (@Pump_Flow > 5 && @Pump_Flow < 30);
	if #hpHeatingMode == 1 && @ThreeWay_Valve_State == 0 && #hwState < 2 && #taDefrostAllowed == 1 then
		if #cpState > 0 then
			-- Zone-2 request can adjust the WAR reference by at most +/-5 C.
			$wcAdjusted = #wcTarget + min(max(@Z2_Heat_Request_Temp - 20,-5), 5);
			#taDelta = @Main_Outlet_Temp - @Z1_Heat_Request_Temp;
			-- During a warm-weather compressor start, reduce the target shift briefly.
			if #hpOutsideTemp > 7 && #cpRunSec < 130 && #cpRunSec != -1 then
				#taShift = ceil(@Main_Outlet_Temp) - 3 - $wcAdjusted;
			-- Hold the previous shift when the compressor is slow and no increase is needed.
			elseif @Compressor_Freq < 21 && max(#piCorrection,
				ceil(@Main_Outlet_Temp - 1.9 - $wcAdjusted)) < #taShift then
				print('no #taShift required');
			else
				#taShift = max(#piCorrection,ceil(@Main_Outlet_Temp - 1.9 - $wcAdjusted));
			end
			-- Monitor sustained outlet temperature above the current heating request.
			if #taDelta < 2 then
				#taDeltaSec = 0;
			elseif #taDeltaSec == 0 then
				#taDeltaSec = 10;
				setTimer(12,10);
			elseif #taDeltaSec >= 80 then
				#taShift = ceil(@Main_Outlet_Temp - 1.8 - $wcAdjusted);
			end
			-- Protect immediately against a larger outlet-temperature overshoot.
			if #taDelta >= 3 then
				#taShift = ceil(@Main_Outlet_Temp) - 2 - $wcAdjusted;
			end
		-- When the compressor is off, force low target or neutral target by conditions.
		elseif (%hour < 7 || %hour > 22 || #rtDelta > 0.2) then
			#taShift = -5;
		-- Keep the reduced request across small negative room deviations; existing off-time gate still applies.
		elseif #cpRunMin > (-2 * #hpOutsideTemp - 30) && (#rtDelta > 0.1 || (#rtDelta > -0.15 && #taShift == -5)) then
			#taShift = -5;
		else
			#taShift = 0;
		end
		-- Keep the generic shift within the supported +/-5 C range.
		#taShift = min(max(#taShift, -5), 5);
		#taZ1ReqTemp = coalesce($wcAdjusted, #wcTarget) + #taShift;				-- Use #wcTarget when local $wcAdjusted is unset
		if #cpState > 0 then
			#taZ1ReqTemp = min(#taZ1ReqTemp, max($wcAdjusted - 5, ceil(@Main_Outlet_Temp) - 1));
		end
		TaShift2($wcAdjusted);
	end
end


--[[
timer=4:	OpenTherm thermostat (heating and cooling)
Purpose:	Control the requested heat-pump state and operating mode for heating and cooling.
Explanation:	Heating uses filtered #chEnable, room-temperature deviation, compressor run/off time, outside temperature and time-of-day conditions. #hpHeatingMode, DHW
		and defrost conditions determine whether heating control is allowed. $chOverNight covers 23:00–02:59. $chRestartAllowed avoids prolonged
		inactivity when heating is requested and the compressor has been off for more than 60 minutes. Cooling follows #clEnable (filtered in
		timer=8). Cooling setpoints are limited by the requested temperature and outlet-temperature safeguards. #hpStateReq and #hpModeReq are requests; timer=8
		sends them to the heat pump.
Result:		#hpStateReq, #hpModeReq, possibly @SetZ1CoolRequestTemperature.
Called by:	Scheduled from timer=1 after 30 seconds; repeats every 60 seconds.
rule 08]]
on timer=4 then
	setTimer(4,60);
	-- Avoid thermostat control during sterilization and active DHW operation.
	if @Sterilization_State == 0 && #hwState < 2 then
		-- Heating control is permitted only in normal room-heating conditions.
		if #hpHeatingMode == 1 && @ThreeWay_Valve_State == 0 && @Defrosting_State == 0 then
			$chOverNight = %hour > 22 || %hour < 3;									-- Night period: 23:00–02:59
			$chRestartAllowed = #chEnable && #chStateMin > 60 && #cpRunMin < -60 && $chOverNight != 1;

			-- Start heating when heat is requested and at least one room/outside temperature condition is met.
			if #chEnable == 1 && (((#rtDelta < 0.2 || %hour == 7) && #hpOutsideTemp < 11) ||
				(#rtDelta < 1 && #hpOutsideTemp < 2) || #rtDelta < 0 || ($chRestartAllowed == 1 && #rtDelta < 2)) &&
				#hpStateReq != 1 then
				#hpStateReq = 1;										-- Request heat pump ON

			-- Stop heating only when room-demand and compressor timing conditions
			-- permit it; avoid unnecessary circulation-pump stops in cold weather.
			elseif ((#rtDelta > 0.2 && %hour > 9) || #rtDelta > 1.5 || (#chEnable == 0 && #chStateMin < -30)) &&
				(#cpRunMin > 60 || #cpState == 0 || $chOverNight) && (#hpOutsideTemp > 4 || (#chEnable == 0 && $chOverNight)) &&
				$chRestartAllowed == 0 && #hpStateReq != 0 then
				#hpStateReq = 0;										-- Request heat pump OFF
				if #hpModeReq != 0 && #hpModeReq != 3 then
					#hpModeReq = 0;										-- Return to heating mode unless in DHW-only mode
				end
			end
		end

		-- Cooling is handled separately from the heating conditions above.
		$clEnable = max(round(#clEnable),0);							-- Use filtered cooling request
		if $clEnable == 1 then
			#hpModeReq = 1;									-- Request cooling mode
			#hpStateReq = 1;								-- Keep heat pump ON
			$clOffset = 0;
			if #cpState == 1 then
				$clReqTempMin = min(round(@Main_Outlet_Temp), 19);
			else
				$clReqTempMin = 0;
				if @Main_Outlet_Temp > (@Main_Target_Temp + 3) then
					$clOffset = -2;							-- Lower cooling request when outlet is too warm
				end
			end

			-- Apply the cooling request only when the target actually changes.
			$clReqTemp = max((?coolingControl + $clOffset), 12, $clReqTempMin);
			if @Z1_Cool_Request_Temp != $clReqTemp then
				@SetZ1CoolRequestTemperature = $clReqTemp;
			end
		elseif $clEnable == 0 && #hpModeReq == 1 && #hwState < 2 && #cpState == 0 then
			#hpModeReq = 0;									-- Leave cooling mode when compressor has stopped
			#hpStateReq = 0;								-- Request heat pump OFF
		end
	end
end


--[[
timer=5: Domestic hot water and sterilization
Purpose:	Schedule DHW production and the weekly sterilization opportunity.
Explanation:	The regular DHW check is at 13:00, moved to 08:00 during specified warm summer conditions or 00:00 when outside temperature is below 4 C.
		Additional temperature thresholds can start DHW immediately or after 09:00. On the comfort day a lower threshold applies; on the sterilization
		day a DHW run is requested if the tank is below 50 C. When a Rules-initiated DHW run starts, the prior operating mode and heat-pump state are
		saved. Sterilization may be advanced to the preceding day; adding 10 to #hwSterilizationDay marks it as already requested for that week. After
		DHW completion, previous operating settings are restored.
Result:		#hwState, #hpModePrev, #hpModeReq, #hpStateReq and DHW/sterilization commands.
Called by:	Scheduled from timer=1 after 35 seconds; repeats every 900 seconds.
rule 09]]
on timer=5 then
	setTimer(5,900);
	-- Do not manage DHW while defrosting or when DHW is disabled.
	if @Defrosting_State == 0 && ?dhwEnable then
		-- Default scheduled run, with summer and cold-weather time overrides.
		$hwStartHour = 13;
		if (%month > 3 && %month < 9) && %hour == 8 && #hpOutsideTemp > 20 then
			$hwStartHour = 8;								-- Summer morning schedule
		elseif #hpOutsideTemp < 4 then
			$hwStartHour = 0;								-- Cold-weather midnight schedule
		end
		-- Extra DHW opportunities when tank temperature is substantially low.
		$hwDeepLow = @DHW_Temp <= (@DHW_Target_Temp + @DHW_Heat_Delta - 10);
		$hwLowOrDrop = @DHW_Temp <= (@DHW_Target_Temp + @DHW_Heat_Delta - 5) || @DHW_Temp < (#hwTempLast - 5);
		-- Scheduled request considers the sterilization day and comfort day.
		$hwScheduleEligible = (%day == #hwSterilizationDay && @DHW_Temp < 50) ||
				(%day == #hwComfortDay && @DHW_Temp < (@DHW_Target_Temp - 3)) || (@DHW_Temp < (@DHW_Target_Temp + @DHW_Heat_Delta));
		-- Start a new Rules-controlled DHW run only if the valve is in heating position.
		if #hwState < 1 && @ThreeWay_Valve_State == 0 && ( ($hwDeepLow) || (%hour >= 9 && ($hwLowOrDrop)) ||
			(%hour == $hwStartHour && ($hwScheduleEligible)) ) then
			#hwState = 2;									-- Rules-initiated DHW run
			-- Save operating state and heat-pump state for restoration after DHW.
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
			-- Mark an early sterilization request by adding 10 to the configured day.
			if %day > (#hwSterilizationDay - 2) && @ThreeWay_Valve_State == 1 && #cpState > 0 && @Sterilization_State != 1 then
				@SetForceSterilization = 1;
				#hwSterilizationDay = #hwSterilizationDay + 10;
			elseif @ThreeWay_Valve_State == 0 && @DHW_Temp >= @DHW_Target_Temp && @Defrosting_State == 0 && @Sterilization_State == 1 then
				#hwState = 1;								-- DHW finished; sterilization still active
			elseif @ThreeWay_Valve_State == 0 && @DHW_Temp >= @DHW_Target_Temp && @Defrosting_State == 0 && @Sterilization_State == 0 then
				#hpModeReq = max(0,#hpModePrev);
				#hpModePrev = @Operating_Mode_State;
				#hpStateReq = #hpStatePrev;
				#hpStatePrev = 1;
				#hwState = 0;								-- DHW cycle fully finished
				-- Start heating after DHW with a fresh PI handover and overshoot state.
				#piStepTime = -1;
				#taDeltaSec = 0;
				#taDelta = 0;
			end
		end
		if %day == (#hwSterilizationDay -10) && %hour > 15 then
			#hwSterilizationDay = #hwSterilizationDay - 10;
		end
		#hwTempLast = @DHW_Temp;
	end
end


--[[
timer=6: Maximum circulation-pump duty
Purpose:	Adapt maximum pump duty to operating mode and hydraulic conditions.
Explanation:	DHW permits a high pump duty, with a small reduction near the end of a run. Cooling uses a fixed duty. When the heat pump is on but the
		compressor is idle, duty is based on @Heat_Delta. During heating, desired flow depends on outside temperature. Low flow may request a small
		increase to avoid E62; otherwise the calculated flow and pump-speed/flow ratio govern adjustment. The resulting duty has a minimum of 82 and is
		sent only if different.
Result:		Possibly @SetMaxPumpDuty; local $puMaxDuty and $puFlowTarget.
Called by:	Scheduled from timer=1 after 40 seconds; repeats every 60 seconds.
rule 10]]
on timer=6 then
	setTimer(6, 60);
	$puMaxDuty = 102 - 4 * @Heat_Delta;
	-- DHW circulation requires high pump duty but less duty near completion.
	if @ThreeWay_Valve_State == 1 then
		$puMaxDuty = 140;												-- DHW circulation
		if (@Sterilization_State == 0 && @DHW_Temp > @DHW_Target_Temp) || (@Sterilization_State == 1 && @DHW_Temp > 57) then
			$puMaxDuty = $puMaxDuty - 10;
		end
	-- Cooling uses a fixed maximum pump duty.
	elseif @Operating_Mode_State == 1 then
		$puMaxDuty = 92;												-- Cooling
	-- For heating, distinguish compressor idle from active circulation.
	elseif @Heatpump_State == 1 then
		if @Compressor_Freq == 0 && @Defrosting_State != 1 then
			$puMaxDuty = 112 - 4 * @Heat_Delta;
		else
			-- Desired heating flow increases as outside temperature falls.
			$puFlowTarget = min(max(ceil(10 + (11 - #hpOutsideTemp) * 6 / 14), 10), 16);
			-- Increase duty when flow is low; otherwise use the flow target.
			if @Pump_Flow > 1 && @Pump_Flow < 8 && $puMaxDuty <= @Max_Pump_Duty then
				$puMaxDuty = @Max_Pump_Duty + 1;
			else
				$puMaxDuty = 55 + floor($puFlowTarget * 3);
				-- Pump speed/flow ratio can limit further duty reduction.
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
	-- Do not reduce duty below 82 (hydraulic safeguard).
	$puMaxDuty = max($puMaxDuty, 82);
	if @Max_Pump_Duty != $puMaxDuty then
		@SetMaxPumpDuty = $puMaxDuty;
	end
end


--[[
timer=7: Quiet-mode selection
Purpose:	Select compressor quiet mode according to load, temperature and operating state.
Explanation:	The temperature-dependent compressor-frequency reference is limited to 24–54 Hz. Defrost, startup, compressor-off, early night/morning and
		cooling conditions force quiet mode level 3. Otherwise frequency thresholds with hysteresis select levels 0–3. Daytime DHW may reduce the
		selected level by one. @Buffer_Tank_Delta below 4 overrides the normal selection.
Result:		#cpFreqTarget, #qmReq and possibly @SetQuietMode.
Called by:	Scheduled from timer=1 after 45 seconds; repeats every 120 seconds.
rule 11]]
on timer=7 then
	setTimer(7,120);
	-- Outside-temperature reference for compressor frequency (24–54 Hz).
	#cpFreqTarget = min(max(ceil(24 + (6 - #hpOutsideTemp) * 30 / 9), 24), 54);
	-- Conditions where compressor limitation takes precedence.
	if @Defrosting_State == 1 || #cpState < 1 || #cpRunMin < 5 || %hour < 7 || @Operating_Mode_State == 1 then
		#qmReq = 3;												-- Maximum compressor limitation
	-- Select mode from frequency thresholds with hysteresis.
	elseif @Compressor_Freq < #cpFreqTarget || (#qmReq == 0 && @Compressor_Freq < #cpFreqTarget + 6) then
		#qmReq = 0;
	elseif @Compressor_Freq < #cpFreqTarget + 6 || (#qmReq == 1 && @Compressor_Freq < #cpFreqTarget + 12) then
		#qmReq = 1;
	elseif @Compressor_Freq < #cpFreqTarget + 26 || (#qmReq == 2 && @Compressor_Freq < #cpFreqTarget + 32) then
		#qmReq = 2;
	else
		#qmReq = 3;												-- Maximum compressor limitation
	end
	-- Relax quiet mode by one level for daytime DHW when applicable.
	$qmDHWOffset = 0;
	if #qmReq > 0 && @ThreeWay_Valve_State && %hour > 9 && %hour < 17 then
		$qmDHWOffset = -1;											-- Relax one level during daytime DHW
	end
	-- The buffer-tank setting has priority over computed quiet mode.
	if @Buffer_Tank_Delta < 4 then
		@SetQuietMode = @Buffer_Tank_Delta;
	elseif #qmReq != @Quiet_Mode_Level then
		@SetQuietMode = #qmReq + $qmDHWOffset;
	end
end


--[[
timer=8: OpenTherm and heat-pump synchronization
Purpose:	Exchange operating values and synchronize requested heat-pump state.
Explanation:	Publishes measured temperatures, estimated modulation and heating/DHW/ cooling status to OpenTherm. Filters the cooling request and outside
		temperature; the latter uses a 59/60 + 1/60 update every 30 seconds. With GPIO33 = 1, room-temperature hysteresis sets #chEnable independently
		of Evohome. Otherwise the OpenTherm ?chEnable OFF state must persist for more than 15 minutes before #chEnable is cleared. Its elapsed duration
		is tracked with sign (+ enabled, - disabled) and a weekly wrap correction. Requests for operating mode and heat-pump ON/OFF are sent only when
		needed. During a detected external DHW run (#hwState = 3), HP state is not overwritten.
Result:		OpenTherm status outputs, filtered # state and heat-pump commands.
Called by:	Scheduled from timer=1 after 50 seconds; repeats every 30 seconds.
rule 12]]
on timer=8 then
	setTimer(8,30);
	-- Publish measured heat-pump temperatures to OpenTherm.
	?outletTemp = round(@Main_Outlet_Temp);
	?inletTemp = round(@Main_Inlet_Temp);
	?outsideTemp = round(#hpOutsideTemp);
	?dhwTemp = round(@DHW_Temp);
	?dhwSetpoint = @DHW_Target_Temp;
	-- Low-pass filter cooling requests to suppress short glitches.
	#clEnable = #clEnable + 0.1 * (?CoolingEnable - #clEnable);
	#rtSetpoint = min(max(?roomTempSet, 10), 22);
	#rtTemp = ?roomTemp;
	#rtDelta = #rtTemp - #rtSetpoint;
	-- HEMS Dim: ignore Evohome chEnable and use room-temperature hysteresis.
	if gpio(33) == 1 then
		#otCHOffStartTime = -1;
		if (#rtDelta < 0 && #chEnable == 0) || (#rtDelta > 0.2 && #chEnable == 1) then
			#chEnable = 1 - #chEnable;									-- Toggle with room-temperature hysteresis
			#chEnableChangeTime = #Time;
		end
	else
		-- Normal mode: tolerate short Evohome chEnable-off intervals.
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
			if $otCHOffElapsedMin > 15 && #chEnable == 1 then						-- Require >15 minutes continuously OFF
				#chEnable = 0;
				#chEnableChangeTime = #Time;
			end
		end
	end
	-- Signed duration of filtered chEnable, with weekly rollover correction.
	$chElapsedMin = (#Time - #chEnableChangeTime + 10080) % 10080;
	if #chEnable == 1 then
		#chStateMin = $chElapsedMin;
	else
		#chStateMin = 0 - $chElapsedMin;
	end
	-- Publish setpoint cap and operating status to OpenTherm.
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
	-- Smooth outside temperature on every 30-second timer call.
	#hpOutsideTemp = (#hpOutsideTemp * 59 + @Outside_Temp)/60;
	-- Issue heat-pump commands only when the actual and requested states differ.
	if @Operating_Mode_State != #hpModeReq then
		@SetOperationMode = #hpModeReq;
	end
	if @Heatpump_State != #hpStateReq && #hwState != 3 then
		@SetHeatpump = #hpStateReq;
	end
	-- Mode 0 or 4 means space-heating logic may be used.
	if @Operating_Mode_State == 0 || @Operating_Mode_State == 4 then
		#hpHeatingMode = 1;
	else
		#hpHeatingMode = 0;
	end
end


--[[
timer=9: PI room correction for TaShift
Purpose:	Calculate room-temperature PI correction relative to #wcTarget.
Explanation:	#rtDelta is actual room temperature minus setpoint; positive $piError means the room is too cold. Kp = 1.2; Ki = 0.05 per five minutes.
		#piIntegral is the I contribution in degrees C, not accumulated room error. Both integral and total PI output are limited to +/-5 C. The entire
		PI calculation pauses during DHW or while Evohome's temporary 12 C OFF setpoint is active; the previous output and integral are held. Normal
		room demand resumes only when the valve is back in heating position and the normal setpoint returns. Conditional integration limits windup;
		during other temporary heating interruptions, the P output still follows room error while the I contribution is held.
Result:		#piIntegral and #piCorrection (degrees C).
Called by:	Scheduled from timer=1 after 55 seconds; repeats every 300 seconds.
rule 13]]
on timer=9 then
	setTimer(9,300);
	-- Independent controller parameters and correction limits (in C).
	$piKp = 1.2;												-- Proportional gain
	$piKi = 0.05;												-- Integral gain per five-minute sample
	$piIMin = -5;												-- Minimum I contribution in C
	$piIMax = 5;												-- Maximum I contribution in C
	$piMin = -5;												-- Minimum total PI correction in C
	$piMax = 5;												-- Maximum total PI correction in C
	-- Evohome is temporarily OFF (12 C) during DHW: hold both I state and PI output.
	-- Resume only after the valve is back, DHW has finished and the normal setpoint is restored.
	if #hwState < 1 && @ThreeWay_Valve_State == 0 && ?roomTempSet > 12 && #rtSetpoint > 12 then
		$piError = #rtSetpoint - #rtTemp;
		$piP = $piKp * $piError;
		-- Integrate only while room heating is considered available.
		if #chEnable == 1 && #hpHeatingMode == 1 && #hwState < 2 && @ThreeWay_Valve_State == 0 && @Defrosting_State == 0 && #rtDelta <= 0.2 then
			-- Store the I contribution itself, always limited to the set bounderies.
			$piIntegralNext = min(max(#piIntegral + $piKi * $piError, $piIMin), $piIMax);
			$piCandidate = $piP + $piIntegralNext;
			-- Conditional anti-windup allows unwinding but blocks further saturation.
			if ($piCandidate <= $piMax || $piError <= 0) && ($piCandidate >= $piMin || $piError >= 0) then
				#piIntegral = $piIntegralNext;
			end
		end
		-- The I contribution is held during interruptions and setpoint changes.
		$piOutput = $piP + #piIntegral;
		#piCorrection = round(min(max($piOutput, $piMin), $piMax));					-- Rounded correction for TaShift
	end
end


--[[
timer=10:	Weather Compensation
Purpose:	Calculate the weather-compensated heating baseline (#wcTarget).
Explanation:	The baseline follows a linear heating curve: $wcTargetLow applies at $wcOutsideHigh, and $wcTargetHigh applies at $wcOutsideLow.
		$wcTargetHigh is fixed at 36 C because the heat pump uses Direct mode; the corresponding heat-pump curve target cannot be used as a stable
		input in this configuration. The result is rounded up and limited to the interval $wcTargetLow–$wcTargetHigh. TaShift subsequently adjusts it. The
		configuration assumes $wcOutsideHigh and $wcOutsideLow are different.
Result:		#wcTarget, weather-compensated heating target in C.
Called by:	Scheduled from timer=1 after 22 seconds; repeats every 1800 seconds.
rule 14]]
on timer=10 then
	setTimer(10,1800);
	$wcTargetLow = @Z1_Heat_Curve_Target_Low_Temp;				-- Target at $wcOutsideHigh
	$wcTargetHigh = 36;							-- Target at $wcOutsideLow (Direct mode)
	$wcOutsideHigh = @Z1_Heat_Curve_Outside_High_Temp;			-- Higher outside-temperature point
	$wcOutsideLow = @Z1_Heat_Curve_Outside_Low_Temp;			-- Lower outside-temperature point

	-- Interpolate between the two curve points; round up and clamp the result.
	#wcTarget = min(max(ceil($wcTargetLow + ($wcOutsideHigh - #hpOutsideTemp) * ($wcTargetHigh - $wcTargetLow) / ($wcOutsideHigh - $wcOutsideLow)), $wcTargetLow), $wcTargetHigh);
end


--[[
timer=11: Compressor start-duration counter
Purpose:	Track elapsed seconds during an observed compressor startup.
Explanation:	The counter starts after the compressor-start event. It advances by five seconds while below 1100, then stops scheduling itself. If the
		compressor was already running when Rules loaded, timer=1 uses a sentinel value of 1999. TaShift uses this value to distinguish early startup
		from steady running.
Result:		#cpRunSec, expressed in seconds.
Called by:	@Compressor_Freq schedules the first call after 1 second; then every 5 seconds.
rule 15]]
on timer=11 then
	#cpRunSec = #cpRunSec + 5;
	-- The threshold is 1100 seconds, not ten minutes.
	if #cpRunSec < 1100 then
		setTimer(11,5);
	end
end


--[[
timer=12: Sustained outlet-temperature overshoot counter
Purpose:	Accumulate time during a persistent outlet/target temperature difference.
Explanation:	TaShift starts this timer once #taDelta reaches 2 C and uses its value for overshoot protection. It advances in 10-second increments up to 200
		seconds while #taDelta remains at least 2 C. TaShift or a compressor stop can reset #taDeltaSec to zero.
Result:		#taDeltaSec, expressed in seconds.
Called by:	Started by TaShift; repeats every 10 seconds while its conditions hold.
rule 16]]
on timer=12 then
	-- Only count persistent overshoot, stopping at 200 seconds.
	if #taDeltaSec < 200 && #taDelta >= 2 then
		#taDeltaSec = #taDeltaSec + 10;
		setTimer(12, 10);
	end
end


--[[
TaShift2: Heating target management (part 2 of 2)
Purpose:	Apply PI handover, 1 C target steps, outlet safety corrections and the zone-2 priority; send the zone-1 request.
Explanation:	Receives $wcAdjusted from TaShift rather than recalculating it. The existing 10/15-minute PI step timing and original 2611.11
		control expressions are retained. $wcAdjusted is only used when #cpState > 0; the compressor-off path uses the precomputed #taZ1ReqTemp.
Result:		Final #taZ1ReqTemp, possible @SetZ1HeatRequestTemperature and PI-step state updates.
Called by:	TaShift via TaShift2($wcAdjusted) when heating is eligible.
rule 17]]
on TaShift2($wcAdjusted) then
	-- Handover from startup to PI-controlled targets; Z2 direct override bypasses it.
	if #cpState > 0 && @Defrosting_State == 0 && @Z2_Heat_Request_Temp <= 25 then
		-- An active PI phase holds the current request until a step is approved.
		if #piStepTime >= 0 then
			#taZ1ReqTemp = @Z1_Heat_Request_Temp;
		end
		-- Each accepted PI step is capped at 1 C; the 15-minute escape restarts per step.
		if (#hpOutsideTemp <= 7 || #cpRunSec >= 130 || #cpRunSec == -1) && ((#piStepTime < 0 &&
				(#cpRunMin >= 15 || (#cpRunMin >= 2 && @Compressor_Freq <= #cpFreqTarget))) || (#piStepTime >= 0 &&
				((#Time - #piStepTime + 10080) % 10080 >= 15 || ((#Time - #piStepTime + 10080) % 10080 >= 10 &&
				@Compressor_Freq <= #cpFreqTarget)))) then
			if $wcAdjusted + #piCorrection > @Z1_Heat_Request_Temp then
				#taZ1ReqTemp = min(@Z1_Heat_Request_Temp + 1, $wcAdjusted + #piCorrection);
			elseif $wcAdjusted + #piCorrection < @Z1_Heat_Request_Temp then
				#taZ1ReqTemp = max(@Z1_Heat_Request_Temp - 1, $wcAdjusted + #piCorrection);
				-- Check the proposed lower target, not the current target, before allowing a down-step.
				if @Main_Outlet_Temp > #taZ1ReqTemp + 0.8 then
					#taZ1ReqTemp = @Z1_Heat_Request_Temp;
				end
			else
				#taZ1ReqTemp = @Z1_Heat_Request_Temp;
			end
			-- Reset the wait interval only when PI starts or a target step is accepted.
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
	-- A direct zone-2 request takes priority over PI target management.
	if @Z2_Heat_Request_Temp > 25 then
		#taZ1ReqTemp = @Z2_Heat_Request_Temp;
	end
	if #taZ1ReqTemp != @Z1_Heat_Request_Temp then
		@SetZ1HeatRequestTemperature = #taZ1ReqTemp;
	end
end
