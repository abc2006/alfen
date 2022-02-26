defmod DF_ueberschussladung_aussen DOIF ueberschussgesteuert{\
	my $callback = [alfen_Socket_aussen:MaxCurrentValidTimeRemaining];;\
	if([?alfen_Socket_aussen:state] eq "disconnected")\
	{\
	return;;\
	}\
	# Wenn das EV nicht angeschlossen ist oder ein Fehler vorliegt: \
		my $mode3state_ = [?alfen_Socket_aussen:Mode3State_];;\
		my $mode3state = [?alfen_Socket_aussen:Mode3State];;\
	fhem("setreading $SELF mode3state $mode3state");;\
##	if($mode3state =~ /[AEF]/){\
	if($mode3state eq "A" || $mode3state eq "E" || $mode3state eq "F"){\
		fhem("setreading $SELF charging_stopped $mode3state_");;\
		fhem("setreading $SELF status Kein Fahrzeug angeschlossen");;\
		set_charge_current("0");;\
		fhem("setreading $SELF sofortladung nein");;\
		return;;\
	}\
	## Wenn sofortladung eingeschaltet ist\
	if([?$SELF:sofortladung] eq "ja"){\
		if([?alfen_Socket_aussen:Charge_with_1_or_3_phases] == 1 ){\
			fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases 3");;\
		}\
		set_charge_current("16");;\
		fhem("setreading $SELF status Sofortladung -> Vollgas");;\
		return;;\
	}\
	\
	if([LRW3E7FA0MC336661:battery_level] >= [LRW3E7FA0MC336661:charge_limit_soc] && [LRW3E7FA0MC336661:battery_level:sec] < 1800 && [LRW3E7FA0MC336661:charge_limit_soc:sec] < 1800)\
	{\
		set_charge_current("16");;\
		fhem("setreading $SELF status Standby - provide Power for preheat");;\
		return;;	\
	}\
	# Wenn sonst der Akku beschädigt wird, weil er zu leer ist\
	if([LRW3E7FA0MC336661:battery_range_:sec] < 300 && [LRW3E7FA0MC336661:battery_level] < 10){\
		if([?alfen_Socket_aussen:Charge_with_1_or_3_phases] == 1 ){\
			fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases 1");;\
		}\
		set_charge_current("6");;\
		fhem("setreading $SELF status EVFirst");;\
		return;;\
	}	\
	# Wenn die PV aus der Batterie gespeist wird, wird das EV NICHT geladen: \
##	if([BMS:1_Power_total:d] < -500 && [BMS:1_Power_total:sec] < 300 && [$SELF:EVStop:sec] == 1 && [$SELF:EVStop:sec] > 120){\
##		fhem("setreading $SELF status EVStop - save the Pylontech: ". [BMS:1_Power_total:d] . " W");;\
##		##fhem("set alfen_Socket_aussen Charge_Current 0");;\
##		return;;\
##	}elsif{ [BMS:1_Power_total:d] < -500 && [BMS:1_Power_total:sec] < 300 }\
##\
##	}\
\
	# wenn der WR leer ist und das Auto weniger als 50 % hat ( im Winter kann man hier bestimmt 80% nehmen), kann das Auto entscheiden\
	if([fsp10k:AC_input_active_Power_total:d] == 0 && ([LRW3E7FA0MC336661:battery_range_:sec] < 300 || [LRW3E7FA0MC336661:battery_level] < 15)){\
		if([?alfen_Socket_aussen:Charge_with_1_or_3_phases] == 1 ){\
			fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases 3");;\
		}\
		set_charge_current("16");;\
		fhem("setreading $SELF status WRempty");;\
		return;;\
	}\
	# Wenn die Batterie voll ist, wird das Auto auch geladen, unabhängig vom Ladestand. \
	# Wo ist jetzt der Punkt, dass wir bei angeschlossenem Auto die Energie lieber sofort ins Auto tun?\
	if([BMS:1_SOC_BMS_total] > [BMS:1_SOC_lademax]+5){\
		if([?alfen_Socket_aussen:Charge_with_1_or_3_phases] == 1 ){\
			fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases 3");;\
		}\
		set_charge_current("16");;\
		fhem("setreading $SELF status PVBattery full");;\
		return;;\
	}\
	\
###############################################################\
# Wenn jetzt alles passt, dann ist PV-Überschuss da\
###############################################################\
\
\
	##fhem("setreading $SELF status Ueberschussladung");;\
	#Wieviel Leistung steht mir zum Laden zur Verfügung? \
	my $available_charge_power = [gendev_PV:98_available_power:d]+[BMS:1_Power_total:d]-500;;	\
	my $number_of_phases;;\
	my $status = "Ueberschussladung";;\
	fhem("setreading $SELF available_charge_power_debug_from_gendev_PV $available_charge_power");;\
\
	\
