############################################
# $Id: 15_fsp10k.pm 2016-01-14 09:25:24Z stephanaugustin $
# test 
package main;

use strict;
use warnings;
use Digest::CRC qw(crc);

my %requests = (
	'QPI' => "515049beac0d", ##  Device Protocol ID Inquiry
##	'QID' => "514944d6ea0d", ## Device Serial Number Inquiry
	'QVFW' => "5156465762990d", ## Main CPU Firmware version Inqiry
	'QVFW2' => "5156465732c3f50d", ## Another CPU Firmware version Inqiry
	'QPIRI' => "5150495249f8540d", ## Device rating information Inquiry
	'QFLAG' => "51464c414798740d", ##Device Flag status Inquiry
	'QPIGS' => "5150494753b7a90d", ## Device general Status parameters Inquiry
	'QPIWS' => "5150495753b4da0d", ##Device Warning Status Inquiry
#	'QDI' => "514449711b0d", ## Default Setting Value Information - default settings - needed to restore defaults, in the software
#	'QMCHGCR' => "514d4348474352d8550d", ## Enquiry selectable value about max charging current - needed for creating the dropdown in the software
#	'QMUCHGCR' => "514d55434847435226340d", ##Enquiry selectable value about max utility charging current - needed for creating the dropdown in the software
#	'QBOOT' => "51424f4f540a88", ## Enquiry DSP has bootstrap or not
#	'QOPM' => "514f504da5c50d", ## Enquiry output mode (For 4000/5000)
#	'QPGS0' => "51504753303fda0d", ## Parallel Information Inquiry. same values as in QPIGS
#	'' => "", ## 
#	'' => "", ## 
#	'' => "", ## 
#	'' => "", ## 
#	'' => "", ## 
#	'QRST' => "5152535472bc0d", ## nicht dokumentiert, NAKss
#	'QMN' => "514d4ebb640d", ##nicht dokumentiert, NAKss 
	'QGMNI' => "51474d4e49290d", ##  nicht dokumentiert
	'QSID' => "51534944bb050d", ## nicht dokumentiert
#	'QBEQI' => "51424851492ea90d", ## nicht dokumentiert VERMUTUNG: Equalisation function - liefert keine Antwort
	'QBEGI' => "51424551492ea90d", ## nicht dokumentierti
	'QMOD' => "514d4f4449c10d" ## Device Mode inquiry
	);

#####################################
sub
fsp10k_Initialize($)
{
  my ($hash) = @_;
  require "$attr{global}{modpath}/FHEM/DevIo.pm";

  $hash->{DefFn}     = "fsp10k_Define";
  $hash->{SetFn}     = "fsp10k_Set";
  $hash->{GetFn}     = "fsp10k_Get";
  $hash->{UndefFn}   = "fsp10k_Undef";
  $hash->{NotifyFn}    = "fsp10k_Notify";
  $hash->{ReadFn}    = "fsp10k_Read";
  $hash->{ReadyFn}    = "fsp10k_Ready";
  $hash->{AttrList}  = "interval Anschluss unknown_as_reading:yes,no ".
                        $readingFnAttributes;

  $hash->{helper}{value} = "";
  $hash->{helper}{key} = "";
  $hash->{helper}{retrycount} = 0;
}

#####################################
sub
fsp10k_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);
	
if(@a < 3 || @a > 5){
	my $msg = "wrong syntax: define <name> fsp10k <device>";
	return $msg;
}	
	my $name = $a[0];
	my $device = $a[2];
 
  $hash->{NAME} = $name;
  ## $hash->DeviceName keeps the name of the io-Device. Without this, DevIO does not work.
  $hash->{DeviceName} = $device;
  $hash->{NOTIFYDEV} 	= "global";
  $hash->{INTERVAL} = AttrVal($name,"interval",60);
  $hash->{actionQueue} 	= [];	
#close connection if maybe open (on definition modify)
  DevIo_CloseDev($hash) if(DevIo_IsOpen($hash));  
  my $ret = DevIo_OpenDev($hash, 0, "fsp10k_DoInit" );
  Log3($name, 1, "fsp10k DevIO_OpenDev_Define" . __LINE__); 
  return $ret;
}


