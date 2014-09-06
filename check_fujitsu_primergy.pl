#!/usr/bin/perl -w

# COPYRIGHT:
#  
# This software is Copyright (c) 2007 NETWAYS GmbH, Christian Doebler 
#                                <support@netways.de>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from http://www.fsf.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.fsf.org.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to NETWAYS GmbH.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# this Software, to NETWAYS GmbH, you confirm that
# you are the copyright holder for those contributions and you grant
# NETWAYS GmbH a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# Nagios and the Nagios logo are registered trademarks of Ethan Galstad.


#
# Some of the code used in this plugin has been taken from various open-
# source plugins for Fujitsu servers found in the internet.
#


#
# please test your changes to this code for compliance with the syntax 
# rules of the nagios embedded perl interpreter. please run it from 
# within npi-new which you can find in the contrib dir of your nagios
# distibution.
#


=head1 NAME

check_fujitsu_primergy.pl - Nagios-Check Plugin for Fujitsu servers

=head1 SYNOPSIS

check_fujitsu_primergy.pl -H|--host=<host> -C|--community=<SNMP community string>
             [--blade]
             [-t|--timeout=<timeout in seconds>]
             [--fan-warning=<threshold>]
             [--fan-critical=<threshold>]
             [-v|--verbose=<>verbosity level>]
             [-e|--exclude=<subsystems to exclude from checks>]
             [-h|--help] [-V|--version]
  
Checks a Fujitsu server using SNMP.

=head1 OPTIONS

=over 4

=item -H|--host=<name-or-ip>

Hostname or ip address of the server to check

=item -C|--community=<SNMP community string>

The SNMP community.

=item --blade

switch the check mode to management blade, only the blade itself is checked

=item -t|--timeout=<timeout in seconds>

Time in seconds to wait before script stops.

=item --fan-warning=<threshold>

Threshold of fan speed (rpm) to give back a warning result.

=item --fan-critical=<threshold>

Threshold of fan speed (rpm) to give back a critical result.

=item -v|--verbose=<verbosity level>

Enable verbose mode (levels: 1,2).
Multi-line output will be generated with verbose level 2.

=item -e|--exclude=<subsystems to exclude from checks>

Comma-sepatated list of non-global subsystems (all except Environment,
PowerSupply, MassStorage and SystemBoard) to exclude from checking.
If a global subsystem is in this list it just won't be displayed in
plugin output but it won't affect the plugin's return state and return value.

Typically used to exclude the Deployment subsystem.

=item -V|--version

Print version an exit.

=item -h|--help

Print help message and exit.

=cut


use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case bundling);
use Pod::Usage;
use Net::SNMP;


sub printResultAndExit {

	# print check result and exit

	my $exitVal = shift;

	print "@_" if (defined @_);

	print "\n";

	# stop timeout
	alarm(0);

	exit($exitVal);
}

sub getSNMPRequest {

	my $oid = shift;

	print 'Checking OID \'' . $oid . '\'... ' if ($main::verbose >= 100);

	my $result = $main::session->get_request($oid);
	printResultAndExit(3, "UNKNOWN", 'Error: get_request(): ' . $main::session->error) unless (defined $result);

	print 'result: ' . $result->{$oid} . "\n" if ($main::verbose >= 100);

	return $result->{$oid};

}


# version string
my $version = '0.3';


# define states
our @state = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN');

# define bladestatus OID
my $oidBladeStatusID = '.1.3.6.1.4.1.7244.1.1.1.3.1.5.0';
my %BladeErrorMap = (   1       =>      3,
                        2       =>      0,
                        3       =>      1,
                        4       =>      2);

## define serverid OID
my $oidServerID = '.1.3.6.1.4.1.231.2.10.2.2.10.2.3.1.7.1';

# define powerconsumption OID
my $oidpowerconsumption = '.1.3.6.1.4.1.231.2.47.1.4.1.1.14.22.35.64.73.110.116.101.114.110.97.108.82.101.112.111.114.116.64.48.48.49.64.35';

