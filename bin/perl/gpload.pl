#!/usr/bin/perl
# PD 20111018: start

use Digest::MD5 qw/md5_hex/;
use Getopt::Std;
binmode STDOUT, ":encoding(utf8)";

our $opt_f;
our $opt_n = $ENV{GP_SEGMENT_COUNT} || 1;
our $opt_i = $ENV{GP_SEGMENT_ID} || 0;

sub err_usage {
  print STDERR "
Usage is:
$0 [OPTIONS] path_glob [path_glob2 path_glob3...]
  -h:     help; print this and exit
  -f o,l: if defined, then make a first field based on the filename, as follow:
          split the path on / and take the elements from position o for length l.
          See splice in perlfunc for how negative indices are dealt with.
  -n n:   we are one of n instances, so process every 1/n file; default: $opt_n
  -i i:   we are instance No i (out of n); default: $opt_i
  -s:     skip headers (i.e. skip the first row of each file)
  -d:     debug mode: only spit out i n file_name
  Note: the files can be .csv or .csv.gz; they must all have the same number of columns
";
  exit @_;
}

err_usage(200) unless getopts('hf:n:i:sd');
err_usage(0) if $opt_h;

sub hashMod {
  my ($text, $n) = @_;
  my @a = unpack('L*', pack('H2'x16, unpack('A2'x16, md5_hex($text))));
  return $a[0] % $n;
}

my ($a,$b) = split(/,/, $opt_f, 2);
for my $g (@ARGV) {
    for my $f (glob $g) {
	next unless hashMod($f,$opt_n) == $opt_i;
	my $pf = $f;
	if ($opt_f) {
	    my @a=split(/\//, $f);
	    $pf = join('', (splice(@a,$a,$b)));
	}
	if ($opt_d) {
	    printf("%d %d %s\n", $opt_i, $opt_n, $f);
	} else {
	    open(F, ($f=~/.gz$/ ? "zcat $f|" : $f)) || die "can't open $f:$!\n";
	    while (<F>) {
		s/\000//g;
		s/\r/\\r/g;
		next if ($opt_s && $. == 1);
		print "$pf\t" if ($opt_f);
		print;
	    }
	    close F;
	}
    }
}
