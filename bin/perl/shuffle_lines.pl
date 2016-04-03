#!/usr/bin/perl
#
# Shuffle the lines of a file in a random order.
# The file can be as big (or almost) as the /tmp free space.
#
# P. Demartines <pierred@lexicus.mot.com> June 1997

# new version splitting the stuff in many files...
$n = 50;
$prefix = "/tmp/shuffle" . $$ ."_"; 
srand;
while (<>) {
    $num = int(rand($n));
    $fname = $prefix . $num;
    if (! $opened{$fname}) {
	open($fname, "+>$fname") ||
	    die "Can't open $fname";
	$opened{$fname} = 1;
    }
    print $fname $_;
}

foreach $fname (keys %opened) {
    seek($fname, 0, 0);
    while (<$fname>) {$a{rand(1).rand(10)} = $_}
    while (($key,$val) = each %a) {print $val;}
    undef %a;
    close($fname);
    unlink $fname;
}

# old version that was requiring a lot of memory
# $| = 1;
# srand;
# while (<>) {$a{rand(1).rand(10)} = $_}
# print join("", values(%a));
