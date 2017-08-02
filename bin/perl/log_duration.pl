#!/usr/bin/perl
#----------------------------------------------------------------------
# PD 20170801
# Compute the time difference between the last line and the first line
# of a log file (or several log files).
#----------------------------------------------------------------------

use Getopt::Std;
use Date::Parse qw/str2time/;
use POSIX qw/strftime/;

our $opt_e = qr/\d{4}-\d{2}-\d{2}[ T]\d\d:\d\d:\d\d/;

sub err_usage {
  print STDERR "
Usage is:
$0 [OPTIONS] [files...]
  -h:  help; print this and exit
  -v:  verbose: print first and last line to show where the time stamps come from.

Compute and display the time difference between the last line and the first line
of a log file (or several log files).
";
  exit @_;
}

err_usage(200) unless getopts('hv');
err_usage(0) if $opt_h;
#err_usage(200) unless defined($opt_c) && defined($opt_t);

while (<>) {
  if (/$opt_e/) {
    $ts = $&;
    $first_ts = $ts unless defined $first_ts;
  }
} continue {
  if (eof) {
    close ARGV;
    $t0 = str2time($first_ts);
    $t1 = str2time($ts);
    $dts = duration_str($t1 - $t0);
    if ($opt_v) {
      printf("%11s (%s .. %s): %s\n", $dts, $first_ts, $ts, $ARGV);
    } else {
      printf("%11s: %s\n", $dts, $ARGV);
    }
    $ts = $first_ts = undef;
  }
}

sub duration_str {
  my $remaining = shift;
  my $rdays = int($remaining / (24*3600));
  $remaining -= $rdays*24*3600;
  my $str = $rdays > 0 ? sprintf("%dd+", $rdays) : "";
  return sprintf("%s%s", $str, strftime("%H:%M:%S", gmtime($remaining)));
}
