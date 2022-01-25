defmod DF_ueberschussladung_aussen DOIF ueberschussgesteuert{\
	my $callback = [alfen_Socket_aussen:MaxCurrentValidTimeRemaining];;\
	if([?alfen_Socket_aussen:state] eq "disconnected")\
	{\
	return;;\
	}\
	# Wenn das EV nicht angeschlossen ist oder ein Fehler vorliegt: \
		my $mode3state_ = [?alfen_Socket_aussen:Mode3State_];;\
		my $mode3state = [?alfen_Socket_aussen:Mode3State];;\
	##fhem("set remotebot message $mode3state");;	 --> A\
	fhem("setreading $SELF mode3state $mode3state");;\
##	if($mode3state =~ /[AEF]/){\
	if($mode3state eq "A" || $mode3state eq "E" || $mode3state eq "F"){\
		fhem("setreading $SELF charging_stopped $mode3state_");;\
		fhem("setreading $SELF status Kein Fahrzeug angeschlossen");;\
		fhem("set alfen_Socket_aussen Charge_Current 0");;\
		fhem("setreading $SELF sofortladung nein");;\
		return;;\
	}\
	##fhem("set remotebot message burp");; --< Burp	\
	## Wenn sofortladung eingeschaltet ist\
	if([?$SELF:sofortladung] eq "ja"){\
		if([?alfen_Socket_aussen:Charge_with_1_or_3_phases] == 1 ){\
			fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases 3");;\
		}\
		fhem("set alfen_Socket_aussen Charge_Current 15");;\
		fhem("setreading $SELF status Sofortladung -> Vollgas");;\
		return;;\
	}\
	# Wenn sonst der Akku beschädigt wird, weil er zu leer ist\
	if([LRW3E7FA0MC336661:battery_range_:sec] < 300 && [LRW3E7FA0MC336661:battery_level] < 20){\
		if([?alfen_Socket_aussen:Charge_with_1_or_3_phases] == 1 ){\
			fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases 1");;\
		}\
		fhem("set alfen_Socket_aussen Charge_Current 6");;\
		fhem("setreading $SELF status EVFirst");;\
		return;;\
	}	\
	# Wenn die PV aus der Batterie gespeist wird, wird das EV NICHT geladen: \
	if([BMS:1_Power_total:d] < -500 && [BMS:1_Power_total:sec] < 300){\
	fhem("setreading $SELF status EVStop - save the Pylontech: ". [BMS:1_Power_total:d] . " W");;\
	fhem("set alfen_Socket_aussen Charge_Current 0");;\
	return;;\
	}\
	# wenn der WR leer ist und das Auto weniger als 50 % hat ( im Winter kann man hier bestimmt 80% nehmen), kann das Auto entscheiden\
	if([fsp10k:AC_input_active_Power_total:d] == 0 && ([LRW3E7FA0MC336661:battery_range_:sec] < 300 || [LRW3E7FA0MC336661:battery_level] < 80)){\
		if([?alfen_Socket_aussen:Charge_with_1_or_3_phases] == 1 ){\
			fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases 3");;\
		}\
		fhem("set alfen_Socket_aussen Charge_Current 14");;\
		fhem("setreading $SELF status WRempty");;\
		return;;\
	}\
	# Wenn die Batterie voll ist, wird das Auto auch geladen, unabhängig vom Ladestand. \
	# Wo ist jetzt der Punkt, dass wir bei angeschlossenem Auto die Energie lieber sofort ins Auto tun?\
	if([BMS:1_SOC_BMS_total] > [BMS:1_SOC_lademax]){\
		if([?alfen_Socket_aussen:Charge_with_1_or_3_phases] == 1 ){\
			fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases 3");;\
		}\
		fhem("set alfen_Socket_aussen Charge_Current 14");;\
		fhem("setreading $SELF status PVBattery full");;\
		return;;\
	}\
	\
###############################################################\
# Wenn jetzt alles passt, dann ist PV-Überschuss da\
###############################################################\
\
\
	fhem("setreading $SELF status Ueberschussladung");;\
	#Wieviel Leistung steht mir zum Laden zur Verfügung? \
	my $available_charge_power = [?$SELF:available_charge_power:d];;	\
	my $number_of_phases;;\
	fhem("setreading $SELF available_charge_power_debug $available_charge_power");;\
\
	\
## Entscheide, wie viele phasen verwendet werden\
	if($available_charge_power < 1380){ \
		fhem("setreading $SELF status Ueberschussladung - Low Power (<1380)");;\
		fhem("set alfen_Socket_aussen Charge_Current 0");;\
		fhem("setreading $SELF set_current_timestamp 0");;\
		return;;\
	}elsif($available_charge_power < 4140){ # && > 1380\
		fhem("setreading $SELF status Ueberschussladung - 1ph-Power (<4000)");;\
		$number_of_phases = 1;;\
	## Wenn die Leistung über 4140 liegt, 3-phasig laden\
	}elsif ($available_charge_power >= 4140){\
		fhem("setreading $SELF status Ueberschussladung - 3ph-Power (>4000)");;\
		$number_of_phases = 3;;\
	}\
	fhem("setreading $SELF number_of_phases_calc $number_of_phases");;\
