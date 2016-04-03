#!/usr/bin/perl
use Time::HiRes qw ( time );
use Getopt::Std;

our $opt_t = 60;
our $opt_s = 1024;

sub err_usage {
  print STDERR "
Usage is:
$0 -i file|-o file
  -h:         help; print this and exit
  -i file:    read test using file
  -o file:    write test using file
  -s size:    packet size (default $opt_s bytes)
  -t time:    time for the write test (ignored if -i). Default $opt_t seconds.
";
  exit @_;
}

err_usage(200) unless getopts('ho:i:t:s:') && (defined($opt_i) || defined($opt_o));
err_usage(0) if $opt_h;

$invMB = 1.0/1024/1024;
$delta = 2;

$t0 = $pt1 = time;
$tnext = $t0+$delta;
$tend = $t0+$opt_t;
$n = 0;
$dn = 0;

$|=1;
$opt_s = 2*int(($opt_s+1)/2);
$s = $opt_s/2-1;

if ($opt_o) {
    $a = ord('A');
    open(O, ">$opt_o") || die "can't write to $opt_o: $!\n";
    # just write a bunch of lines to a file, and measure how fast it goes

    do {
	#    print join('',map {chr(int(rand(25))+$a)} (1..1023)),"\n";
	print O '01' x $s,"0\n";
	$dn += $opt_s;
	$t1 = time;
	if ($t1 > $tnext) {
	    $n += $dn;
	    printf "%.3fMB written in %.3f s: %.3fMB/s;  overall: ",$dn*$invMB,$t1-$pt1,$dn*$invMB/($t1-$pt1);
	    printf "%.3fMB written in %.3f s: %.3fMB/s\n",$n*$invMB,$t1-$t0,$n*$invMB/($t1-$t0);
	    $tnext += $delta;
	    $dn = 0;
	    $pt1 = $t1;
	}
    } while ($tnext < $tend);
    close(O);
}

if ($opt_i) {
    open(I, "$opt_i") || die "can't open $opt_i: $!\n";
    $|=1;
    while (<I>) {
	$dn += length($_);
	$t1 = time;
	if ($t1 > $tnext || eof) {
	    $n += $dn;
	    printf "%.3fMB read in %.3f s: %.3fMB/s;  overall: ",$dn*$invMB,$t1-$pt1,$dn*$invMB/($t1-$pt1);
	    printf "%.3fMB read in %.3f s: %.3fMB/s\n",$n*$invMB,$t1-$t0,$n*$invMB/($t1-$t0);
	    $tnext += $delta;
	    $dn = 0;
	    $pt1 = $t1;
	}
    }
    close(I);
}