sub
fsp10k_DoInit($)
{
 my ($hash) = @_;
 my $name = $hash->{NAME};
 Log3($name, 2, "DoInitfkt");
 fsp10k_TimerGetData($hash);
}
###########################################
#_ready-function for reconnecting the Device
# function is called, when connection is down.
sub fsp10k_Ready($)
{
  my ($hash) = @_;

	my $name = $hash->{NAME};
	my $ret;
	$ret = DevIo_OpenDev($hash, 1, "fsp10k_DoInit" );
}
###################################
sub fsp10k_Notify($$){
my ($hash,$dev) = @_;
my $name = $hash->{NAME};

Log3 $name, 4, "fsp10k ($name) - fsp10k_Notify  Line: " . __LINE__;	
return if (IsDisabled($name));
my $devname = $dev->{NAME};
my $devtype = $dev->{TYPE};
my $events = deviceEvents($dev,1);
Log3 $name, 4, "fsp10k ($name) - fsp10k_Notify - not disabled  Line: " . __LINE__;	
return if (!$events);
if( grep /^ATTR.$name.interval/,@{$events} or grep /^INITIALIZED$/,@{$events}) {
	Log3 $name, 4, "fsp10k ($name) - fsp10k_Notify change Interval to AttrVal($name,interval,60) _Line: " . __LINE__;	
	$hash->{INTERVAL} = AttrVal($name,"interval",60);
}


Log3 $name, 4, "fsp10k ($name) - fsp10k_Notify got events @{$events} Line: " . __LINE__;	
fsp10k_TimerGetData($hash) if( grep /^INITIALIZED$/,@{$events}
				or grep /^CONNECTED$/,@{$events}
				or grep /^DELETEATTR.$name.disable$/,@{$events}
				or grep /^DELETEATTR.$name.interval$/,@{$events}
				or (grep /^DEFINED.$name$/,@{$events} and $init_done) );


return;

}
#####################################
sub fsp10k_Undef($$)
{
  my ($hash, $name) = @_;
  DevIo_CloseDev($hash);         
  RemoveInternalTimer($hash);
  RemoveInternalTimer("resend:$name");
  RemoveInternalTimer("next:$name");
  RemoveInternalTimer("first:$name");
  return undef;
}
#####################################
sub fsp10k_Set($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of reopen:noArg reset:noArg"; 
	my $ret;
	my $minInterval = 30;
	Log3($name,5, "fsp10k argument $a[1] _Line: " . __LINE__);
  	if ($a[1] eq "?"){
	Log3($name,5, "fsp10k argument fragezeichen" . __LINE__);
	return $usage;
	}
	if($a[1] eq "reopen"){
		if(DevIo_IsOpen($hash)){
			Log3($name,1, "Device is open, closing ... Line: " . __LINE__);
			DevIo_CloseDev($hash);
			Log3($name,1, "fsp10k Device closed Line: " . __LINE__);
		} 
		Log3($name,1, "fsp10k_Set  Device is closed, trying to open Line: " . __LINE__);
		$ret = DevIo_OpenDev($hash, 1, "fsp10k_DoInit" );
		while(!DevIo_IsOpen($hash)){
			Log3($name,1, "fsp10k_Set  Device is closed, opening failed, retrying" . __LINE__);
			$ret = DevIo_OpenDev($hash, 1, "fsp10k_DoInit" );
			sleep 1;
		}
		return "device opened";
	} elsif ($a[1] eq "reset"){
	$hash->{helper}{value} = "";
	$hash->{helper}{key} = "";
	@{$hash->{actionQueue}} = ();
	Log3($name,1, "fsp10k_Set actionQueue is empty: @{$hash->{actionQueue}} Line:" . __LINE__);
	fsp10k_TimerGetData($hash);
	}
	
}
#####################################
sub fsp10k_Get($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of calcHex"; 
	Log3($name,5, "fsp10k argument $a[1]_Line: " . __LINE__);
  	if ($a[1] eq "?"){
	Log3($name,5, "fsp10k argument fragezeichen_Line: " . __LINE__);
	return $usage;
	}
#	my $value="QPI";
#	my $hex = unpack("H*", $value);
#my @s=( { 's'=>"An Arbitrary String", 'crc16'=>"DDFC", 'crc32'=>"90415518" },
#       { 's'=>"ZYXWVUTSRQPONMLKJIHGFEDBCA", 'crc16'=>"B199", 'crc32'=>"6632024D (not xored)" },
#   );
#	my @list = (crc16($hex) =~ /(..)/g);

#	my $finale =  map { pack ("H2", $_) } @list;

##	'QPI' => "515049beac0d", ##  Device Protocol ID Inquiry
#	my $input="QPI";
#	my $width=16;
#	my $init="0x0000";
#	my $xorout="0x0000";
#	my $refout="false";
#       	my $poly="0x1021";
#	my $refin="false";
#	my $cont=1;
	#check=0x31c3 
	#residue=0x0000 
	#name="CRC-16/XMODEM"
	
#my 	$crc = crc($input,$width,$init,$xorout,$refout,$poly,$refin,$cont);

#     	my $finale = crc("QPI",16,0x0000,i);
#	Log3($name,1, "fsp10k get $crc _Line: " . __LINE__);



}

