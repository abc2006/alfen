defmod DF_ueberschussladung_Keller DOIF ueberschussgesteuert{\
	if([alfen_Socket_Keller:state] eq "disconnected")\
	{\
	return;;\
	}\
	\
	if(get_Exec("tmr_wb_vollgas")){\
		##fhem("set remotebot message Zeitladung->Vollgas");;\
		if([alfen_Socket_Keller:Charge_with_1_or_3_phases] == 1 ){\
			fhem("set alfen_Socket_Keller Charge_with_1_or_3_phases 3");;\
		}\
		fhem("set alfen_Socket_Keller Charge_Current 14");;\
		fhem("setreading $SELF status Zeitladung -> Vollgas");;\
		return;;\
	}\
\
	my $mode3state = [alfen_Socket_Keller:Mode3State_];;\
	if([alfen_Socket_Keller:Mode3State] =~ /[ABEF]/){\
		##fhem("set remotebot message Laden unterbrochen");;\
		fhem("setreading $SELF charging_stopped $mode3state");;\
		fhem("setreading $SELF status Kein Fahrzeug angeschlossen");;\
		fhem("set alfen_Socket_Keller Charge_Current 0");;\
		return;;\
	}\
\
\
\
	fhem("setreading $SELF status Ueberschussladung");;\
	#Wieviel Leistung steht mir zum Laden zur Verfügung? \
	my $available_charge_power = [$SELF:available_charge_power:d];;	\
	##debug-variable\
	##$available_charge_power = 4100;;	\
	my $number_of_phases;;\
	fhem("setreading $SELF available_charge_power_debug $available_charge_power");;\
\
\
## Entscheide, wie viele phasen verwendet werden\
	if ($available_charge_power < 4000){\
		$number_of_phases = 1;;\
	## Wenn die Leistung über 4k5 liegt, 3-phasig laden\
	}elsif ($available_charge_power >= 4000){\
		$number_of_phases = 3;;\
	}\
	fhem("setreading $SELF number_of_phases_calc $number_of_phases");;\
\
\
	my $available_charge_current = int($available_charge_power/230/[alfen_Socket_Keller:Charge_with_1_or_3_phases]);;\
\
## setze die entscheidung um	\
	if([$SELF:set_phases_timestamp:sec] > 300 && $number_of_phases != [alfen_Socket_Keller:Charge_with_1_or_3_phases])	{\
	## $available_charge_current = 0;;\
		fhem("set alfen_Socket_Keller Charge_with_1_or_3_phases $number_of_phases");;\
		fhem("setreading $SELF set_phases_timestamp $number_of_phases");;\
	}\
	\
	\
##Entscheide mit wie viel Strom geladen wird\
	fhem("setreading $SELF tmp_calc_current $available_charge_current");;\
	\
	if($available_charge_current < 5 && [alfen_Socket_Keller:Charge_with_1_or_3_phases] == 1 ){\
		$available_charge_current = 0;;\
		fhem("setreading $SELF charging_stopped 1");;\
		fhem("set alfen_Socket_Keller Charge_Current $available_charge_current");;\
	}elsif($available_charge_current < 6){\
		$available_charge_current = 6;;\
	}\
\
## setze die Entscheidung um \
	if([$SELF:charging_stopped:sec] > 120){\
		if([$SELF:set_current_timestamp:sec] > 15 )	{\
			if($available_charge_current > 14){\
				$available_charge_current = 14;;\
			}\
			fhem("set alfen_Socket_Keller Charge_Current $available_charge_current");;\
			fhem("setreading $SELF set_current_timestamp $available_charge_current");;\
		}\
\
	}\
	\
	my $logvar1 = [alfen_Socket_Keller:Charge_with_1_or_3_phases];;\
	my $logvar2 = [alfen_Socket_Keller:CurrentPhaseL1];;\
	\
	##fhem("set remotebot message Ueberschussladung SOLL: $number_of_phases phasen $available_charge_current Ampere SOLL IST: $logvar1 phasen IST");;\
\
\
	\
}\
zeitgesteuert {\
my $time_sec = [$SELF:charge_vollgas_km]/80*3600;;\
set_Exec("tmr_wb_vollgas", $time_sec, '');;\
fhem("setreading $SELF charge_vollgas_km 0");;\
\
return;;\
}
attr DF_ueberschussladung_Keller DOIF_Readings 1_3_phases:[alfen_Socket_Keller:Charge_with_1_or_3_phases],\
pvpower:([fsp10k:Solar_input_power_total]+[KNX50.O06_Aktor_PVpure:active_power_]),\
actual_charge_current_setpoint:[alfen_Socket_Keller:ActualAppliedMaxCurrent:d0],\
actual_charge_current:[alfen_Socket_Keller:CurrentPhaseL1:d0],\
actual_charge_power:[alfen_Socket_Keller:RealPowerSum:d0],\
available_charge_power:[fsp10k:Solar_input_power_total:d],\
available_charge_current:[$SELF:available_charge_power:d0]/230/3
attr DF_ueberschussladung_Keller room _types->doif,tesla
attr DF_ueberschussladung_Keller stateFormat 1_3_phases ph Ladestrom actual_charge_current_setpoint A
attr DF_ueberschussladung_Keller userReadings set_current_timestamp_sec {ReadingsAge($name,"set_current_timestamp",-1)},\
set_phases_timestamp_sec {ReadingsAge($name,"set_phases_timestamp",-1)},\
set_charging_stopped_timestamp_sec {ReadingsAge($name,"charging_stopped",-1)}