# define global OIDs
my $oidPrefix = '1.3.6.1.4.1.231.2.10.2.11.';
my $oidSysStat = $oidPrefix . '2.1.0';
my $oidSubSysCnt = $oidPrefix . '3.2.0';
my $oidSubSys = $oidPrefix . '3.1.1';
my $oidSubSysDisplayName = $oidPrefix . '.4.1.1.5';
my @sysStat = (
	'dummy',
	'OK',
	'DEGRADED',
	'ERROR',
	'FAILED',
	'UNKNOWN'
);


# define environment-related OIDs
my $oidEnvFanPrefix = '1.3.6.1.4.1.231.2.10.2.2.5.2.2.1.';
my $oidEnvFanStatus = $oidEnvFanPrefix . '3';
my $oidEnvFanPurpose = $oidEnvFanPrefix . '4';
my $oidEnvFanSpeed = $oidEnvFanPrefix . '8';
my $oidEnvFanDesc = $oidEnvFanPrefix . '16';
my @fanChecks = (
	$oidEnvFanStatus,
	$oidEnvFanPurpose,
	$oidEnvFanSpeed,
	$oidEnvFanDesc
);
my $oidEnvTempPrefix = '1.3.6.1.4.1.231.2.10.2.2.5.2.1.1.';
my $oidEnvTempStatus = $oidEnvTempPrefix . '3';
my $oidEnvTempWarn = $oidEnvTempPrefix . '6';
my $oidEnvTempCrit = $oidEnvTempPrefix . '8';
my $oidEnvTempValue = $oidEnvTempPrefix . '11';
my $oidEnvTempDesc = $oidEnvTempPrefix . '13';
my @tempChecks = (
	$oidEnvTempStatus,
	$oidEnvTempValue,
	$oidEnvTempWarn,
	$oidEnvTempCrit,
	$oidEnvTempDesc
);


# define fan-related strings
my @fanStatus = (
    "dummy", "UNKNOWN", "DISABLED", "OK", "FAIL", "prefailure-predicted",
    "redundant-fan-failed", "not-manageable", "not-present"
);
my @fanPurpose = (
    "dummy",     "UNKNOWN", "DISABLE",      "cpu-onchip",
    "component", "housing", "power-supply", "not-available"
);
my @tempStatus = (
    "dummy", "UNKNOWN", "not-available", "OK", "dummy", "FAILED",
    "WARNING", "CRITICAL"
);


# init command-line parameters
my $argvCnt = $#ARGV + 1;
my $host = '';
my $community = '';
my $timeout = 0;
my $fanWarning = -1;
my $fanCritical = -1;
my $powerConsumption = undef;
my $showVersion = undef;
our $verbose = 0;
my $exclude = '';
my $help = undef;
$main::verbose = 1;


# init left variables
my $globalResult = undef;
my $serverID = undef;
my $result = undef;
my $fresult = undef;
my $tresult = undef;
my $fanPurpose;
my $fanStatus;
my $fanSpeed;
my $fanID;
my $optBlade = undef;
our $session;
my $error = '';
my $ferror = '';
my $msg = '';
my $fan_msg = '';
my $temp_msg = '';
my $perfdata = '';
my $exitVal = undef;
my $subsys_cnt = undef;
my @fans = ();
my @temps = ();
my @subsys_stati = (
	{},
	{
		'displayname'	=> 'Environment',
	},
	{
		'displayname' => 'PowerSupply',
	},
	{
		'displayname' => 'MassStorage',
	},
	{
		'displayname' => 'SystemBoard',
	}
);


