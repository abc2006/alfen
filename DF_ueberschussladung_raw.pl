ueberschussgesteuert{
	my $callback = [alfen_Socket_aussen:MaxCurrentValidTimeRemaining];
	if([?alfen_Socket_aussen:state] eq "disconnected")
	{
	return;
	}
	
	if(get_Exec("tmr_wb_vollgas")){
		##fhem("set remotebot message Zeitladung->Vollgas");
		if([?alfen_Socket_aussen:Charge_with_1_or_3_phases] == 1 ){
			fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases 3");
		}
		fhem("set alfen_Socket_aussen Charge_Current 14");
		fhem("setreading $SELF status Zeitladung -> Vollgas");
		return;
	}

	my $mode3state = [?alfen_Socket_aussen:Mode3State_];
	if([?alfen_Socket_aussen:Mode3State] =~ /[ABEF]/){
		##fhem("set remotebot message Laden unterbrochen");
		fhem("setreading $SELF charging_stopped $mode3state");
		fhem("setreading $SELF status Kein Fahrzeug angeschlossen");
		fhem("set alfen_Socket_aussen Charge_Current 0");
		return;
	}


	fhem("setreading $SELF status Ueberschussladung");
	#Wieviel Leistung steht mir zum Laden zur Verfügung? 
	my $available_charge_power = [?$SELF:available_charge_power:d];	
	##debug-variable
	##$available_charge_power = 4100;	
	my $number_of_phases;
	fhem("setreading $SELF available_charge_power_debug $available_charge_power");


## Entscheide, wie viele phasen verwendet werden
	if ($available_charge_power < 4000){
		$number_of_phases = 1;
	## Wenn die Leistung über 4k5 liegt, 3-phasig laden
	}elsif ($available_charge_power >= 4000){
		$number_of_phases = 3;
	}
	fhem("setreading $SELF number_of_phases_calc $number_of_phases");

	my $available_charge_current = int($available_charge_power/230/[?alfen_Socket_aussen:Charge_with_1_or_3_phases]);
	## 100% = 425 km
	## 25% = 100km
	if([?LRW3E7FA0MC336661:battery_range_] < 100 && [?LRW3E7FA0MC336661:battery_range_:sec] < 135) {
		$number_of_phases = 3; 
		$available_charge_current = 16;
	}
##############################################################################
## setze die entscheidung um	##############################################
##############################################################################
	if([?$SELF:set_phases_timestamp:sec] > 300 && $number_of_phases != [?alfen_Socket_aussen:Charge_with_1_or_3_phases])	{
		fhem("set alfen_Socket_aussen Charge_with_1_or_3_phases $number_of_phases");
		fhem("setreading $SELF set_phases_timestamp $number_of_phases");
	}
	
##Entscheide mit wie viel Strom geladen wird
	fhem("setreading $SELF tmp_calc_current $available_charge_current");
	
	if($available_charge_current < 5 && [?alfen_Socket_aussen:Charge_with_1_or_3_phases] == 1 ){
		$available_charge_current = 0;
		##fhem("setreading $SELF charging_stopped 1");
		##fhem("set alfen_Socket_aussen Charge_Current $available_charge_current");
	}elsif($available_charge_current < 6){
		$available_charge_current = 6;
	}

## setze die Entscheidung um 
	if([?$SELF:charging_stopped:sec] > 120){
		if([?$SELF:set_current_timestamp:sec] > 15 )	{
			if($available_charge_current > 14){
				$available_charge_current = 14;
			}
			fhem("set alfen_Socket_aussen Charge_Current $available_charge_current");
			fhem("setreading $SELF set_current_timestamp $available_charge_current");
		}
	}
}
zeitgesteuert {
my $time_sec = [$SELF:charge_vollgas_km]/80*3600;
set_Exec("tmr_wb_vollgas", $time_sec, '');
fhem("setreading $SELF charge_vollgas_km 0");

return;
}
