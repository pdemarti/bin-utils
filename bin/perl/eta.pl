#!/usr/bin/perl
#----------------------------------------------------------------------
# PD 20120323
# usage (example):  eta.pl -c 'du -s .' -t 99366500
# tells that we are waiting for 'du -sb .' to give 99366500.
# i.e. for the current dir to be filled by some other process (e.g.
# rsync) up to a total of 99366500 bytes
#----------------------------------------------------------------------

use Getopt::Std;

our $opt_c;
our $opt_t;
our $opt_s = 2;
our $opt_u = "bytes";
our $opt_k = 100;
our $opt_f = undef;

sub err_usage {
  print STDERR "
Usage is:
$0 -c 'command' -t 'target_value' [OPTIONS]
  -h:       help; print this and exit
  -c cmd:   command to watch; the command must return a numerical value.
  -f field: split the output and take the nth field (like cut -f n, except that the split is done the perl way)
  -t x:     target value to reach
  -u unit:  what unit is the value expressed in (only for printing); default: $opt_u
  -s sleep: seconds to sleep between running the command again; default: $opt_s
  -k th:    if the difference to the target is less than this threshold, then exit; default $opt_k
";
  exit @_;
}

err_usage(200) unless getopts('hc:f:t:u:s:k:');
err_usage(0) if $opt_h;
err_usage(200) unless defined($opt_c) && defined($opt_t);

$t0=time;
$_ = qx{$opt_c};
$_ = (split)[$opt_f-1] if ($opt_f);
$s0=$_;
while (1) {
    sleep($opt_s);
    $t=time;
    $_ = qx{$opt_c};
    $_ = (split)[$opt_f-1] if ($opt_f);
    $s=$_;
    $rate=1.0*($s-$s0)/($t-$t0);
    printf("%d %s\t%s\t+%d in %s sec: %.3f %s/sec, ETA=%s\n",
	   $s, $opt_u, scalar(localtime($t)),
	   $s-$s0, $t-$t0,
	   $rate, $opt_u,
	   scalar(localtime($t+($opt_t-$s)/$rate)));
    exit(0) if ($opt_t-$s < $opt_k);
}