\
	## 100% = 425 km\
	## 25% = 100km\
	\
##############################################################################\
## setze die entscheidung um	##############################################\
##############################################################################\
	fhem("setreading $SELF set_phases_timestamp_sec " . [$SELF:set_phases_timestamp:sec]);;\
	if($number_of_phases != [?alfen_Socket_aussen:Charge_with_1_or_3_phases]){\
		if($number_of_phases == 1 && [?$SELF:set_phases_timestamp:sec] > 300){\
			#runter mit kurzem delay\
			##fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases 1");;\
			fhem("setreading $SELF set_phases_timestamp $number_of_phases");;\
		}\
		if($number_of_phases == 3 && [?$SELF:set_phases_timestamp:sec] > 300)	{\
			# hoch nur mit längerem delay\
			fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases 3");;\
			fhem("setreading $SELF set_phases_timestamp $number_of_phases");;\
		}\
	}\
	#Berechne mit wie viel Strom geladen wird\
	my $available_charge_current = int($available_charge_power/230/[?alfen_Socket_aussen:Charge_with_1_or_3_phases]);;\
	if([BMS:1_SOC_BMS_total] > 30){\
	$available_charge_current = $available_charge_current+1;;\
	}\
	\
	fhem("setreading $SELF tmp_calc_current $available_charge_current");;\
	\
\
\
## setze die Entscheidung um \
	if([?$SELF:charging_stopped:sec] > 120){\
		if([?$SELF:set_current_timestamp:sec] > 15 )	{\
			\
			\
			if($available_charge_current > 0 && $available_charge_current < 6){\
				$available_charge_current = 6;;\
			}	\
			\
			if($available_charge_current > 14){\
				$available_charge_current = 14;;\
			}\
			fhem("set alfen_Socket_aussen Charge_Current $available_charge_current");;\
			fhem("setreading $SELF set_current_timestamp $available_charge_current");;\
		}\
	}\
}\
zeitgesteuert {\
#my $km = [$SELF:charge_vollgas_km];;\
#if($km == 0){\
#$km = 100;;\
#}\
#my $time_sec = $km/80*3600;;\
#set_Exec("tmr_wb_vollgas", $time_sec, '');;\
#if($time_sec){\
#	fhem("setreading $SELF charge_vollgas_km 0");;\
#}\
fhem("setreading $SELF sofortladung ja");;\
\
\
return;;\
}\
\
sofortladen{\
if([?$SELF:sofortladung] eq "ja")\
{\
fhem("setreading DF_ueberschussladung_aussen sofortladung nein");;\
} else {\
fhem("setreading DF_ueberschussladung_aussen sofortladung ja");;\
}\
\
\
return;;\
}\

attr DF_ueberschussladung_aussen DOIF_Readings true_EV:([Erzeugungszaehler:total_power]-[Stromzaehler:total_power])*-1,\
EV_without_WB:([Erzeugungszaehler:total_power]-[Stromzaehler:total_power]+[alfen_Socket_aussen:RealPowerSum])*-1,\
total_pv_power:[fsp10k:Solar_input_power_total]+[KNX50.O06_Aktor_PVpure:Solar_input_power_total:d0],\
total_available_power:[$SELF:total_pv_power:med5]-[$SELF:EV_without_WB:med5],\
1_3_phases:[alfen_Socket_aussen:Charge_with_1_or_3_phases],\
pvpower:([fsp10k:Solar_input_power_total:d]+[KNX50.O06_Aktor_PVpure:Solar_input_power_total:d]),\
actual_charge_current_setpoint:[alfen_Socket_aussen:ActualAppliedMaxCurrent:d0],\
actual_charge_current:[alfen_Socket_aussen:CurrentPhaseL1:d0],\
actual_charge_power:[alfen_Socket_aussen:RealPowerSum:d0],\
available_charge_power_:[fsp10k:Solar_input_power_total]+[KNX50.O06_Aktor_PVpure:Solar_input_power_total:d0]-([Erzeugungszaehler:total_power]-[Stromzaehler:total_power]+[alfen_Socket_aussen:RealPowerSum])*-1,\
available_charge_power:[$SELF:available_charge_power_:avg5],\
available_charge_current:[$SELF:available_charge_power:d0]/230/3
attr DF_ueberschussladung_aussen DbLogInclude status,state
attr DF_ueberschussladung_aussen event_Readings set_current_timestamp_sec:[$SELF:set_current_timestamp:sec],\
set_phases_timestamp_sec:[$SELF:set_phases_timestamp:sec],\
set_charging_stopped_timestamp_sec:[$SELF:charging_stopped:sec],\
pvfirst: [BMS:1_SOC_lademax] - [BMS:1_SOC_BMS_total]
attr DF_ueberschussladung_aussen room _types->doif,tesla
attr DF_ueberschussladung_aussen stateFormat 1_3_phases ph Ladestrom actual_charge_current/actual_charge_current_setpoint A status available_charge_power W

setstate DF_ueberschussladung_aussen 3 ph Ladestrom 0/15 A Sofortladung -> Vollgas -905 W
setstate DF_ueberschussladung_aussen 2022-01-05 10:13:28 1_3_phases 3
setstate DF_ueberschussladung_aussen 2022-01-25 17:06:15 Device fsp10k
setstate DF_ueberschussladung_aussen 2022-01-25 17:06:16 EV_without_WB 997.8
setstate DF_ueberschussladung_aussen 2022-01-24 20:17:49 actual_charge_current 0
setstate DF_ueberschussladung_aussen 2022-01-24 19:04:26 actual_charge_current_setpoint 15
setstate DF_ueberschussladung_aussen 2022-01-24 20:17:51 actual_charge_power 0
setstate DF_ueberschussladung_aussen 2022-01-25 17:06:15 available_charge_current -1.31739130434783
setstate DF_ueberschussladung_aussen 2022-01-25 17:06:16 available_charge_power -905
setstate DF_ueberschussladung_aussen 2022-01-25 17:06:16 available_charge_power_ -896.8
setstate DF_ueberschussladung_aussen 2022-01-24 19:04:21 available_charge_power_debug -990.76
setstate DF_ueberschussladung_aussen 2022-01-24 19:04:21 block_sofortladen executed
setstate DF_ueberschussladung_aussen 2022-01-25 17:06:15 block_ueberschussgesteuert executed
setstate DF_ueberschussladung_aussen 2021-12-19 21:17:33 charge_vollgas_km 0
setstate DF_ueberschussladung_aussen 2022-01-24 19:03:14 charging_stopped EVSE ready and standby
setstate DF_ueberschussladung_aussen 2021-10-31 19:08:09 debug 4264.08074307442
setstate DF_ueberschussladung_aussen 2021-10-31 19:04:13 debug_zeitgesteuert 4500
setstate DF_ueberschussladung_aussen 2022-01-25 17:04:28 e_BMS_1_Power_total 0
setstate DF_ueberschussladung_aussen 2022-01-25 17:06:14 e_BMS_1_SOC_BMS_total 21.6
setstate DF_ueberschussladung_aussen 2022-01-25 13:21:02 e_BMS_1_SOC_lademax 95
setstate DF_ueberschussladung_aussen 2022-01-23 17:14:47 e_DF_ueberschussladung_aussen_set_phases_timestamp 1
setstate DF_ueberschussladung_aussen 2022-01-25 17:06:11 e_alfen_Socket_aussen_MaxCurrentValidTimeRemaining 298
setstate DF_ueberschussladung_aussen 2022-01-25 17:06:15 e_fsp10k_AC_input_active_Power_total 9
setstate DF_ueberschussladung_aussen 2022-01-10 14:28:31 mode enabled
setstate DF_ueberschussladung_aussen 2022-01-25 17:06:15 mode3state B2
setstate DF_ueberschussladung_aussen 2022-01-23 17:14:58 number_of_phases_calc 3
setstate DF_ueberschussladung_aussen 2022-01-25 17:06:15 pvfirst 73.4
setstate DF_ueberschussladung_aussen 2022-01-25 17:06:15 pvpower 101
setstate DF_ueberschussladung_aussen 2022-01-24 19:03:14 set_charging_stopped_timestamp_sec 0
setstate DF_ueberschussladung_aussen 2022-01-24 19:04:21 set_current_timestamp 0
setstate DF_ueberschussladung_aussen 2022-01-24 19:04:21 set_current_timestamp_sec 0
setstate DF_ueberschussladung_aussen 2022-01-23 17:14:47 set_phases_timestamp 1
setstate DF_ueberschussladung_aussen 2022-01-23 17:14:58 set_phases_timestamp_sec 11
setstate DF_ueberschussladung_aussen 2022-01-24 19:04:21 sofortladung ja
setstate DF_ueberschussladung_aussen 2022-01-10 14:28:31 state initialized
setstate DF_ueberschussladung_aussen 2022-01-25 17:06:15 status Sofortladung -> Vollgas
setstate DF_ueberschussladung_aussen 2022-01-23 17:14:58 tmp_calc_current 6
setstate DF_ueberschussladung_aussen 2022-01-25 17:06:15 total_available_power -904.8
setstate DF_ueberschussladung_aussen 2022-01-25 17:06:15 total_pv_power 101
setstate DF_ueberschussladung_aussen 2022-01-25 17:06:16 true_EV 997.8

