#! /usr/bin/perl -w
###################################################################
# Oreon is developped with GPL Licence 2.0 
#
# GPL License: http://www.gnu.org/licenses/gpl.txt
#
# Developped by : Julien Mathis - Romain Le Merlus 
#                 Christophe Coraboeuf
#
###################################################################
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
#    For information : contact@merethis.com
####################################################################
#
# Script init
#

use strict;
use FindBin;
use lib "$FindBin::Bin";
use lib "@NAGIOS_PLUGINS@";
use utils qw($TIMEOUT %ERRORS &print_revision &support);

use vars qw($PROGNAME);
use Getopt::Long;
use vars qw($opt_V $opt_h $opt_H $opt_D $opt_w $opt_c $opt_n $rta_critical $rta_warning $pl_critical $pl_warning $opt_s);

# Plugin var init

my $ping = `whereis -b ping`;
$ping =~ /^.*:\s(.*)$/;
$ping = $1;

$PROGNAME = "check_graph_ping";
sub print_help ();
sub print_usage ();

Getopt::Long::Configure('bundling');
GetOptions
    ("h" => \$opt_h,		"help" => \$opt_h,
     "V" => \$opt_V,		"version" => \$opt_V,
     "w=s" => \$opt_w,		"warning=s" => \$opt_w,
     "c=s" => \$opt_c,		"critical=s" => \$opt_c,
     "n=s" => \$opt_n,		"number=s" => \$opt_n,
     "H=s" => \$opt_H,		"hostname=s" => \$opt_H);

if ($opt_V) {
    print_revision($PROGNAME,'$Revision: 1.2 $');
    exit $ERRORS{'OK'};
}

if ($opt_h) {
    print_help();
    exit $ERRORS{'OK'};
}

$opt_H = shift unless ($opt_H);
(print_usage() && exit $ERRORS{'OK'}) unless ($opt_H);

($opt_c) || ($opt_c = shift) || ($opt_c = "500,40%");
if ($opt_c =~ /([0-9]+),([0-9]+)%/) {
    $rta_critical = $1;
    $pl_critical = $2;
}

($opt_w) || ($opt_w = shift) || ($opt_w = "200,20%");
if ($opt_w =~ /([0-9]+),([0-9]+)%/) {
    $rta_warning = $1;
    $pl_warning = $2;
}

if ( ($rta_critical <= $rta_warning) || ($pl_critical <= $pl_warning) ) {
    print "critical must be superior to warning\n";
    print_usage();
    exit $ERRORS{'OK'};
}

($opt_n) || ($opt_n = shift) || ($opt_n = 1);
my $NbPing;
if ($opt_n =~ /([0-9]+)/){
    $NbPing = $1;
} else{
    print "Unknown ping number\n";
    exit $ERRORS{'UNKNOWN'};
}

# Plugin requests

$_ = `$ping -n -c $NbPing $opt_H 2>/dev/null`;
my $return = $? / 256;

# Get Data From Ping Result

my $ping_result = $_;
my @ping_result_array = split(/\n/,$ping_result);
my @ping_subresult1_array;
my @ping_subresult2_array;
my $rta = 0;
my $pl;
my $time_answer;

if( ( $return != 0 ) || $ping_result_array[@ping_result_array -2 ] =~ /100% packet loss/) {
    $rta = -1;
    $time_answer = 0;
} else {
    @ping_subresult1_array = split(/=/,$ping_result_array[@ping_result_array -1 ]);
    @ping_subresult2_array = split(/,/,$ping_result_array[@ping_result_array -2 ]);
    @ping_subresult1_array = split(/\//,$ping_subresult1_array[1]);
    @ping_subresult2_array = split(/ /,$ping_subresult2_array[2]);
    $rta = $ping_subresult1_array[1];
    $pl = $ping_subresult2_array[1];
    $time_answer = $ping_subresult1_array[1];
    $pl =~ /([0-9]+)\%/;
    $pl = $1;
}

# Plugin return code

my $result_str = "";

if( $rta == -1 ) {
    $ping_result_array[@ping_result_array -2 ] =~ s/\%/percent/g; 
    print "GPING CRITICAL - ".$ping_result_array[@ping_result_array -2 ]."|time=0 ok=0\n";
    exit $ERRORS{'CRITICAL'};
} elsif ( ($pl >= $pl_critical) || ($rta >= $rta_critical) ) {
    $ping_result_array[@ping_result_array -1 ] =~ s/\%/percent/g;
    my @tab = split(/,/,$ping_result_array[@ping_result_array -1 ]);
    print "GPING CRITICAL - ". $tab[1] ."|time=".$time_answer."ms;$pl_warning;$pl_critical;; ok=1\n";
    exit $ERRORS{'CRITICAL'};
} elsif (($pl >= $pl_warning) || ($rta >= $rta_warning) ) {
    $ping_result_array[@ping_result_array -1 ] =~ s/\%/percent/g;
    my @tab = split(/,/,$ping_result_array[@ping_result_array -1 ]);
    print "GPING WARNING - ".$tab[0]."|time=".$time_answer."ms;$pl_warning;$pl_critical;; ok=1\n";
    exit $ERRORS{'WARNING'};
} else {
    $ping_result_array[@ping_result_array -1 ] =~ s/\%/percent/g;
    my @tab = split(/,/,$ping_result_array[@ping_result_array -1 ]);
    print "GPING OK - ".$tab[0]."|time=".$time_answer."ms;$pl_warning;$pl_critical;; ok=1\n";
    exit $ERRORS{'OK'};
}

sub print_usage () {
    print "Usage:\n";
    print "$PROGNAME\n";
    print "   -H (--hostname)   Hostname to query (Required)\n";
    print "   -g (--rrdgraph)   Create a rrd base if necessary and add datas into this one\n";
    print "   --rrd_step	Specifies the base interval in seconds with which data will be fed into the RRD (300 by default)\n";
    print "   -S (--ServiceId)  Oreon Service Id\n";
    print "   -w (--warning)    Threshold pair (Default: 200,20%)\n";
    print "   -c (--critical)   Threshold pair (Default: 500,40%)\n";
    print "   -n (--number)     number of ICMP ECHO packets to send (Default: 1)\n";
    print "   -V (--version)    Plugin version\n";
    print "   -h (--help)       usage help\n";
}

sub print_help () {
    print "######################################################\n";
    print "#      Copyright (c) 2004-2007 Oreon-project         #\n";
	print "#      Bugs to http://www.oreon-project.org/         #\n";
	print "######################################################\n";
    print_usage();
    print "\n";
}