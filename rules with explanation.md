# Rules set for HeishaMon


function | Rules | Description
:--- | --- | ---
GEN|on System#Boot then|Booting the rules set
GEN| #allowDHW = 1;|allow DHW function (0/1)
GEN| #allowOTThermostat = 1;|allow OTT Thermostat function (0/1)
GEN| #allowPumpSpeed = 1;|allow PumpSpeed function (0/1)
GEN| #allowSilentMode = 1;|allow SilentMode function (0/1)
GEN| #allowSoftStart = 1;|allow SoftStart function (0/1)
GEN| #allowSyncOT = 1;|allow Sync OT function (0/1)
GEN| #allowWAR = 1;|allow WAR function (0/1)
GEN||
GEN| #chEnable = -1;|#chEnable is clean ?chEnable 
GEN| #chEnableOffTime = -1;|Time?chEnable goes off
GEN| #chEnableTimeOff = -1;|?chEnable Off Timer
GEN| #chSetPoint = -1;|copy of ?chEnable
GEN| #compRunTime = -1;|Time the compressor is running
GEN| #compStartTime = -1;|Time the compressor starts running
GEN| #compState = -1;|compressor state (0/1)
GEN| #DHWRun = -1;|DHWrun state (0/1)
GEN| #firstBoot = 1;|accomodate boot up routine
GEN| #heatPumpState = -1;|
GEN| #legionellaRunDay = 7;|1 (Monday) .. 7 (Saturday)
GEN| #mainTargetTemp = -1;|Water Temperature target for HEAT
GEN| #maxPumpDuty = 85;|value which fits my installation (~ 11l/m)
GEN| #maxTa = -1;|MaxTa based on WAR
GEN| #mildMode = -1;|
GEN| #operatingMode = -1;|
GEN| #prevHeatPumpState = -1;|
GEN| #prevOperatingMode = -1;|
GEN| #quietMode = -1;|
GEN| #roomTempDelta = -1;|delta between room setpoint and temp
GEN| #softStartCorrection = 0;|
GEN| #softStartPhase = -1;|
GEN| #timeRef = -1;|
GEN| setTimer(1,60);|main timer which calls all functions
GEN| setTimer(2,10);|timer for time reference
GEN|end|
GEN||
GEN|on timer=1 then|main timer which calls all functions
GEN| if #firstBoot == 1 then|not required to remove them if you don't need them, this is done with the allow variable in the on boot block
GEN|  #firstBoot = 0;|First run different to set variables
GEN|  #heatPumpState = @Heatpump_State;|
GEN|  #operatingMode = @Operating_Mode_State;|
GEN|  compressorFreq();|
GEN|   calculateWAR();|
GEN|  syncOpenTherm();|
GEN| else|
GEN|   calculateWAR();|
GEN|  setSilentMode();|
GEN|  syncOpenTherm();|
GEN|  setMaxPumpDuty();|
GEN|  checkDHW();|
GEN|  OTThermostat();|
GEN| end|
GEN| setTimer(1,15);|run this function every 15 seconds
GEN|end|
GEN||
GEN|on timer=2 then|timer for time reference
GEN| #timeRef = %day * 1440 + %hour * 60 + %minute;|sync #timeRef with current time 
GEN| setTimer(2,60);|run this function every  minute
GEN|end|
SM||
SM|on setSilentMode then|SilentMode function
SM| if #allowSilentMode == 1 then|Sets #silentmode value depending on outside temperature and time of day
SM|  #allowSilentMode = 0;|
SM|  if @Outside_Temp > 9 then|
SM|   #silentMode = 3;|
SM|  else|
SM|   if @Outside_Temp > 4 then|
SM|    #silentMode = 2;|
SM|   else|
SM|    if @Outside_Temp > 1 then|
SM|     if %hour > 22 || %hour < 7 then|
SM|      #silentMode = 1;|
SM|     else|
SM|      #silentMode = 0;|
SM|     end|
SM|    end|
SM|   end|
SM|  end|
SM|  setTimer(3, 900);|this function runs every 15 minutes
SM|  setQuietMode();|
SM| end|
SM|end|
SM||
SM|on timer=3 then|
SM| #allowSilentMode = 1;|reset allow parameter
SM|end|
SM||
SM|on setQuietMode then|Set QuietMode variable
SM| if #mildMode > -1 then|QuietMode will be #mildMode if #mildMode is set, otherwise #silentMode
SM|  #quietMode = #mildMode;|
SM| else|
SM|  if #chEnable == 0 && #compState == 1 then|to avoid FAN spin up when compressor goes off QM3 is set
SM|   #quietMode = 3;|
SM|  else|
SM|   #quietMode = #silentMode;|
SM|  end|
SM| end|
SM| if @Quiet_Mode_Level != #quietMode then|
SM|  @SetQuietMode = #quietMode;|
SM| end|
SM|end|
SyncOT||
SyncOT|on syncOpenTherm then|Sync OT variable
SyncOT| if #allowSyncOT == 1 then|
SyncOT|  ?outletTemp = @Main_Outlet_Temp;|
SyncOT|  ?inletTemp = @Main_Inlet_Temp;|
SyncOT|  ?outsideTemp = @Outside_Temp;|
SyncOT|  ?dhwTemp = @DHW_Temp;|
SyncOT|  ?dhwSetpoint = @DHW_Target_Temp;|
SyncOT|  if ?chEnable == 1 then|#chEnable update is with some logic to keep #chEnable 1 if ?chEnable is 0 for only a short (5 minute) time
SyncOT|   #chEnable = 1;|
SyncOT|   if #chEnableTimeOff != -1 then|
SyncOT|    #chEnableTimeOff = -1;|
SyncOT|    #chEnableOffTime = -1;|
SyncOT|   end|
SyncOT|  else|
SyncOT|   if #chEnableTimeOff == -1 then|
SyncOT|    #chEnableTimeOff = #timeRef;|#chEnableTimeOff is set to time ?chEnable went off
SyncOT|   end|
SyncOT|   #chEnableOffTime = #timeRef - #chEnableTimeOff;|#chEnableOffTime gives time in minutes ?chEnable = 0
SyncOT|   if #chEnableOffTime < 0 then|
SyncOT|    #chEnableOffTime = #timeRef - #chEnableTimeOff + 10080;|
SyncOT|   end|
SyncOT|   if #chEnableOffTime > 5 then|#chEnable goes to 0 if ?chEnable is off for 5 minutes
SyncOT|    #chEnable = 0;|
SyncOT|   end|
SyncOT|  end|
SyncOT|  #dhwEnable = ?dhwEnable;|
SyncOT|  if #maxTa != -1 then|sync ?maxTa with result of the WAR
SyncOT|   ?maxTSet = #maxTa;|function
SyncOT|  end|
SyncOT|  if @Compressor_Freq == 0 then|sync ?flameState with compressor on/off, ?chState with HP running for Heat and ?dhwState with HP running for DHW
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
WAR|  $Ta1 = @Z1_Heat_Curve_Target_Low_Temp;|
WAR|  $Tb1 = @Z1_Heat_Curve_Outside_High_Temp;|
WAR|  $Ta2 = 36;|
WAR|  $Tb2 = @Z1_Heat_Curve_Outside_Low_Temp;|
WAR|  if @Outside_Temp >= $Tb1 then|
WAR|   #maxTa = $Ta1;|
WAR|  else|
WAR|   if @Outside_Temp <= $Tb2 then|
WAR|    #maxTa = $Ta2;|
WAR|   else|
WAR|    #maxTa = 1 + floor(0.9 + $Ta1 + (($Tb1 - @Outside_Temp) * ($Ta2 - $Ta1) / ($Tb1 - $Tb2)));|#maxTA is result of WAR calculation
WAR|   end|
WAR|  end|
WAR|  #allowWAR = 0;|
WAR|  setTimer(5,1800);|this function runs every half hour
WAR| end|
WAR|end|
WAR||
WAR|on timer=5 then|
WAR| #allowWAR = 1;|reset allow parameter
WAR|end|
PS||
PS|on setMaxPumpDuty then|MaxPumpDuty function
PS| if #allowPumpSpeed == 1 then|Sets (water)pump speed depending on OM and compressor running or not if production is HEAT or COOL the pumpspeed will depend on @Outside_Temp as well
PS|  #allowPumpSpeed = 0;|
PS|  if @ThreeWay_Valve_State == 1 && @Max_Pump_Duty != 220 then|
PS|   @SetMaxPumpDuty = 220;|
PS|  end|
PS|  if @ThreeWay_Valve_State == 0 && @Heatpump_State == 1 then|
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
PS| #allowPumpSpeed = 1;|reset allow parameter
PS|end|
DHW||
DHW|on checkDHW then|DHW function
DHW| if #allowDHW == 1 then|DHW production will start if a) DHW_Temp < 39 and b) DHW_Temp < DHW_Target + DHW_Delta and %hour = 13. On Legionelladay a Legionella run will be done if %hour = 13.
DHW|  #allowDHW = 0;|
DHW|  if @ThreeWay_Valve_State == 0 && (@DHW_Temp < 39 || (%hour == 13 && (%day == #LegionellaRunDay || @DHW_Temp < @DHW_Target_Temp + @DHW_Heat_Delta))) then|
DHW|   #prevOperatingMode = @Operating_Mode_State;| 
DHW|   #prevHeatPumpState = @Heatpump_State;|
DHW|   @SetOperationMode = 3;|
DHW|   if @Heatpump_State != 1 then|
DHW|    @SetHeatpump = 1;|
DHW|   end|
DHW|   if %day == #legionellaRunDay && %hour == 13 then|
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
DHW| #allowDHW = 1;|reset allow parameter
DHW|end|
OTT||
OTT|on OTThermostat then|Opentherm Thermostat function
OTT| if #allowOTThermostat == 1 && #DHWRun != 1 then|Switch HP on/off based on ?chEnable & Sync HP_Target with ?chSetpoint. Prevent update setpoint if due to some glitches ?chSetpoint = 0 which happens sometimes. Run softStart function (if allowed). set #mainTargetTemp based on #chSetpoint and #softStartCorrection (if any). Safegards to prevent Target below 27 and above 40 degrees.
OTT|  if @ThreeWay_Valve_State == 0 then|
OTT|   if ?chSetpoint > 9 then|
OTT|    #chSetpoint = ?chSetpoint;|
OTT|    if #chSetpoint < 30 && #compState == 0 then|
OTT|     #chSetpoint = 30;|
OTT|    end|
OTT|    if #chSetpoint < 27 && #compState == 1 then|
OTT|     #chSetpoint = 27;|
OTT|    end|
OTT|    if #chSetpoint > #maxTa then|
OTT|     #chSetpoint = #maxTa;|
OTT|    end|
OTT|   end|
OTT|   softStart();|
OTT|   #mainTargetTemp = #chSetpoint + #softStartCorrection;|
OTT|   if #mainTargetTemp < 27 then|
OTT|    #mainTargetTemp = 27;|
OTT|   end|
OTT|   if #mainTargetTemp > 40 then|
OTT|     #mainTargetTemp = 40;|
OTT|   end|
OTT|   #mainTargetTemp = floor(#mainTargetTemp);|
OTT|   if #compState == 1 then|
OTT|    if #mainTargetTemp + 2 < @Main_Outlet_Temp then|safegard to prevent Target way below @Main_outlet_Temp to prevent compressor switch off.
OTT|     #mainTargetTemp = round(@Main_Outlet_Temp - 1.5);|
OTT|    end|
OTT|    #roomTempDelta = ?roomTempSet - ?roomTemp;|
OTT|    if #roomTempDelta > 1 && #chEnableOffTime > 15 && @ThreeWay_Valve_State == 0 && #compRunTime > 30 then|
OTT|     #mainTargetTemp = round(@Main_Outlet_Temp - 10);|
OTT|    end|
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
OTT|  if #chEnableOffTime > 15 && @ThreeWay_Valve_State == 0 && (#compRunTime > 30 || #compState == 0) && @Outside_Temp > 2 then|Set HP off if #chEnable is off for 15 minutes & compressor is off or on for more than 30 minutes
OTT|   @SetHeatpump = 0;|
OTT|  end|
OTT|  if #softStartPhase == -1 || #softStartPhase > 1 then|
OTT|   #allowOTThermostat = 0;|this function runs every 30 seconds. (trigger from timer 1 every 15 sec.) except in sSSP 0, then 15 sec.
OTT|   setTimer(8,25);|
OTT|  end|
OTT| end|
OTT|end|
OTT||
OTT|on timer=8 then|
OTT|  #allowOTThermostat = 1;|reset allow parameter
OTT|end|
OTT||
OTT|on @Compressor_Freq then|
OTT| compressorFreq();|
OTT|end|
OTT||
OTT|on CompressorFreq then|Compressor function
OTT| if @Compressor_Freq > 18 then|
OTT|  if #compState < 1 then|
OTT|   #compStartTime = #timeRef;|Set #compStartTime to time compressor starts
OTT|   #compState = 1;|Set #compState variable (compressor ON/OFF)
OTT|  end|
OTT|  #compRunTime = #timeRef - #compStartTime;|#compRunTime is the time the compressor is running (in minutes).
OTT|  if #compRunTime < 0 then|
OTT|   #compRunTime = #timeRef - #compStartTime + 10080;|
OTT|  end|
OTT| else|
OTT|  #compState = 0;|
OTT|  #compStartTime = -1;|
OTT|  #compRunTime = -1;|
OTT|  #softStartCorrection = 0;|
OTT|  #softStartPhase = -1;|
OTT|  if #mildMode != #silentMode && #mildMode != -1 && #silentMode != 1 then|
OTT|   #mildMode = #silentMode;|Set @quietMode back to #silentmode value once compressor stops
OTT|   setQuietMode();|
OTT|  end|
OTT| end|
OTT|end|
SS||
SS|on softStart then|softStart function
SS| if #allowSoftStart == 1 && #compState == 1 then|This function tries to reduce the compressor frequency asap by setting QuietMode and reducing target temp to temp below current water temp. After this startup behavour it increases the target temp to prevent switch off compressor for a set time (2 hours). After this phase it will gradualy reduce the correction value which will most likely lead to compressor off.
SS|  if #compRunTime < 3 then|
SS|   #softStartPhase = 1;|
SS|   #softStartCorrection = @Main_Outlet_Temp - #chSetpoint;|
SS|  else|
SS|   if #compRunTime < 120 then|
SS|    #softStartPhase = 2;|
SS|    if @Compressor_Freq < 22 then|
SS|     #softStartCorrection = @Main_Outlet_Temp - #chSetpoint;|
SS|    else|
SS|     if #chSetpoint <= @Main_Outlet_Temp then|
SS|      #softStartCorrection = @Main_Outlet_Temp - 0.7 - #chSetpoint;|
SS|     end|
SS|    end|
SS|    if #chSetpoint > @Main_Outlet_Temp then|
SS|     #softStartCorrection = @Main_Outlet_Temp + 1 - #chSetpoint;|
SS|    end|
SS|   else|
SS|    if #softStartPhase == 2 then|
SS|     #softStartPhase = 3;|
SS|     setTimer(9,5);|
SS|    end|
SS|   end|
SS|  end|
SS|  if #softStartCorrection > 5 then|
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
SS| if #allowSoftStart == 1 && #compState == -5 then|correction when ?chenable goes to 10
SS|  #softStartCorrection = #mainTargetTemp - #chenable;|
SS| end|
SS|end|
SS||
SS|on timer=9 then|
SS| if #softStartCorrection > 0 then|
SS|  #softStartCorrection = #softStartCorrection - 1;|
SS|  setTimer(9,900);|
SS| end|
SS|end|