setstate DF_ueberschussladung_Keller 1 ph Ladestrom 13 A
setstate DF_ueberschussladung_Keller 2021-10-23 09:24:09 1_3_phases 1
setstate DF_ueberschussladung_Keller 2021-10-23 09:24:09 Device alfen_Socket_Keller
setstate DF_ueberschussladung_Keller 2021-10-22 12:22:43 actual_charge_current 0
setstate DF_ueberschussladung_Keller 2021-10-23 09:32:29 actual_charge_current_setpoint 13
setstate DF_ueberschussladung_Keller 2021-10-22 12:22:44 actual_charge_power 0
setstate DF_ueberschussladung_Keller 2021-10-23 09:32:27 available_charge_current 4.63478260869565
setstate DF_ueberschussladung_Keller 2021-10-23 09:32:27 available_charge_power 3198
setstate DF_ueberschussladung_Keller 2021-10-23 09:32:27 available_charge_power_debug 3198
setstate DF_ueberschussladung_Keller 2021-10-23 09:32:27 block_ueberschussgesteuert executed
setstate DF_ueberschussladung_Keller 2021-10-09 14:54:05 charge_vollgas_km 500
setstate DF_ueberschussladung_Keller 2021-10-08 13:17:54 charge_vollgas_sec 60
setstate DF_ueberschussladung_Keller 2021-10-23 09:10:03 charging_stopped 1
setstate DF_ueberschussladung_Keller 2021-10-23 09:32:27 e_DF_ueberschussladung_Keller_available_charge_power 3198
setstate DF_ueberschussladung_Keller 2021-10-23 09:10:03 e_DF_ueberschussladung_Keller_charging_stopped 1
setstate DF_ueberschussladung_Keller 2021-10-23 09:32:25 e_DF_ueberschussladung_Keller_set_current_timestamp 13
setstate DF_ueberschussladung_Keller 2021-10-23 09:24:09 e_alfen_Socket_Keller_Charge_with_1_or_3_phases 1
setstate DF_ueberschussladung_Keller 2021-10-22 12:22:43 e_alfen_Socket_Keller_CurrentPhaseL1 0
setstate DF_ueberschussladung_Keller 2021-10-22 12:22:40 e_alfen_Socket_Keller_Mode3State A
setstate DF_ueberschussladung_Keller 2021-10-22 12:22:40 e_alfen_Socket_Keller_Mode3State_ EVSE ready and standby
setstate DF_ueberschussladung_Keller 2021-10-22 09:13:20 mode enabled
setstate DF_ueberschussladung_Keller 2021-10-23 09:32:27 number_of_phases_calc 1
setstate DF_ueberschussladung_Keller 2021-10-23 09:32:27 pvpower 3814.11
setstate DF_ueberschussladung_Keller 2021-10-23 09:32:29 set_charging_stopped_timestamp_sec 1346
setstate DF_ueberschussladung_Keller 2021-10-23 09:32:25 set_current_timestamp 13
setstate DF_ueberschussladung_Keller 2021-10-23 09:32:29 set_current_timestamp_sec 4
setstate DF_ueberschussladung_Keller 2021-10-23 09:24:09 set_phases_timestamp 1
setstate DF_ueberschussladung_Keller 2021-10-23 09:32:29 set_phases_timestamp_sec 500
setstate DF_ueberschussladung_Keller 2021-10-22 09:13:20 state initialized
setstate DF_ueberschussladung_Keller 2021-10-23 09:32:27 status Ueberschussladung
setstate DF_ueberschussladung_Keller 2021-10-23 09:32:27 tmp_calc_current 13
setstate DF_ueberschussladung_Keller 2021-10-08 13:21:06 zeitgesteuert on

