subs {
sub set_charge_current{
	my ($current) = shift // return "1";
	my $charging_stopped_age = ReadingsAge("$SELF","charging_stopped","");
	##my $current_set_age = ReadingsAge("$SELF","set_current_timestamp_sec","");
	my $valid_time_remaining = ReadingsNum("alfen_Socket_aussen","MaxCurrentValidTimeRemaining", "1");
	my $actual_max_current = ReadingsNum("alfen_Socket_aussen","ActualAppliedMaxCurrent", "1");
		if($charging_stopped_age > 120){
				if(
					($valid_time_remaining < 30 && $current == $actual_max_current)
				||	($valid_time_remaining < 285 && $current != $actual_max_current))
				{
				fhem("set alfen_Socket_aussen Charge_Current $current");
				##fhem("setreading $SELF set_current_timestamp_sec $current");
				Log3("$SELF",3,"set_charge_current() set alfen_Socket_aussen Charge_Current $current");
				}
		}
	return 0; 
	}# set charge current
} # subs

ueberschussgesteuert{
	Log3("$SELF",5,"set_charge_current() EVENTS $EVENTS");
	my $callback = [alfen_Socket_aussen:MaxCurrentValidTimeRemaining];
	my $ret;
	$ret = set_charge_current("0");
	Log3("$SELF",2,"set_charge_current() ret $ret");
	if([?alfen_Socket_aussen:state] eq "disconnected")
	{
	return;
	}
	# Wenn das EV nicht angeschlossen ist oder ein Fehler vorliegt: 
		my $mode3state_ = [?alfen_Socket_aussen:Mode3State_];
		my $mode3state = [?alfen_Socket_aussen:Mode3State];
	fhem("setreading $SELF mode3state $mode3state");
##	if($mode3state =~ /[AEF]/){
	if($mode3state eq "A" || $mode3state eq "E" || $mode3state eq "F"){
		fhem("setreading $SELF charging_stopped $mode3state_");
		fhem("setreading $SELF status Kein Fahrzeug angeschlossen");
		$ret = set_charge_current("0");
		fhem("setreading $SELF sofortladung nein");
		Log3("$SELF",0,"set_charge_current() ret $ret");
		
		return;
	}
	## Wenn sofortladung eingeschaltet ist
	if([?$SELF:sofortladung] eq "ja"){
		if([?alfen_Socket_aussen:Charge_with_1_or_3_phases] == 1 ){
			fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases 3");
		}
		$ret = set_charge_current("16");
		fhem("setreading $SELF status Sofortladung -> Vollgas");
		Log3("$SELF",0,"set_charge_current() ret $ret");
		return;
	}
	
	if([?LRW3E7FA0MC336661:battery_level] >= [?LRW3E7FA0MC336661:charge_limit_soc] && [?LRW3E7FA0MC336661:battery_level:sec] < 1800 && [?LRW3E7FA0MC336661:charge_limit_soc:sec] < 1800)
	{
		$ret = set_charge_current("16");
		fhem("setreading $SELF status Standby - provide Power for preheat");
		Log3("$SELF",0,"set_charge_current() ret $ret");
		return;	
	}
	# Wenn sonst der Akku beschädigt wird, weil er zu leer ist
	if([?LRW3E7FA0MC336661:battery_range_:sec] < 300 && [?LRW3E7FA0MC336661:battery_level] < 10){
		if([?alfen_Socket_aussen:Charge_with_1_or_3_phases] == 1 ){
			fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases 1");
		}
		$ret = set_charge_current("6");
		fhem("setreading $SELF status EVFirst");
		Log3("$SELF",0,"set_charge_current() ret $ret");
		return;
	}	

	# wenn der WR leer ist und das Auto weniger als 50 % hat ( im Winter kann man hier bestimmt 80% nehmen), kann das Auto entscheiden
	if([?fsp10k:AC_input_active_Power_total:d] == 0 && ([?LRW3E7FA0MC336661:battery_range_:sec] < 300 || [?LRW3E7FA0MC336661:battery_level] < 15)){
		if([?alfen_Socket_aussen:Charge_with_1_or_3_phases] == 1 ){
			fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases 3");
		}
		$ret = set_charge_current("16");
		Log3("$SELF",0,"set_charge_current() ret $ret");
		fhem("setreading $SELF status WRempty");
		return;
	}
	# Wenn die Batterie voll ist, wird das Auto auch geladen, unabhängig vom Ladestand. 
	# Wo ist jetzt der Punkt, dass wir bei angeschlossenem Auto die Energie lieber sofort ins Auto tun?
	if([?BMS:1_SOC_BMS_total] > [?BMS:1_SOC_lademax]+5 && [?fsp10k:Solar_input_power_total:d] > 1500){
		if([?alfen_Socket_aussen:Charge_with_1_or_3_phases] == 1 ){
			fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases 3");
		}
		$ret = set_charge_current("16");
		fhem("setreading $SELF status PVBattery full");
		Log3("$SELF",0,"set_charge_current() ret $ret");
		return;
	}
	
###############################################################
# Wenn jetzt alles passt, dann ist PV-Überschuss da
###############################################################


	##fhem("setreading $SELF status Ueberschussladung");
	#Wieviel Leistung steht mir zum Laden zur Verfügung? 
	my $available_charge_power = [?gendev_PV:98_available_power:d]+[?BMS:1_Power_total:d]-500;	
	my $number_of_phases;
	my $status = "Ueberschussladung";
	fhem("setreading $SELF available_charge_power_debug_from_gendev_PV $available_charge_power");

	
## Entscheide, wie viele phasen verwendet werden
	if($available_charge_power < 1380){ 
		$status .= " - Low Power (<1380)";
		fhem("setreading $SELF set_current_timestamp 0");
		return;
	}elsif($available_charge_power < 4140){ # && > 1380
		$status .= " - 1ph-Power (<4000)";
		$number_of_phases = 1;
	## Wenn die Leistung über 4140 liegt, 3-phasig laden
	}elsif ($available_charge_power >= 4140){
		$status .= " - 3ph-Power (>4000)";
		$number_of_phases = 3;
	}
	fhem("setreading $SELF number_of_phases_calc $number_of_phases");
	fhem("setreading $SELF status $status");
	## 100% = 425 km
	## 25% = 100km
	
##############################################################################
## setze die entscheidung um	##############################################
##############################################################################
	fhem("setreading $SELF set_phases_timestamp_sec " . [$SELF:set_phases_timestamp:sec]);
	if($number_of_phases != [?alfen_Socket_aussen:Charge_with_1_or_3_phases]){
		if($number_of_phases == 1 && [?$SELF:set_phases_timestamp:sec] > 600){
			#runter mit kurzem delay
			##fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases 1");
			fhem("setreading $SELF set_phases_timestamp $number_of_phases");

		}
		if($number_of_phases == 3 && [?$SELF:set_phases_timestamp:sec] > 300)	{
			# hoch nur mit längerem delay
			##fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases 3");
			fhem("setreading $SELF set_phases_timestamp $number_of_phases");
		}
	}
	#Berechne mit wie viel Strom geladen wird
	my $available_charge_current = int($available_charge_power/230/[?alfen_Socket_aussen:Charge_with_1_or_3_phases]);
	if([?BMS:1_SOC_BMS_total] > 30){
	$available_charge_current = $available_charge_current+1;
	}
	
	fhem("setreading $SELF tmp_calc_current $available_charge_current");
	
if($available_charge_current > 0 && $available_charge_current < 6){
	$available_charge_current = 6;
}	
	
if($available_charge_current > 16){
	$available_charge_current = 16;
}
$ret = set_charge_current($available_charge_current);
Log3("$SELF",0,"set_charge_current() ret $ret");

}

sofortladen{
if([?$SELF:sofortladung] eq "ja")
{
fhem("setreading DF_ueberschussladung_aussen sofortladung nein");
} else {
fhem("setreading DF_ueberschussladung_aussen sofortladung ja");
}
return;
}# sofortladen



