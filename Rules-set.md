# Rules set for HeishaMon


function | Rules | Description
:--- | --- | ---
ALL|on System#Boot then|
DHW| #allowDHW = 1;|allow DHW function
OTT| #allowOTThermostat = 1;|allow OTT Thermostat function
PS| #allowPumpSpeed = 1;|allow PumpSpeed function
SM| #allowSilentMode = 1;|allow SilentMode function
SS| #allowSoftStart = 1;|allow SoftStart function
SyncOT| #allowSyncOT = 1;|allow Sync OT function
WAR| #allowWAR = 1;|allow WAR function
ALL||
SyncOT| #chEnable = -1;|set variables
SyncOT OTT| #chEnableOffTime=-1;|
SyncOT| #chEnableTimeOff=-1;|
OTT| #chSetPoint = -1;|
OTT| #compRunTime = -1;|
OTT| #compStartTime = -1;|
OTT| #compState = -1;|
DHW| #DHWRun = -1;|
DHW| #legionellaRunDay = 7;|
OTT| #mainTargetTemp = -1;|
PS| #maxPumpDuty = 85;|value which fits my installation (~ 11l/m)
WAR SyncOT| #maxTa = -1;|
SM| #mildMode = -1;|
DHW| #prevHeatPumpState = -1;|
DHW| #prevOperatingMode = -1;|
SM| #quietMode = -1;|
OTT SS| #softStartCorrection = 0;|
SS| #softStartPhase = -1;|
SyncOT OTT SM SS| #timeRef = -1;|
ALL| setTimer(1,10);|main timer which calls all functions
SyncOT OTT| setTimer(2,15);|timer for time reference
ALL|end|
ALL||
ALL|on timer=1 then|main timer which calls all functions
WAR| calculateWAR();|not required to remove them if you
SM| checkSilentMode();|don't need them, this is done with
SyncOT| syncOpenTherm();|the allow variable in the on boot
PS| maxPumpDuty();|block
DHW| checkDHW();|
OTT| OTThermostat();|
ALL| setTimer(1,15);|run this function every 15 seconds
ALL|end|
SyncOT OTT SS||
SyncOT OTT SS|on timer=2 then|timer for time reference
SyncOT OTT SS| #timeRef = %day * 1440 + %hour * 60 + %minute;|sync #timeRef with current time 
SyncOT OTT SS| setTimer(2,60);|run this function every  minute
SyncOT OTT SS|end|
SM||
SM|on checkSilentMode then|SilentMode function
SM| if isset(@Outside_Temp) == 1 && isset(@Heatpump_State) then|Sets #silentmode value depending on
SM|  if #allowSilentMode == 1 then|outside temperature and time of day
SM|   #allowSilentMode = 0;|
SM|   if @Outside_Temp < 10 then|
SM|    #silentMode = 2;|
SM|   else|
SM|    #silentMode = 3;|
SM|   end|
SM|   if @Outside_Temp < 5 then|
SM|    #silentMode = 1;|
SM|   end|
SM|   if @Outside_Temp < 2 then|
SM|    if %hour > 22 || %hour < 7 then|
SM|     #silentMode = 1;|
SM|    else|
SM|     #silentMode = 0;|
SM|    end|
SM|   end|
SM|   setTimer(3, 900);|this function runs every 15 minutes
SM|   setQuietMode();|
SM|  end|
SM| end|
SM|end|
SM||
SM|on timer=3 then|reset allow parameter
SM| #allowSilentMode = 1;|
SM|end|
SM||
SM|on setQuietMode then|Set QuietMode variable
SM| if #mildMode != -1 then|QuietMode will be #mildMode if 
SM|  #quietMode = #mildMode;|#mildMode is set, otherwise 
SM| else|#silentMode
SM|  #quietMode = #silentMode;|
SM| end|
SM| if @Quiet_Mode_Level != #quietMode then|
SM|  @SetQuietMode = #quietMode;|
SM| end|
SM|end|
SyncOT||
SyncOT|on syncOpenTherm then|Sync OT variable
SyncOT| if  #allowSyncOT == 1 then|
SyncOT|  ?outletTemp = @Main_Outlet_Temp;|
SyncOT|  ?inletTemp = @Main_Inlet_Temp;|
SyncOT|  ?outsideTemp = @Outside_Temp;|
SyncOT|  ?dhwTemp = @DHW_Temp;|
SyncOT|  ?dhwSetpoint = @DHW_Target_Temp;|
SyncOT|  if ?chEnable == 1 then|chEnable update is with some logic to
SyncOT|   #chEnable = 1;|keep #chEnable 1 if ?chEnable is 0 for 
SyncOT|   if #chEnableTimeOff != -1 then|only a short (5 minute) time
SyncOT|    #chEnableTimeOff = -1;|
SyncOT|    #chEnableOffTime = -1;|
SyncOT|   end|
SyncOT|  else|
SyncOT|   if #chEnableTimeOff == -1 then|
SyncOT|    #chEnableTimeOff = #timeRef;|
SyncOT|   end|
SyncOT|   #chEnableOffTime = #timeRef - #chEnableTimeOff;|#chEnableOffTime gives time in 
SyncOT|   if #chEnableOffTime < 0 then|minutes ?chEnable = 0
SyncOT|    #chEnableOffTime = #timeRef - #chEnableTimeOff + 10080;|
SyncOT|   end|
SyncOT|   if #chEnableOffTime > 5 then|#chEnable goes to 0 after 5 minutes
SyncOT|    #chEnable = 0;|
SyncOT|   end|
SyncOT|  end|
SyncOT|  #dhwEnable = ?dhwEnable;|
SyncOT|  if #maxTa != -1 then|sync ?maxTa with result of the WAR
SyncOT|   ?maxTSet = #maxTa;|function
SyncOT|  end|
SyncOT|  if @Compressor_Freq == 0 then|
SyncOT|   ?flameState = 0;|
SyncOT|   ?chState = 0;|
SyncOT|   ?dhwState = 0;|
SyncOT|  else|
SyncOT|   ?flameState = 1;|
SyncOT|   if @ThreeWay_Valve_State == 0 then|
SyncOT|    ?chState = 1;|
SyncOT|    ?dhwState = 0;|
SyncOT|   else|
SyncOT|    ?chState = 0;|
SyncOT|    ?dhwState = 1;|
SyncOT|   end|
SyncOT|  end|
SyncOT| end|
SyncOT|end|
WAR||
WAR|on calculateWAR then|Calculate WAR setpoint function
WAR| if #allowWAR == 1 then|
WAR|  if isset(@Z1_Heat_Curve_Target_Low_Temp) == 1 && isset(@Z1_Heat_Curve_Outside_High_Temp) == 1 && isset(@Z1_Heat_Curve_Target_High_Temp) == 1 && isset(@Z1_Heat_Curve_Outside_Low_Temp) == 1 then|
WAR|   $Ta1 = @Z1_Heat_Curve_Target_Low_Temp;|
WAR|   $Tb1 = @Z1_Heat_Curve_Outside_High_Temp;|
WAR|   $Ta2 = 36;|
WAR|   $Tb2 = @Z1_Heat_Curve_Outside_Low_Temp;|
WAR|   if @Outside_Temp >= $Tb1 then|
WAR|    #maxTa = $Ta1;|
WAR|   else|
WAR|    if @Outside_Temp <= $Tb2 then|
WAR|     #maxTa = $Ta2;|
WAR|    else|
WAR|     #maxTa = 1 + floor(0.9 + $Ta1 + (($Tb1 - @Outside_Temp) * ($Ta2 - $Ta1) / ($Tb1 - $Tb2)));|
WAR|    end|
WAR|   end|
WAR|  end|
WAR|  #allowWAR = 0;|
WAR|  setTimer(5,900);|this function runs every 15 minutes
WAR| end|
WAR|end|
WAR||
WAR|on timer=5 then|
WAR| #allowWAR = 1;|
WAR|end|
PS||
PS|on maxPumpDuty then|MaxPumpDuty function
PS| if #allowPumpSpeed == 1 then|Sets (water)pump speed depending on
PS|  #allowPumpSpeed = 0;|
PS|  if @ThreeWay_Valve_State == 1 && @Max_Pump_Duty != 220 then|OM and compressor running or not
PS|   @SetMaxPumpDuty = 220;|if production is HEAT or COOL the
PS|  end|pumpspeed will depend on
PS|  if @ThreeWay_Valve_State == 0 && @Heatpump_State == 1 then|@Outside_Temp as well
PS|   if @Outside_Temp < 10 then|
PS|    $MPF = 11;|
PS|   else|
PS|    $MPF = 10;|
PS|   end|
PS|   if @Outside_Temp < 5 then|
PS|    $MPF = 12;|
PS|   end|
PS|   if @Outside_Temp < 2 then|
PS|    $MPF = 13;|
PS|   end|
PS|   if @Compressor_Freq == 0 then|
PS|    $MPF = 8;|
PS|   end|
PS|   if @Pump_Flow < $MPF then|
PS|    #maxPumpDuty = #maxPumpDuty + 5;|
PS|   else|
PS|    if @Pump_Flow > $MPF + 1 then|
PS|     #maxPumpDuty = #maxPumpDuty - 1;|
PS|    end|
PS|   end|
PS|   if #maxPumpDuty > 140 then|
PS|    #maxPumpDuty = 140;|
PS|   end|
PS|   if @Max_Pump_Duty != #maxPumpDuty then|
PS|    @SetMaxPumpDuty = #maxPumpDuty;|
PS|   end|
PS|  end|
PS|  setTimer(6, 60);|this function runs every minute
PS| end|
PS|end|
PS||
PS|on timer=6 then|
PS| #allowPumpSpeed = 1;|
PS|end|
DHW||
DHW|on checkDHW then|DHW function
DHW| if #allowDHW == 1 then|DHW production will start if:
DHW|  #allowDHW = 0;|- DHW_Temp < 39;
DHW|  if @ThreeWay_Valve_State == 0 && (@DHW_Temp < 39 || (%hour == 13 && (%day == #LegionellaRunDay || @DHW_Temp < @DHW_Target_Temp + @DHW_Heat_Delta))) then|- DHW_Temp < DHW_Target +
DHW|   #prevOperatingMode = @Operating_Mode_State;|   DHW_Delta and %hour = 13;
DHW|   #prevHeatPumpState = @Heatpump_State;|On Legionelladay a Legionella run
DHW|   @SetOperationMode = 3;|will be done if %hour = 13.
DHW|   if @Heatpump_State != 1 then|
DHW|    @SetHeatpump = 1;|
DHW|   end |
DHW|   if %day == #legionellaRunDay then|
DHW|    @SetForceSterilization = 1;|
DHW|   end|
DHW|   #DHWRun = 1;|
DHW|  end|
DHW|  if #DHWRun == 1 then|
DHW|   if @ThreeWay_Valve_State == 0 && @DHW_Temp > 49 then|
DHW|    @SetOperationMode = #OperatingModeLast;|
DHW|    if @Heatpump_State != #HeatPumpStateLast then|
DHW|     @SetHeatpump = #HeatPumpStateLast;|
DHW|    end|
DHW|    #OperatingModeLast = 3;|
DHW|    #HeatPumpStateLast = 1;|
DHW|    #DHWRun = -1;|
DHW|   end|
DHW|  end|
DHW|  setTimer(7,900);|this function runs every 15 minutes minute
DHW| end|
DHW|end|
DHW||
DHW|on timer=7 then|
DHW| #allowDHW = 1;|
DHW|end|
OTT||
OTT|on OTThermostat then|Opentherm Thermostat function
OTT| if #allowOTThermostat == 1 && #DHWRun != 1 then|Switch HP on/off based on ?chEnable
OTT|  if #chenable == 1 && @ThreeWay_Valve_State == 0 then|& Sync HP_Target with ?chSetpoint
OTT|   if ?chSetpoint > 9 then|Prevent update setpoint if due to some
OTT|    #chSetpoint = ?chSetpoint;|glitches ?chSetpoint = 0 which happens
OTT|   end|sometimes.
OTT|   softStart();|Run softStart function (if allowed)
OTT|   #mainTargetTemp = #chSetpoint + #softStartCorrection;|set #mainTargetTemp based on 
OTT|   if #mainTargetTemp < 20 then|#chSetpoint and #softStartCorrection
OTT|    #mainTargetTemp = 20;|(if any). Safegards to prevent Target 
OTT|   end|below 20 and above 40 degrees.
OTT|   if #mainTargetTemp > 40 then|
OTT|     #mainTargetTemp = 40;|
OTT|   end|
OTT|   #mainTargetTemp = floor(#mainTargetTemp);|
OTT|   if #compState == 1 then|
OTT|    if #mainTargetTemp + 2 < @Main_Outlet_Temp then|safegard to prevent Target way below
OTT|     #mainTargetTemp = round(@Main_Outlet_Temp - 1.5);|@Main_outlet_Temp to prevent
OTT|    end|compressor switch off.
OTT|   end|
OTT|   if @Z1_Heat_Request_Temp != #mainTargetTemp then|
OTT|    @SetZ1HeatRequestTemperature = #mainTargetTemp;|
OTT|   end|
OTT|   if @Operating_Mode_State != 0 then|Set OM to HEAT
OTT|    @SetOperationMode = 0;|
OTT|   end|
OTT|   if @Heatpump_State != 1 && #chEnable == 1 then|Set HP on if #chEnable = 1
OTT|    @SetHeatpump = 1;|
OTT|   end|
OTT|  end|
OTT|  if #chEnableOffTime > 15 && @ThreeWay_Valve_State == 0 && (#compRunTime > 30 || #compState == 0) then|Set HP off if #chEnable is off for
OTT|   @SetHeatpump = 0;|15 minutes & compressor is off or 
OTT|  end|on for more than 30 minutes
OTT|  #allowOTThermostat = 0;|
OTT|  setTimer(8,25);|this function runs every 30 seconds
OTT| end|(trigger from timer 1 every 15 sec.)
OTT|end|
OTT||
OTT|on timer=8 then|
OTT|  #allowOTThermostat  = 1;|
OTT|end|
SS||
SS|on softStart then|softStart function
SS| if #allowSoftStart == 1 && #compState == 1 then|This function tries to reduce the
SS|  if #softStartPhase  < 1 then|compressor frequency asap by setting
SS|   #softStartPhase = 1;|QuietMode and reducing target temp
SS|   setTimer(9,5);|to temp below current water temp.
SS|  end|After this startup behavour it increases
SS|  if #softStartPhase == 2 then|the target temp to prevent switch off
SS|   #softStartCorrection = @Main_Outlet_Temp - 1 - #chSetpoint;|compressor for a set time (2 hours)
SS|  end|After this phase it will gradualy reduce
SS|  if #softStartPhase == 3 then|the correction value which will most 
SS|   if #chSetpoint <= @Main_Outlet_Temp then|likely lead to compressor off.
SS|    #softStartCorrection = @Main_Outlet_Temp - 0.7 - #chSetpoint;|
SS|   end|
SS|   if #chSetpoint > @Main_Outlet_Temp then|
SS|    #softStartCorrection = @Main_Outlet_Temp + 1 - #chSetpoint;|
SS|   end|
SS|  end|
SS|  if #softStartCorrection > 5 && #chSetpoint != 10 then|
SS|   #softStartCorrection = 5;|
SS|  end|
SS|  if #softStartCorrection < -5 then|
SS|   #softStartCorrection = -5;|
SS|  end|
SS|  if @Compressor_Freq > 18 && @Compressor_Freq < 26 then|Set @QuietMode back to 0 when
SS|   #mildMode = 0;|compressor < xx Hz
SS|   setQuietMode();|
SS|  end|
SS| end|
SS|end|
SS||
SS|on timer=9 then|
SS| if #softStartPhase == 4 then|
SS|  if #softStartCorrection > 0 then|
SS|   #softStartCorrection = #softStartCorrection - 1;|
SS|   setTimer(9,900);|phase 3 step correction timer
SS|  else|
SS|   #softStartCorrection = 0;|
SS|   #softStartPhase = -1;|
SS|  end|
SS| end|
SS|if #softStartPhase == 3 then|
SS|  #softStartPhase = 4;|
SS|  setTimer(9,10);|
SS| end|
SS| if #softStartPhase == 2 then|
SS|  #softStartPhase = 3;|
SS|  setTimer(9,7200);|phase 2 timer
SS| end|
SS| if #softStartPhase == 1 then|
SS|  #softStartPhase = 2;|
SS|  setTimer(9,120);|phase 1 timer
SS| end|
SS|end|
OTT SS||
OTT SS|on @Compressor_Freq then|
OTT SS| if @Compressor_Freq == 0 then|
OTT SS|  #compState = 0;|
OTT SS|  #softStartCorrection = 0;|
OTT SS|  #softStartPhase = -1;|
OTT SS|  if #mildMode != #silentMode then|Set @quietMode back to #silentmode value
OTT SS|   #mildMode = #silentMode;|once compressor stops
OTT SS|   setQuietMode();|
OTT SS|  end|
OTT SS| else|
OTT SS|  if #compState < 1 then|
OTT SS|   #compStartTime = #timeRef;|
OTT SS|   #compState = 1;|
OTT SS|  end|
OTT SS|  #compRunTime = #timeRef - #compStartTime;|caclutate CompressorRunTime
OTT SS|  if #compRunTime < 0 then|
OTT SS|   #compRunTime = #timeRef - #compStartTime + 10080;|
OTT SS|  end|
OTT SS| end|
OTT SS|end|