# get command-line parameters
GetOptions(
   "H|host=s"		=> \$host,
   "C|community=s"	=> \$community,
   "t|timeout=i"	=> \$timeout,
   "fan-warning=i"	=> \$fanWarning,
   "fan-critical=i"	=> \$fanCritical,
   "v|verbose=i"	=> \$main::verbose,
   "blade"		=> \$optBlade,
   "e|exclude=s"	=> \$exclude,
   "V|version"		=> \$showVersion,
   "h|help"			=> \$help,
) or pod2usage({
	-msg     => "\n" . 'Invalid argument!' . "\n",
	-verbose => 1,
	-exitval => 3
});


# check command-line parameters
pod2usage(
	-verbose => 2,
	-exitval => 3,
) if ($help || !$argvCnt);

pod2usage(
	-msg		=> "\n$0" . ' - version: ' . $version . "\n",
	-verbose	=> 1,
	-exitval	=> 3,
) if ($showVersion);

pod2usage(
	-msg		=> "\n" . 'No host specified!' . "\n",
	-verbose	=> 1,
	-exitval	=> 3
) if ($host eq '');

pod2usage(
	-msg		=> "\n" . 'No community specified!' . "\n",
	-verbose	=> 1,
	-exitval	=> 3
) if ($community eq '');


# set timeout
local $SIG{ALRM} = sub {
	print 'check_fujitsu_primergy: UNKNOWN: Timeout' . "\n";
	exit(3);
};
alarm($timeout);


# connect to SNMP host
($main::session, $error) = Net::SNMP->session(
	Hostname	=> $host,
	Community	=> $community
);
printResultAndExit(3, "UNKNOWN", "Error: session(): $error") unless $main::session;


