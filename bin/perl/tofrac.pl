#!/usr/bin/perl
#
# transform decimal numbers into fractions

use POSIX qw/floor/;

sub frac {
    my ($x,$y) = @_;
    return (1,0) if ($y < 1E-6);
    my $a = floor($x/$y);
    my ($y1,$x1) = frac($y,$x-$a*$y);
    return ($x1+$a*$y1, $y1);
}

# infrac(x,fractional) --> (a,b,c) meaning a+b/c where c is no greater than fractional
# for example, infrac(pi, 32) -->  (3,5,32)  ie 3+5/32
# but	       infrac(pi, 16) -->  (3,1,8)
sub infrac {
    my ($x,$c) = @_;
    my $sign = $x >= 0 ? 1 : -1;
    $x *= $sign;
    my $a = floor($x+0.00000001);
    my $b = floor(0.5+($x-$a)*$c);
    my ($b,$c) = frac($b,$c);
    my $r = $x - ($a+$b/$c);
    return ($sign*$a,$b,$c,$r);
}

# string version of above
sub infracs {
    return sprintf("%d+%d/%d", infrac(@_));
}


# use this for converting from decimal number to inch and fractions
my $number = qr/(?:\d*\.\d+|\d+)(?:[eE][+-]?\d+)?/;  # number regexp
while (<>) {
    chomp;
    s,(\d+)\s+(\d+/\d+),($1+$2),g;
    s/mm/\/25.4/g;
    print;
    $_ = eval($_);
    print "\t= $_";
    my @a = frac($_,1);
    printf("\t(= %d/%d)", $a[0], $a[1]);
    my $c = 1024;
    for $p (64,32,16,8) {
        next if $c <= $p;
	my $a,$b,$r; ($a,$b,$c,$r) = infrac($_, $p);
	print "\t= $a + $b/$c";
	printf(" (+%.4f)",$r) if ($r>0);
	printf(" (%.4f)",$r) if ($r<0);
    }
    print "\n";
}
