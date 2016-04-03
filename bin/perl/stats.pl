#!/usr/bin/perl
#
# Computes typical statistics on each numerical column in stdin.

require "getopts.pl";

sub err_usage
  {
  print STDERR "
Usage is:
$0 [file]
";
  exit @_;
  }

if (!&Getopts('c')) {do err_usage(200);}

while (<>) {
    @a=split;
    for $i (0 .. $#a) {
	$min[$i] = $a[$i] if !defined($min[$i]) || $a[$i] < $min[$i];
	$max[$i] = $a[$i] if !defined($max[$i]) || $a[$i] > $max[$i];
        $sum[$i]+=$a[$i];
	$sumsq[$i] += $a[$i]**2;
    }
    $n++;
}

print "n:     ",join("\t", map { sprintf("%d", $n)} @min),"\n";
print "min:   ",join("\t", map { sprintf("%.3f", $_)} @min),"\n";
print "max:   ",join("\t", map { sprintf("%.3f", $_)} @max),"\n";
print "avg:   ",join("\t", map { sprintf("%.3f", $_/$n)} @sum),"\n";
print "stdev: ",join("\t", map { sprintf("%.3f", sqrt($sumsq[$_]/$n - ($sum[$_]/$n)**2))} (0..$#sum)),"\n";
print "sum:   ",join("\t", map { sprintf("%.3f", $_)} @sum),"\n";