if (defined $optBlade) {
	my $bladestatus = getSNMPRequest($oidBladeStatusID);
	$exitVal = $BladeErrorMap{$bladestatus};
	$msg = "Global status is ";
	if ($exitVal == 0) {
		$msg .= "OK";
	} else {
		$msg .= "FAILURE";
	}
} else {
	# fetch ServerID
	$serverID = getSNMPRequest($oidServerID);
	# fetch global state
	$globalResult = getSNMPRequest($oidSysStat);
	
	#get Powerconsumption if enabled
	$powerConsumption = getSNMPRequest($oidpowerconsumption);
	if ($powerConsumption =~ m/(\d+)/) {
		$powerConsumption =~ m/>(\d+)</i;
		$powerConsumption = $1;
	} else {
		$powerConsumption = "N/A";
	}
	$perfdata .= ' PowerConsumption=' . $powerConsumption;
	$perfdata .= 'Watt' if ($powerConsumption ne "N/A") ;
	
	# set exit value
	if ($globalResult eq '1') {
		$exitVal = 0;
	} elsif ($globalResult eq '2') {
		$exitVal = 1;
	} elsif ($globalResult eq '3' || $globalResult eq '4') {
		$exitVal = 2;
	} else {
		$exitVal = 3;
	}
	
	
	# prepare subsystems to exclude
	$exclude =~ s/^\s*|\s$//g;
	$exclude =~ s/\s*,\s*/,/g;
	my @exclude_arr = split(',', $exclude);
	
	
	# get subsystem information
	$subsys_cnt = getSNMPRequest($oidSubSysCnt);
	my @msg_arr = ();
	
	for (my $x = 1; $x <= $subsys_cnt; $x++) {
	
		$result = getSNMPRequest($oidSubSys . '.3.' . $x);
	
		my $subsys_name = getSNMPRequest($oidSubSys . '.2.' . $x) if ($result ne '1');
	
		next if ((defined($subsys_name) && grep(/^$subsys_name$/, @exclude_arr)));
		next if ($result eq '5');
	
		if (defined($subsys_stati[$x]->{'displayname'})) {
			next if (grep(/^$subsys_stati[$x]->{'displayname'}$/, @exclude_arr));
			push(@msg_arr, $subsys_stati[$x]->{'displayname'} . '(' . $sysStat[$result] . ')');
		}
	
		if ($result > $globalResult) {
			if ($result eq '1') {
				$exitVal = 0 if (!$exitVal);
			} elsif ($result eq '2') {
				$exitVal = 1 if ($exitVal <= 1);
			} elsif ($result eq '3' || $globalResult eq '4') {
				$exitVal = 2 if ($exitVal <= 2);
			} else {
				$exitVal = 3 if ($exitVal <= 3);
			}
		}
	
		$error .= ' ' . $subsys_name . '(' . $sysStat[$result] . '),' if ($result ne '1');
	
	}
	
	$msg = "ID: " . $serverID . ' - ';
	$msg .= join(' - ', @msg_arr);
	
	chomp($msg);
	chop($error);
	
	
	
	$fresult = $main::session->get_entries( -columns => \@fanChecks );
	
	# store fetched data
	foreach my $snmpkey ( keys %{$fresult} ) {
		push(@fans, $1) if ($snmpkey =~ m/$oidEnvFanStatus.(\d+\.\d+)/);
	}
	
	# sort fetched data
	@fans = Net::SNMP::oid_lex_sort(@fans);
	foreach $fanID (@fans) {
	
		$fanPurpose = $$fresult{$oidEnvFanPurpose . '.' . $fanID};
		$fanStatus  = $$fresult{$oidEnvFanStatus . '.' . $fanID};
		next if ($fanStatus eq '99' or $fanStatus eq '2' or $fanStatus eq '8');
	
		$fanSpeed = $$fresult{$oidEnvFanSpeed . '.' . $fanID};
	
		$perfdata .= ' ' . $fanPurpose[$fanPurpose] . $fanID . '=' . $fanSpeed . 'rpm';
		$fan_msg .= "\n" . $fanStatus[$fanStatus] . ': '. $fanPurpose[$fanPurpose] . ' (' . $fanSpeed . 'rpm),';
	
		if ($fanSpeed <= $fanCritical) {
			$exitVal = 2;
		} elsif ($fanSpeed <= $fanWarning) {
			$exitVal = 1 if ($exitVal != 2);
		}
	}
	
	# now check the temperatures
	
	$tresult = $main::session->get_entries( -columns => \@tempChecks );
	
	# store fetched data
	foreach my $snmpkey ( keys %{$tresult} ) {
		push(@temps, $1) if ($snmpkey =~ m/$oidEnvTempStatus.(\d+\.\d+)/);
	}
	
	# sort fetched data
	@temps = Net::SNMP::oid_lex_sort(@temps);
	foreach my $tempID (@temps) {
	
		my $tempStatus  = $$tresult{$oidEnvTempStatus . '.' . $tempID};
	
		next if ($tempStatus eq '99' or $tempStatus eq '2');
		my $tempValue = $$tresult{$oidEnvTempValue . '.' . $tempID};
		my $tempWarn = $$tresult{$oidEnvTempWarn . '.' . $tempID};
		my $tempCrit = $$tresult{$oidEnvTempCrit . '.' . $tempID};
		my $tempDesc = $$tresult{$oidEnvTempDesc . '.' . $tempID};
		$tempDesc =~ s/[ ,;=]/_/g;
	
		$perfdata .= ' ' . $tempDesc . '=' .$tempValue.'C;' . $tempWarn . ';' . $tempCrit .'';
		$temp_msg .= "\n". $tempStatus[$tempStatus] . ": $tempDesc is $tempValue C";
	
		if ($tempCrit > 0  and $tempValue >= $tempCrit) {
			$exitVal = 2;
		} elsif ($tempWarn > 0 and $tempValue >= $tempWarn) {
			$exitVal = 1 if ($exitVal != 2);
		} 
	}
}


# close SNMP session
$main::session->close;


# print check result and exit
printResultAndExit(
	$exitVal, 
	$state[$exitVal], 
	($main::verbose > 0) ? '' : (($error  ne '') ? ' -' . $error         : ''),
	($msg    ne '') ? $msg          : '',
	' |'. $perfdata,
	($main::verbose >= 2) ? $fan_msg . $temp_msg : ''
);

