defmod DF_chargenow DOIF (["alfen_Socket_Keller:Mode3State"] || [alfen_Socket_Keller:CurrentPhaseL1] > 5 || ["LRW3E7FA0MC336661:battery_level"] || [alfen_Socket_Keller:MaxCurrentValidTimeRemaining] < 30)\
{ \
if("[alfen_Socket_Keller:Mode3State]" eq "C1" || "[alfen_Socket_Keller:Mode3State]" eq "C2")\
{\
\
	if([LRW3E7FA0MC336661:battery_level:sec] < 300 && [LRW3E7FA0MC336661:battery_level] < 50 )\
	{\
		fhem("set alfen_Socket_Keller Charge_Current 14");;\
		fhem("setreading $SELF status battery_low");;\
	}\
	elsif ([fsp10k:Solar_input_power_total:d] > 4140)\
	{\
		my $charge_current=int([fsp10k:Solar_input_power_total:d]/230/3);;\
		fhem("set alfen_Socket_Keller Charge_Current $charge_current");;\
		fhem("setreading $SELF status pv over");;\
	}else{\
		fhem("set alfen_Socket_Keller Charge_Current 0");;\
		fhem("setreading $SELF status stopped");;\
	}\
\
}\
\
}\

attr DF_chargenow do always
attr DF_chargenow event_Readings available_charge_power:[fsp10k:Solar_input_power_total:d],\
actual_charge_current_setpoint:[alfen_Socket_aussen:ActualAppliedMaxCurrent:d0]
attr DF_chargenow room _types->doif,tesla

setstate DF_chargenow disabled
setstate DF_chargenow 2021-10-22 09:12:08 Device alfen_Socket_Keller
setstate DF_chargenow 2021-10-20 14:32:18 actual_charge_current_setpoint 7
setstate DF_chargenow 2021-10-22 09:12:09 available_charge_power 3633
setstate DF_chargenow 2021-10-22 09:11:50 cmd 1
setstate DF_chargenow 2021-10-22 09:11:50 cmd_event alfen_Socket_Keller
setstate DF_chargenow 2021-10-22 09:11:50 cmd_nr 1
setstate DF_chargenow 2021-10-21 21:11:56 e_alfen_Socket_Keller_CurrentPhaseL1 0
setstate DF_chargenow 2021-10-22 09:12:08 e_alfen_Socket_Keller_MaxCurrentValidTimeRemaining 40
setstate DF_chargenow 2021-10-22 09:12:10 last_cmd cmd_1
setstate DF_chargenow 2021-10-22 09:12:10 mode disabled
setstate DF_chargenow 2021-10-22 09:12:10 state disabled
setstate DF_chargenow 2021-10-22 09:11:50 status stopped

