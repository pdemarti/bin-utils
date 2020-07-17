#!/usr/bin/perl
#
# Sum up everything that looks like a number in stdin.
# P. Demartines <pierred@lexicus.mot.com> 26-Sep-1997
# PD 15-Jan-01 modified for -c option (cumul)

use Getopt::Std;

our $opt_c;
our $opt_k;
our $opt_v;

sub err_usage {
  print STDERR "
Usage is:
$0 [-c] [-k k] [-v] [file]
    -c: cumulate. This prints out the cumul of numbers as we find them when
        going through the file, rather than just showing the final sum.
    -k k: limit to only the first k numbers found on each line.
    -v: echo each line of the input file (implies -c)
";
  exit @_;
}

err_usage(200) unless getopts('hck:v');
err_usage(0) if $opt_h;

while (<>) {
    $line = $opt_v ? $_ : "\n";
    # remove comments
    s/\#.*//;
    @a = split(/([-]?(?:\d+\.?\d*|\.\d+)(?:[eE][-]?\d+)?)/);
    # take only the odd elements in the array (i.e.: the numbers)
    @a = @a[map 2*$_+1, 0..$#a/2];

    # limit to only first number (if any)
    splice @a, $opt_k if $opt_k;
    $sum += $_ for @a;

	print "$sum\t$line" if $opt_c || $opt_v;
}

print "$sum\n" unless $opt_c;
