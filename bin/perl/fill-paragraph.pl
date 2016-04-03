#!/usr/bin/perl
#
# This implements a slightly different version of Emacs' fill-paragraph.
# It is more suited to my own needs.
#
# P. Demartines <pierred@lexicus.mot.com> 10-Nov-1997
#
# padspace -- return an array of spaces to pad a string with
#
#       padspace($n,$m) returns an array of $n padding spaces, the total
#       length of which is $m ($m > $n). The respective length of each
#       padding space is balanced throughout the array.
#
#	Example:
#
#	    padspace(3,4) gives (' ', '  ', ' ')    (1,2,1 spaces).
#
#       This is based on a resampling algorithm loosely inspired by
#       Bresenham's algorithm for drawing lines on a discrete raster.
#----------------------------------------------------------------------

use Getopt::Std;

sub padspace {
    local($nd,$ns) = @_;
    local($spc,$loops,$ds,$e,$de,@res);
    $loops = $nd;
    if ($loops < 1) {
	return @res;
    }
    $ds = int($ns/$nd);
    $ns = $ns*2;
    $e = $ns - $nd;
    $nd = $nd*2;
    $de = $ds*$nd;
    while ($loops--) {
	$spc = ' 'x$ds;
        $e -= $de;
        if ($e >= 0) {
            $spc .= ' ';
            $e -= $nd;
        }
        $e += $ns;
    push(@res, $spc);
    }
    return @res;
}


#----------------------------------------------------------------------
sub printpar {
    if ($par) {
	# print paragraph
	$max = $opt_w - length($nextprefix);
	$maxm1 = $max - 1;
	while ($par =~ s/^(.{1,$maxm1}(\S(?=\s|\Z)|-)|\S+)\s*//) {
	    $line = $1;
	    if ($opt_j && $par =~ /\S/ && ($n = ($line =~ s/\s+/¤/g))) {
		# justify
		$m = $n + $max - length($line);
		@padding = &padspace($n,$m);
		$line =~ s/¤/shift(@padding)/ge;
	    }
	    push(@par,$line);
	}
	print $firstprefix;
	print join("\n$nextprefix", @par);
	print "\n";
	undef $par;
	undef @par;
    }
}


#------------------------------------------------------------------------------
sub err_usage {
    ($prgm = $0) =~ s,.*/,,;
    print STDERR "
Usage is: $prgm [-h][-j|-c][-w width] [file]
     -c:       Centered justification (doesn't break lines).
     -j:       Left and Right justification (as opposed to just Left)
     -w width: Maximum desired width.
     -h:       Help.
";
    exit @_;
}


#----------------------------------------------------------------------
# main

$opt_w = 72;	# width
$opt_j = 0;	# LR justify

err_usage(200) unless getopts('hcjw:');
err_usage(0) if $opt_h;
err_usage(200) if $#ARGV > 1 || ($opt_j && $opt_c);

if ($opt_c) {
    # Center the text, don't break lines
    # Note: you can always break the lines first with no -c or -j option,
    # and then pipe the output through this program again with -c
    while (<>) {
	s/^\s*//;
	s/\s*$//;
	if (($l = length) < $opt_w) {
	    print ' ' x int(($opt_w-$l)/2);
	}
	print "$_\n";
    }
    exit 0;
}

$lookforpar = 1;
while (<>) {
    while (s/\t/" " x (8-(length($`) % 8))/e) {};	# tabs --> spaces (pretty cool eh?)
    s/ *$//;
    if (/^(\s*)(\/\*+|[\*\#%;!>]*)(\s*)$/) {
	# "empty" line --> paragraph break
	&printpar;
	print;
	$lookforpar = 1;
	next;
    }
    s/\n//;
    if ($lookforpar) {
	# the following regexp always matches
	s/^(\s*)(\/\*+|[\*\#%;!>]*)(\s*)((?:\d+(?:\.\d+)*[\)]?|[-+oO])\s+)?//;
	$sp1 = $1;
	$csc = $2;
	$sp2 = $3;
	$item = $4;
	$firstprefix = $sp1 . $csc . $sp2 . $item;
	if ($csc =~ s/^\/(?=\*)//) {$sp1 .= ' ';}
	if ($item ne "") {$sp2 .= ' ' x length($item);}
	$nextprefix = $sp1 . $csc . $sp2;
	$lookforpar = 0;
	$par = $_;
    } else {
	s/^\s*\Q$csc\E\s*//;
	$par .= ' ' unless $par =~ /-$/;
	$par .= $_;
    }
}
printpar;
1;
