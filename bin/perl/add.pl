#!/usr/bin/perl
#
# Sum up everything that looks like a number in stdin.
# P. Demartines <pierred@lexicus.mot.com> 26-Sep-1997
# PD 15-Jan-01 modified for -c option (cumul)

require "getopts.pl";

sub err_usage
  {
  print STDERR "
Usage is:
$0 [-c] [file]
    -c: cumulate. This prints out the cumul of numbers as we find them when
        going through the file, rather than just showing the final sum.
";
  exit @_;
  }

if (!&Getopts('c')) {do err_usage(200);}

while (<>) {
    @sumFoundOnThisLine = () if ($opt_c);
    while (s/\b[-]?(\d+\.?\d*|\.\d+)([eE][-]?\d+)?\b//) {
	$sum += $&;
	push(@sumFoundOnThisLine, $sum) if ($opt_c);
    }
    if ($opt_c) {
	print join(" ", @sumFoundOnThisLine) . "\n";
    }
}

print "$sum\n" unless ($opt_c);