## Entscheide, wie viele phasen verwendet werden\
	if($available_charge_power < 1380){ \
		$status .= " - Low Power (<1380)";;\
		fhem("set alfen_Socket_aussen Charge_Current 0");;\
		fhem("setreading $SELF set_current_timestamp 0");;\
		return;;\
	}elsif($available_charge_power < 4140){ # && > 1380\
		$status .= " - 1ph-Power (<4000)";;\
		$number_of_phases = 1;;\
	## Wenn die Leistung über 4140 liegt, 3-phasig laden\
	}elsif ($available_charge_power >= 4140){\
		$status .= " - 3ph-Power (>4000)";;\
		$number_of_phases = 3;;\
	}\
	fhem("setreading $SELF number_of_phases_calc $number_of_phases");;\
	fhem("setreading $SELF status $status");;\
	## 100% = 425 km\
	## 25% = 100km\
	\
##############################################################################\
## setze die entscheidung um	##############################################\
##############################################################################\
	fhem("setreading $SELF set_phases_timestamp_sec " . [$SELF:set_phases_timestamp:sec]);;\
	if($number_of_phases != [?alfen_Socket_aussen:Charge_with_1_or_3_phases]){\
		if($number_of_phases == 1 && [?$SELF:set_phases_timestamp:sec] > 600){\
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
if($available_charge_current > 0 && $available_charge_current < 6){\
	$available_charge_current = 6;;\
}	\
	\
if($available_charge_current > 16){\
	$available_charge_current = 16;;\
}\
set_charge_current($available_charge_current);;\
\
}\
\
sofortladen{\
if([?$SELF:sofortladung] eq "ja")\
{\
fhem("setreading DF_ueberschussladung_aussen sofortladung nein");;\
} else {\
fhem("setreading DF_ueberschussladung_aussen sofortladung ja");;\
}\
return;;\
}# sofortladen\
\
\
subs {\
sub set_charge_current{\
	my ($current) = shift // return 1;;\
	my $charging_stopped_age = ReadingsAge("$SELF","charging_stopped","");;\
	my $current_set_age = ReadingsAge("$SELF","set_current_timestamp","");;\
	\
		if($charging_stopped_age > 120 && $current_set_age > 15){\
			fhem("set alfen_Socket_aussen Charge_Current $current");;\
			fhem("setreading $SELF set_current_timestamp $current");;\
			Log3("$SELF",0,"set Charge_Current $current");;\
		}\
	return;; \
	}# set charge current\
\
} # subs\

attr DF_ueberschussladung_aussen DOIF_Readings available_charge_current:[$SELF:available_charge_power:d0]/230/3,\
available_charge_power2:[gendev_PV:98_available_power],\
available_charge_power:[$SELF:available_charge_power2:avg5],\
pvfirst: [BMS:1_SOC_lademax] - [BMS:1_SOC_BMS_total],\
pvpower:([fsp10k:Solar_input_power_total:d]+[KNX50.O06_Aktor_PVpure:Solar_input_power_total:d]),\
set_charging_stopped_timestamp_sec:[$SELF:charging_stopped:sec],\
set_current_timestamp_sec:[$SELF:set_current_timestamp:sec],\
set_phases_timestamp_sec:[$SELF:set_phases_timestamp:sec],\
solarpower:[gendev_PV:10_Solar_input_power_total],\
ch2:[gendev_PV:10_Solar_input_power_total]-[gendev_PV:80_Eigenverbrauch_EZVZ]-500
attr DF_ueberschussladung_aussen DbLogInclude status,state
attr DF_ueberschussladung_aussen comment set_current_timestamp_sec:[$SELF:set_current_timestamp:sec],\
set_phases_timestamp_sec:[$SELF:set_phases_timestamp:sec],\
set_charging_stopped_timestamp_sec:[$SELF:charging_stopped:sec],\
pvfirst: [BMS:1_SOC_lademax] - [BMS:1_SOC_BMS_total],\
available_charge_power_alt:[fsp10k:Solar_input_power_total]+[KNX50.O06_Aktor_PVpure:Solar_input_power_total:d0]-([Erzeugungszaehler:total_power]-[Stromzaehler:total_power]+[alfen_Socket_aussen:RealPowerSum])*-1,\
solarpower: [fsp10k:Solar_input_power_total]+[KNX50.O06_Aktor_PVpure:Solar_input_power_total:d0],\
feedinpower: [fsp10k:AC_input_active_Power_total]+[KNX50.O06_Aktor_PVpure:AC_input_active_Power_total:d0],\
feedindiff: [$SELF:solarpower]+[$SELF:feedinpower],\
available_charge_power_:[fsp10k:AC_input_active_Power_total]+[KNX50.O06_Aktor_PVpure:AC_input_active_Power_total:d0]-[Stromzaehler:total_power]+[alfen_Socket_aussen:RealPowerSum],\
true_EV:([Erzeugungszaehler:total_power]-[Stromzaehler:total_power])*-1,\
EV_without_WB:([Erzeugungszaehler:total_power]-[Stromzaehler:total_power]+[alfen_Socket_aussen:RealPowerSum])*-1,\
total_pv_power:[fsp10k:Solar_input_power_total]+[KNX50.O06_Aktor_PVpure:Solar_input_power_total:d0],\
total_available_power:[$SELF:total_pv_power:med5]-[$SELF:EV_without_WB:med5],\
1_3_phases:[alfen_Socket_aussen:Charge_with_1_or_3_phases],\
pvpower:([fsp10k:Solar_input_power_total:d]+[KNX50.O06_Aktor_PVpure:Solar_input_power_total:d]),\
actual_charge_current_setpoint:[alfen_Socket_aussen:ActualAppliedMaxCurrent:d0],\
actual_charge_current:[alfen_Socket_aussen:CurrentPhaseL1:d0],\
actual_charge_power:[alfen_Socket_aussen:RealPowerSum:d0],\
available_charge_power:[$SELF:available_charge_power_:avg5],\
available_charge_current:[$SELF:available_charge_power:d0]/230/3
attr DF_ueberschussladung_aussen event-on-change-reading .*
attr DF_ueberschussladung_aussen event_Readings 1_3_phases:[alfen_Socket_aussen:Charge_with_1_or_3_phases],\
actual_charge_current:[alfen_Socket_aussen:CurrentPhaseL1:d0],\
actual_charge_current_setpoint:[alfen_Socket_aussen:ActualAppliedMaxCurrent:d0],\
actual_charge_power:[alfen_Socket_aussen:RealPowerSum:d0]
attr DF_ueberschussladung_aussen room _types->doif,tesla
attr DF_ueberschussladung_aussen stateFormat 1_3_phases ph Ladestrom actual_charge_current/actual_charge_current_setpoint A status actual_charge_power/available_charge_power_debug_from_gendev_PV W

setstate DF_ueberschussladung_aussen 3 ph Ladestrom 0/0 A Ueberschussladung - 3ph-Power (>4000) 7823/17114 W
setstate DF_ueberschussladung_aussen 2022-02-23 11:40:17 1_3_phases 3
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:15 Device BMS
setstate DF_ueberschussladung_aussen 2022-02-23 11:40:17 actual_charge_current 0
setstate DF_ueberschussladung_aussen 2022-02-23 11:40:17 actual_charge_current_setpoint 0
setstate DF_ueberschussladung_aussen 2022-02-26 13:52:43 actual_charge_power 7823
setstate DF_ueberschussladung_aussen 2022-02-23 11:40:18 available_charge_current 8.07101449275362
setstate DF_ueberschussladung_aussen 2022-02-23 11:40:17 available_charge_power 5569
setstate DF_ueberschussladung_aussen 2022-02-23 11:40:17 available_charge_power2 5569
setstate DF_ueberschussladung_aussen 2022-02-11 12:19:54 available_charge_power_debug 11938.4
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:15 available_charge_power_debug_from_gendev_PV 17114
setstate DF_ueberschussladung_aussen 2022-02-25 08:52:44 block_sofortladen executed
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:15 block_ueberschussgesteuert executed
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:06 ch2 13063
setstate DF_ueberschussladung_aussen 2022-02-26 02:43:49 charging_stopped EVSE ready and standby
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:15 e_BMS_1_Power_total 4751
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:15 e_BMS_1_SOC_BMS_total 63.1
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:15 e_BMS_1_SOC_lademax 95
setstate DF_ueberschussladung_aussen 2022-02-26 13:52:20 e_LRW3E7FA0MC336661_battery_level 99
setstate DF_ueberschussladung_aussen 2022-02-26 13:52:20 e_LRW3E7FA0MC336661_charge_limit_soc 100
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:15 e_alfen_Socket_aussen_MaxCurrentValidTimeRemaining 294
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:14 e_fsp10k_AC_input_active_Power_total -6849
setstate DF_ueberschussladung_aussen 2022-02-23 11:40:17 mode enabled
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:15 mode3state C2
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:15 number_of_phases_calc 3
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:06 pvfirst 31.9
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:14 pvpower 14675
setstate DF_ueberschussladung_aussen 2022-02-23 11:40:17 set_charging_stopped_timestamp_sec 0
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:09 set_current_timestamp 16
setstate DF_ueberschussladung_aussen 2022-02-26 10:58:13 set_current_timestamp_sec 0
setstate DF_ueberschussladung_aussen 2022-02-26 13:50:25 set_phases_timestamp 1
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:15 set_phases_timestamp_sec 170
setstate DF_ueberschussladung_aussen 2022-02-26 02:43:49 sofortladung nein
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:06 solarpower 14670
setstate DF_ueberschussladung_aussen 2022-02-23 11:40:17 state initialized
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:15 status Ueberschussladung - 3ph-Power (>4000)
setstate DF_ueberschussladung_aussen 2022-02-26 13:53:15 tmp_calc_current 25