############################################
sub fsp10k_TimerGetData($){
my $hash = shift;
my $name = $hash->{NAME};
Log3 $name, 4, "fsp10k ($name) _TimerGetData - action Queue 1: $hash->{actionQueue} Line: " . __LINE__;	
Log3 $name, 4, "fsp10k ($name) _TimerGetData - actionQueue_array  @{$hash->{actionQueue}}  Line: " . __LINE__;	
if(defined($hash->{actionQueue}) and scalar(@{$hash->{actionQueue}}) == 0 ){
	Log3 $name, 4, "fsp10k ($name) _TimerGetData - is defined and empty. Line: " . __LINE__;	
	if( not IsDisabled($name) ) {
		Log3 $name, 4, "fsp10k ($name) _TimerGetData - is not disabled. Line: " . __LINE__;	
		while( my ($key,$value) = each %requests ){
		Log3 $name, 4, "fsp10k ($name) _TimerGetData - actionQueue fill: $key  Line: " . __LINE__;	
		Log3 $name, 4, "fsp10k ($name) _TimerGetData - actionQueue fill: $value  Line: " . __LINE__;	
			unshift( @{$hash->{actionQueue}}, $value );
			unshift( @{$hash->{actionQueue}}, $key );
			#My $hash = (
			#	foo => [1,2,3,4,5],
			#	bar => [a,b,c,d,e]
			#);
			#@{$hash{foo}} would be (1,2,3,4,5)
		}
		Log3 $name, 4, "fsp10k ($name) _TimerGetData - actionQueue filled: @{$hash->{actionQueue}}  Line: " . __LINE__;	
		Log3 $name, 4, "fsp10k ($name) _TimerGetData - call fsp10k_sendRequests Line: " . __LINE__;	
		fsp10k_sendRequests("first:$name");
	}else{
		readingsSingleUpdate($hash,'state','disabled',1);
	}
	InternalTimer( gettimeofday()+$hash->{INTERVAL}, 'fsp10k_TimerGetData', $hash);
	Log3 $name, 4, "fsp10k ($name) _TimerGetData - call InternalTimer fsp10k_TimerGetData Line: " . __LINE__;	
}else {
	Log3 $name, 4, "fsp10k ($name) _TimerGetData - call fsp10k_sendRequests Line: " . __LINE__;	
	fsp10k_sendRequests("next:$name");
}
}
####################################
sub fsp10k_sendRequests($){
my ($calltype,$name) = split(':', $_[0]);
my $hash = $defs{$name};
Log3 $name, 5, "fsp10k ($name) - fsp10k_sendRequests calltype $calltype  Line: " . __LINE__;	

#Wenn aufgerufen wird, dass die nächste Abfrage erfolgt, und der Empfangsbuffer leer ist
if($calltype eq "next" && $hash->{helper}{recv} eq ""){ 
	if(defined($hash->{actionQueue}) and scalar(@{$hash->{actionQueue}}) > 0 ){
		$hash->{helper}{value} = pop( @{$hash->{actionQueue}} );
		$hash->{helper}{key} = pop( @{$hash->{actionQueue}} );
		$hash->{helper}{retrycount} = 0;
		if(!defined($hash->{helper}{key}) || $hash->{helper}{key} eq ""){
			Log3 $name, 4, "fsp10k ($name) - fsp10k_sendRequests_next key not defined or empty, finish  Line: " . __LINE__;
			return;	
		}
	}else{
	Log3 $name, 4, "fsp10k ($name) - fsp10k_sendRequests actionQueue not defined or empty, finish  Line: " . __LINE__;
	}
}elsif($calltype eq "resend" && $hash->{helper}{recv} eq ""){ 
	my $delta = gettimeofday() - $hash->{helper}{resend};
	Log3 $name, 5, "fsp10k ($name) - fsp10k_sendRequests_resend delta: $delta   Line: " . __LINE__;
	$hash->{CONNECTION} = "timeout";
	readingsSingleUpdate($hash, "_status","communication failed",1);
	if($hash->{helper}{retrycount} > 10) {
		Log3 $name, 4, "fsp10k ($name) - fsp10k_sendRequests retryCount reached, next one  Line: " . __LINE__;	
	
		$hash->{helper}{value} = pop( @{$hash->{actionQueue}} );
		$hash->{helper}{key} = pop( @{$hash->{actionQueue}} );
		$hash->{helper}{retrycount} = 0;
		if(!defined($hash->{helper}{key}) || $hash->{helper}{key} eq ""){
			Log3 $name, 4, "fsp10k ($name) - fsp10k_sendRequests_resend key not defined or empty, finish  Line: " . __LINE__;
			return;	
		}
	}else{
	$hash->{helper}{retrycount}++;
	Log3 $name, 4, "fsp10k ($name) - fsp10k_sendRequests receivebuffer $hash->{helper}{recv}. retryCount is  $hash->{helper}{retrycount} Line: " . __LINE__;	
	}
}else{
	Log3 $name, 4, "fsp10k ($name) - fsp10k_sendRequests receivebuffer not empty: _$hash->{helper}{recv}_ Line: " . __LINE__;	
}


Log3 $name, 4, "fsp10k ($name) - fsp10k_sendRequests value: $hash->{helper}{value}  Line: " . __LINE__;	
Log3 $name, 4, "fsp10k ($name) - fsp10k_sendRequests key: $hash->{helper}{key}  Line: " . __LINE__;	
$hash->{helper}{recv} = "";
$hash->{helper}{resend} = gettimeofday();
DevIo_SimpleWrite($hash,$hash->{helper}{value},1);
if($hash->{helper}{value} ne "" &&  $hash->{helper}{key} ne ""){ 
	InternalTimer(gettimeofday()+2,'fsp10k_sendRequests',"resend:$name");
	Log3 $name, 4, "fsp10k ($name) - fsp10k_sendRequests starte resend-timer. Line: " . __LINE__;	
} else {
	Log3 $name, 4, "fsp10k ($name) - fsp10k_sendRequests key or value empty. Aborting. Line: " . __LINE__;	
	return;
}	
}
#####################################
sub fsp10k_Read($$)
{

	my ($hash) = @_;
	my $name = $hash->{NAME};
	$hash->{CONNECTION} = "established";
	readingsSingleUpdate($hash, "_status","communication in progress",1);
	Log3($name,4, "fsp10k jetzt wird gelesen _Line:" . __LINE__);
	# read from serial device
	#
	
        my $buf =  DevIo_SimpleRead($hash);
	Log3($name,5, "fsp10k buffer: $buf");
	if (!defined($buf)  || $buf eq "")
	{ 
		
		Log3($name,1, "fsp10k Fehler beim lesen _Line:" . __LINE__);
		$hash->{CONNECTION} = "failed";
		return "error" ;
	}
 	# es geht los mit 0x28 und hört auf mit 0x0d - eigentlich.	
	$hash->{helper}{recv} .= $buf; 
	
	Log3($name,5, "fsp10k helper: $hash->{helper}{recv}"); 
	my $hex_before = unpack "H*", $hash->{helper}{recv};
	Log3($name,5, "fsp10k hex_before: $hex_before");
	## now we can modify the hex string ... 
	if($hex_before =~ /28(.*)....0d/){
	Log3($name,5, "fsp10k hex without start and CRC: $1");

		my @h1 = ($1 =~ /(..)/g);
		my @ascii_ary = map { pack ("H2", $_) } @h1;
		my $asciistring;
	foreach my $part (@ascii_ary){
		$asciistring .= $part;
	}
		Log3($name,5, "fsp10k ascii: $asciistring");
		my @splits = split(" ",$asciistring);
		Log3($name,5, "fsp10k splits: @splits");
		fsp10k_analyze_answer($hash, @splits);
	if(defined($hash->{actionQueue}) and scalar(@{$hash->{actionQueue}}) != 0 ){
		Log3 $name, 4, "fsp10k ($name) - fsp10k_ReadFn Noch nicht alle Abfragen gesendet, rufe sendRequests wieder auf  Line: " . __LINE__;	
		Log3 $name, 4, "fsp10k ($name) - fsp10k_ReadFn Noch anstehende Abfragen:  @{$hash->{actionQueue}} Line: " . __LINE__;	
		fsp10k_sendRequests("next:$name");
	}else{
	
	readingsSingleUpdate($hash, "_status","communication finished, standby",1);
	}
	}
 
	return;
}
##########################################################################################
sub fsp10k_analyze_answer($@){

	my ($hash,@values) = @_;
	my $name = $hash->{NAME};
	my $cmd = $hash->{helper}{key};
	my $success = "failed";
	Log3($name,4, "fsp10k cmd: $cmd _Line:" . __LINE__);

		Log3($name,5, "fsp10k analysiere ueberhaupt mal irgendwas _Line:" . __LINE__);

	if($values[0] =~ /NAK/){
		Log3($name,5, "fsp10k analysiere $values[0] _Line:" . __LINE__);
		Log3($name,5, "fsp10k Keine Gültige Abfrage, Antwort fehlerfrei. Abbruch. _Line:" . __LINE__);
		##fsp10k_blck_doInternalUpdate($hash); 
			$hash->{helper}{key} = "";
		$hash->{helper}{value} = "";
		$hash->{helper}{retrycount} = "";
		Log3($name, 5, "fsp10k ($name) - fsp10k_analyze_answer stoppe resend-timer. Line: " . __LINE__);	
		RemoveInternalTimer("resend:$name");
return;
	}

if($cmd eq "QPIRI") {

		Log3($name,4, "fsp10k cmd: analysiere qpiri _Line:" . __LINE__);
					readingsBeginUpdate($hash);
						readingsBulkUpdate($hash,"Grid_rating_Voltage",$values[0],1);
						readingsBulkUpdate($hash,"Grid_rating_Current",$values[1],1);
						readingsBulkUpdate($hash,"AC_output_rating_Voltage",$values[2],1);
						readingsBulkUpdate($hash,"AC_output_rating_Frequency",$values[3],1);
						readingsBulkUpdate($hash,"AC_output_rating_current",$values[4],1);
						readingsBulkUpdate($hash,"AC_output_rating_appearent_Power",$values[5],1);
						readingsBulkUpdate($hash,"AC_output_rating_active_Power",$values[6],1);
						readingsBulkUpdate($hash,"Battery_rating_voltage",$values[7],1);
						readingsBulkUpdate($hash,"Battery_re-charge_voltage",$values[8],1);
						readingsBulkUpdate($hash,"Battery_under_voltage",$values[9],1);
						readingsBulkUpdate($hash,"Battery_bulk_voltage",$values[10],1);
						readingsBulkUpdate($hash,"Battery_float_voltage",$values[11],1);
			
						## 0 = AGM, 1 = Flooded, 2 = User
						readingsBulkUpdate($hash,"Battery_type",$values[12],1);
						readingsBulkUpdate($hash,"Current_max_AC_charging_current",int($values[13]),1);
						readingsBulkUpdate($hash,"Current_max_charging_current",int($values[14]),1);
						
						# 0 = Appliance, 1 = UPS
						readingsBulkUpdate($hash,"Input_voltage_range",$values[15],1);
						#0 = Utility first, 1 = Solar first, 2 = SBU
						readingsBulkUpdate($hash,"Output_Source_priority",$values[16],1);
						#0 = Utility first, 1 = Solar first, 2 = Solar + Utility, 3: = only solar charging permitted
						readingsBulkUpdate($hash,"Charger_source_priority",$values[17],1);
						readingsBulkUpdate($hash,"Parallel_max_num",$values[18],1);
						#00 Grid tie, 01 off grid 10 Hybrid
						readingsBulkUpdate($hash,"Machine_type",$values[19],1);
						# 0 transformerless, 1 transformer
						readingsBulkUpdate($hash,"Topology",$values[20],1);
						# 0 single machine 01 parallel output 02 phase 1 of 3 03 phase 2 of 3 04 phase 3 of 3
						readingsBulkUpdate($hash,"Output_Mode",$values[21],1);
						readingsBulkUpdate($hash,"Battery_re-discharge_voltage",$values[22],1);
						# 0 = as long as one unit has PV connected, parallel system will consider PV OK
						# 1 = inly all of inverters ghave connected pv, parallel system will consider PV OK
						readingsBulkUpdate($hash,"PV_OK_condition_for_parallel",$values[23],1);
						# 0 = PV ionput max current wl be the max charged current
						# 1 = PV input max power will be the sum of the max charged power and loads power.
						readingsBulkUpdate($hash,"PV_power_balance",$values[24],1);
					readingsEndUpdate($hash,1);
		Log3($name,5, "fsp10k $cmd successful _Line:" . __LINE__);
		$success="success";
}elsif($cmd eq "QMOD") {
	Log3($name,4, "fsp10k cmd: analysiere QMOD _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "fsp10k uebergeben: $a _Line:" . __LINE__);
	my $r;
	if($a eq "P") {$r = "Power on Mode";}
	elsif($a eq "S") {$r = "Standby Mode";}
	elsif($a eq "L") {$r = "Line Mode";}
	elsif($a eq "B") {$r = "Battery Mode";}
	elsif($a eq "F") {$r = "Fault Mode";}
	elsif($a eq "H") {$r = "Power saving Mode";}

	Log3($name,5, "fsp10k analyse: QMOD. Entscheidung für $r _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_Mode",$r,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fsp10k $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QFLAG") {
	Log3($name,4, "fsp10k cmd: analysiere QMOD _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "fsp10k uebergeben: $a _Line:" . __LINE__);
	my ($E,$D) = split(/D/, $a);
	my %flags = ();
##		'Silence_Buzzer' => "",
##		'Overload_Bypass_Function' => "",	
##		'Power_Saving' => "",	
##		'LCD_escape_to_default' => "",	
##		'Overload_restart' => "",	
###		'Overtemperature_restart' => "",	
##		'backlight_always_on' => "",	
##		'Alarm_on_pri_src_interrupt' => "",	
##		'Fault_Code_Record' => "",	
##	);
	if($E =~ m/a/) {$flags{'Silence_Buzzer'} = "enabled";} elsif($D =~ m/a/)  {$flags{'Silence_Buzzer'} = "disabled";} 
	if($E =~ m/b/) {$flags{'Overload_Bypass_Function'} = "enabled";} elsif($D =~ m/b/)  {$flags{'Overload_Bypass_Function'} = "disabled";} 
	if($E =~ m/j/) {$flags{'Power_Saving'} = "enabled";} elsif($D =~ m/j/)  {$flags{'Power_Saving'} = "disabled";} 
	if($E =~ m/k/) {$flags{'LCD_escape_to_default'} = "enabled";} elsif($D =~ m/k/)  {$flags{'LCD_escape_to_default'} = "disabled";} 
	if($E =~ m/u/) {$flags{'Overload_restart'} = "enabled";} elsif($D =~ m/u/)  {$flags{'Overload_restart'} = "disabled";} 
	if($E =~ m/v/) {$flags{'Overtemperature_restart'} = "enabled";} elsif($D =~ m/v/)  {$flags{'Overtemperature_restart'} = "disabled";} 
	if($E =~ m/x/) {$flags{'backlight_always_on'} = "enabled";} elsif($D =~ m/x/)  {$flags{'backlight_always_on'} = "disabled";} 
	if($E =~ m/y/) {$flags{'Alarm_on_pri_src_interrupt'} = "enabled";} elsif($D =~ m/y/)  {$flags{'Alarm_on_pri_src_interrupt'} = "disabled";} 
	if($E =~ m/z/) {$flags{'Fault_Code_Record'} = "enabled";} elsif($D =~ m/z/)  {$flags{'Fault_Code_Record'} = "disabled";} 

	readingsBeginUpdate($hash);
	foreach my $key (%flags){
		readingsBulkUpdate($hash,$key,$flags{$key},1);
	}
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fsp10k $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QPIGS") {
	Log3($name,4, "fsp10k cmd: analysiere QPIGS _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Grid_voltage",$values[0],1);
		readingsBulkUpdate($hash,"Grid_frequency",$values[1],1);
		readingsBulkUpdate($hash,"AC_output_voltage",$values[2],1);
		readingsBulkUpdate($hash,"AC_output_frequency",$values[3],1);
		readingsBulkUpdate($hash,"AC_output_appearent_power",int($values[4]),1);
		readingsBulkUpdate($hash,"AC_output_active_power",int($values[5]),1);
		readingsBulkUpdate($hash,"Output_load_percent",int($values[6]),1);
		readingsBulkUpdate($hash,"BUS_voltage",$values[7],1);
		readingsBulkUpdate($hash,"Battery_actual_voltage",$values[8],1);
		readingsBulkUpdate($hash,"Battery_charging_current",int($values[9]),1);
		readingsBulkUpdate($hash,"Battery_capacity_percent",int($values[10]),1);
		readingsBulkUpdate($hash,"Inverter_heat_sink_temperature",int($values[11]),1);
		readingsBulkUpdate($hash,"PV_Input_current_for_battery",int($values[12]),1);
		readingsBulkUpdate($hash,"PV_Input_voltage",int(10*$values[13])/10,1);
		readingsBulkUpdate($hash,"Battery_voltage_from_SCC",$values[14],1);
		readingsBulkUpdate($hash,"Battery_discharge_current",int($values[15]),1);
		readingsBulkUpdate($hash,"Device_Status",$values[16],1);
		readingsBulkUpdate($hash,"QPIGS_17",$values[17],1);
		readingsBulkUpdate($hash,"QPIGS_18",$values[18],1);
		readingsBulkUpdate($hash,"PV_input_actual_power",int($values[19]),1);
		readingsBulkUpdate($hash,"QPIGS_20",$values[20],1);
	readingsEndUpdate($hash,1);
	Log3($name,5, "fsp10k $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QPIWS") {
	Log3($name,3, "fsp10k cmd: analysiere QMOD _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,4, "fsp10k uebergeben: $a _Line:" . __LINE__);
	my $r; 
	if(int($a) == 0){
	$r = "no Error";
	}else{
	my @b = split(//,$a);
	if($b[0] == 1) {$r = "Reserved - no Error";}
	elsif($b[1] == 1) {$r = "Inverter - Fault";}
	elsif($b[2] == 1) {$r = "Bus Over (Voltage?) - Fault";}
	elsif($b[3] == 1) {$r = "Bus Under (Voltage?) - Fault";}
	elsif($b[4] == 1) {$r = "Bus Soft Fail - Fault";}
	elsif($b[5] == 1) {$r = "LINE_FAIL - Warning";}
	elsif($b[6] == 1) {$r = "OPVShort - Warning";}
	elsif($b[7] == 1) {$r = "Inverter Voltage too low - Fault";}
	elsif($b[8] == 1) {$r = "Inverter Voltage too high - Fault";}
	elsif($b[9] == 1) {
		$r = "Over temperature -";
		$r .= $b[1] == 1 ? "Fault":"Warning";			
		}
	elsif($b[10] == 1) {
		$r = "Fan locked";
		$r .= $b[1] == 1 ? "Fault":"Warning";			
	}
	elsif($b[11] == 1) {
		$r = "Battery Voltage High";
		$r .= $b[1] == 1 ? "Fault":"Warning";			
	}
	elsif($b[12] == 1) {$r = "Battery Low Alarm - Warning";}
	elsif($b[13] == 1) {$r = "Reserved - no Error";}
	elsif($b[14] == 1) {$r = "Battery under shutdown - Warning";}
	elsif($b[15] == 1) {$r = "Reserved, but still a Warning";}
	elsif($b[16] == 1) {
		$r = "Overload - ";
		$r .= $b[1] == 1 ? "Fault":"Warning";			
	}
	elsif($b[17] == 1) {$r = "EEPROM - Fault";}
	elsif($b[18] == 1) {$r = "Inverter Over Current - Fault";}
	elsif($b[19] == 1) {$r = "Inverter Soft Fail - Fault";}
	elsif($b[20] == 1) {$r = "Self Test Fail - Fault";}
	elsif($b[21] == 1) {$r = "OP DC Voltage Over - Fault";}
	elsif($b[22] == 1) {$r = "Bat Open - Fault";}
	elsif($b[23] == 1) {$r = "Current Sensor Fail - Fault";}
	elsif($b[24] == 1) {$r = "Battery Short - Fault";}
	elsif($b[25] == 1) {$r = "Power Limit - Warning";}
	elsif($b[26] == 1) {$r = "PV Voltage High - Warning";}
	elsif($b[27] == 1) {$r = "MPPT Overload Fault - Warning";}
	elsif($b[28] == 1) {$r = "MPPT Overload Warning - Warning";}
	elsif($b[29] == 1) {$r = "Battery too low to charge - Warning";}
	elsif($b[30] == 1) {$r = "Reserved - no Error";}
	elsif($b[31] == 1) {$r = "Reserved - no Error";}
	}
	Log3($name,5, "fsp10k analyse: QMOD. Entscheidung für $r _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_warning",$r,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fsp10k $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QVFW") {
	Log3($name,4, "fsp10k cmd: analysiere $cmd _Line:" . __LINE__);
	my ($b,$a) =split(":",$values[0]);
	Log3($name,5, "fsp10k uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Main_CPU_Firmware_Version",$a,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fsp10k $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QVFW2") {
	Log3($name,4, "fsp10k cmd: analysiere $cmd _Line:" . __LINE__);
	my ($b,$a) =split(":",$values[0]);
	Log3($name,5, "fsp10k uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Another_Firmware_CPU_version",$a,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fsp10k $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QID") {
	Log3($name,4, "fsp10k cmd: analysiere $cmd _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "fsp10k uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_Serial_Number",$a,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fsp10k $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QPI") {
	Log3($name,4, "fsp10k cmd: analysiere $cmd _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "fsp10k uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_Protocol_ID",$a,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fsp10k $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QGMNI") {
	Log3($name,4, "fsp10k cmd: analysiere $cmd _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "fsp10k uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"QGMNI_unknown",$a,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fsp10k $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QBEQI") {
	Log3($name,4, "fsp10k cmd: analysiere $cmd _Line:" . __LINE__);
	readingsBeginUpdate($hash);
	my $i = 0;
	foreach(@values)
	{
		Log3($name,5, "fsp10k $a _Line:" . __LINE__);
		readingsBulkUpdate($hash,$cmd . "_$i",$values[$i],1);
		$i++;
	}
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fsp10k $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QBEGI") {
	Log3($name,4, "fsp10k cmd: analysiere $cmd _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"QBEGI_0",$values[0],1);
		readingsBulkUpdate($hash,"Battery_equalisation_duration_minutes",$values[1],1);
		readingsBulkUpdate($hash,"Battery_equalisation_interval_days",$values[2],1);
		readingsBulkUpdate($hash,"Battery_charge_maximum_total_current",$values[3],1);
		readingsBulkUpdate($hash,"QBEGI_4",$values[4],1);
		readingsBulkUpdate($hash,"Battery_equalisation_voltage",$values[5],1);
		readingsBulkUpdate($hash,"QBEGI_0",$values[6],1);
		readingsBulkUpdate($hash,"Battery_equalisation_timeout_minutes",$values[7],1);
		readingsBulkUpdate($hash,"QBEGI_0",$values[8],1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fsp10k $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QSID") {
	Log3($name,4, "fsp10k cmd: analysiere $cmd _Line:" . __LINE__);
	readingsBeginUpdate($hash);
	my $i = 0;
	foreach(@values)
	{
		Log3($name,5, "fsp10k $cmd _$i $values[$i] _Line:" . __LINE__);
		readingsBulkUpdate($hash,"QSID_$i",$values[$i],1);
		$i++;
	}
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fsp10k $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "SPARE") {
	Log3($name,4, "fsp10k cmd: analysiere $cmd _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "fsp10k uebergeben: $a _Line:" . __LINE__);
	my $r;
	if($a eq "P") {$r = "Power on Mode";}
	elsif($a eq "S") {$r = "Standby Mode";}
	elsif($a eq "L") {$r = "Line Mode";}
	elsif($a eq "B") {$r = "Battery Mode";}
	elsif($a eq "F") {$r = "Fault Mode";}
	elsif($a eq "H") {$r = "Power saving Mode";}

	Log3($name,5, "fsp10k analyse: QMOD. Entscheidung für $r _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_Mode",$r,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fsp10k $cmd successful _Line:" . __LINE__);
	$success="success";
} else {
	Log3($name,1,"fsp10k cmd " . $cmd . " not implemented yet, putting values in _devel<nr>, Line: " . __LINE__);	
	readingsBeginUpdate($hash);
	my $i = 0;
	foreach (@values) 
	{
 		Log3($name,1,"fsp10k cmd  $cmd unknown, putting $values[$i] in _devel_$i");	
		if( AttrVal($name,"unknown_as_reading",0) eq "yes" ){
			readingsBulkUpdate($hash, "_devel_" . $i,$values[$i],1);
		}
		$i++;
	}
	readingsEndUpdate($hash,1);
	Log3($name,5, "fsp10k $cmd successful _Line:" . __LINE__);
	$success="success";
}

Log3($name,5, "fsp10k analyze ready. success: $success _Line:" . __LINE__);
if($success eq "success"){
	$hash->{CONNECTION} = "established";
	$hash->{helper}{key} = "";
	$hash->{helper}{value} = "";
	$hash->{helper}{retrycount} = 0;
	$hash->{helper}{recv} = "";
	Log3($name, 5, "fsp10k ($name) - fsp10k_analyze_answer stoppe resend-timer. Line: " . __LINE__);	
	RemoveInternalTimer("resend:$name");
}


}

1;


=pod
=begin html

=end html

=begin html_DE

=end html_DE
=cut
