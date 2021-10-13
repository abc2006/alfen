############################################
# $Id: 15_alfenWB.pm 2021-10-13 09:25:24Z stephanaugustin $
# test 
package main;

use strict;
use warnings;

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
alfenWB_Initialize($)
{
  my ($hash) = @_;
## Weiss noch nicht, ob wir das brauchen
##  require "$attr{global}{modpath}/FHEM/DevIo.pm";

  $hash->{DefFn}     = "alfenWB_Define";
  $hash->{SetFn}     = "alfenWB_Set";
  $hash->{GetFn}     = "alfenWB_Get";
  $hash->{UndefFn}   = "alfenWB_Undef";
  $hash->{NotifyFn}    = "alfenWB_Notify";
  $hash->{ReadFn}    = "alfenWB_Read";
  $hash->{ReadyFn}    = "alfenWB_Ready";
  $hash->{AttrList}  = "interval ".
                        $readingFnAttributes;
}

#####################################
sub
alfenWB_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);
	
if(@a < 4 || @a > 4){
	my $msg = "wrong syntax: define <name> alfenWB <ip> <port>";
	return $msg;
}	
	my $name = $a[0];
	my $ip = $a[2];
	my $port = $a[3];
	
  $hash->{NAME} = $name;

  $hash->{NOTIFYDEV} 	= "global";
  $hash->{INTERVAL} = AttrVal($name,"interval",60);
  $hash->{actionQueue} 	= [];	

  return;
}


sub
alfenWB_DoInit($)
{
 my ($hash) = @_;
 my $name = $hash->{NAME};
 Log3($name, 2, "DoInitfkt");
 alfenWB_TimerGetData($hash);
}
###########################################
#_ready-function for reconnecting the Device
# function is called, when connection is down.
sub alfenWB_Ready($)
{
  my ($hash) = @_;

	my $name = $hash->{NAME};
	my $ret;
	$ret = DevIo_OpenDev($hash, 1, "alfenWB_DoInit" );
}
###################################
sub alfenWB_Notify($$){
my ($hash,$dev) = @_;
my $name = $hash->{NAME};

Log3 $name, 4, "alfenWB ($name) - alfenWB_Notify  Line: " . __LINE__;	
return if (IsDisabled($name));
my $devname = $dev->{NAME};
my $devtype = $dev->{TYPE};
my $events = deviceEvents($dev,1);
Log3 $name, 4, "alfenWB ($name) - alfenWB_Notify - not disabled  Line: " . __LINE__;	
return if (!$events);
if( grep /^ATTR.$name.interval/,@{$events} or grep /^INITIALIZED$/,@{$events}) {
	Log3 $name, 4, "alfenWB ($name) - alfenWB_Notify change Interval to AttrVal($name,interval,60) _Line: " . __LINE__;	
	$hash->{INTERVAL} = AttrVal($name,"interval",60);
}


Log3 $name, 4, "alfenWB ($name) - alfenWB_Notify got events @{$events} Line: " . __LINE__;	
alfenWB_TimerGetData("init:$name") if( grep /^INITIALIZED$/,@{$events}
				or grep /^CONNECTED$/,@{$events}
				or grep /^DELETEATTR.$name.disable$/,@{$events}
				or grep /^DELETEATTR.$name.interval$/,@{$events}
				or (grep /^DEFINED.$name$/,@{$events} and $init_done) );


return;

}
#####################################
sub alfenWB_Undef($$)
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
sub alfenWB_Set($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of reopen:noArg reset:noArg current:0,6,7,8,9,10,11,12,13,14,15,16 phases:1,3 charge:start,stop" ; 
	my $ret;
	my $minInterval = 30;
	Log3($name,5, "alfenWB argument $a[1] _Line: " . __LINE__);
  	if ($a[1] eq "?"){
	Log3($name,5, "alfenWB argument fragezeichen" . __LINE__);
	return $usage;
	}
	if($a[1] eq "reopen"){
		## Verbindung neu aufbauen
		}
		return "device opened";
	} elsif ($a[1] eq "reset"){
		##Verbindung trennen; 
		##Alle dynamischen Werte resetten;
		##Verbindung aufbauen;
	} elsif ($a[1] eq "current"){
		alfenWB_chargecurrent();
	} elsif ($a[1] eq "phases"){
		alfenWB_switch_phases();
	} elsif ($a[1] eq "charge"){
		alfenWB_charging();
	}
}
#####################################
sub alfenWB_Get($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Not yet implemented"; 
	Log3($name,5, "alfenWB argument $a[1]_Line: " . __LINE__);
  	if ($a[1] eq "?"){
	Log3($name,5, "alfenWB argument fragezeichen_Line: " . __LINE__);
	return $usage;
	}


}

############################################
sub alfenWB_TimerGetData(){
my ($calltype,$name) = split(':', $_[0]);
my $hash = $defs{$name};

if(IsDisabled($name) ) {
return; 
}

## request Values from WB


repeat with timer; 

InternalTimer( gettimeofday()+$hash->{INTERVAL}, 'alfenWB_TimerGetData', $hash);
alfenWB_sendRequests("next:$name");

}
####################################
sub alfenWB_sendRequests(){
my ($calltype,$name) = split(':', $_[0]);
my $hash = $defs{$name};
Log3 $name, 5, "alfenWB ($name) - alfenWB_sendRequests calltype $calltype  Line: " . __LINE__;	

## sende Anfragen zur Wallbox
## warte $interval 
## sende nochmal 
## usw...


}
#####################################
sub alfenWB_Read()
{
## Wird aufgerufen, wenn Daten zur Verfügung stehen. Hab ich mit TCP noch nicht genutzt
	my ($hash) = @_;
	my $name = $hash->{NAME};
	$hash->{CONNECTION} = "established";
	readingsSingleUpdate($hash, "_status","communication in progress",1);

	return;
}
##########################################################################################
sub alfenWB_analyze_answer($@){

	my ($hash,@values) = @_;
	my $name = $hash->{NAME};


}

1;


=pod
=begin html

=end html

=begin html_DE

=end html_DE
=cut
