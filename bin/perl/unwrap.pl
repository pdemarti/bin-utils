#!/usr/bin/perl
#----------------------------------------------------------------------
# PD 20120410
# Try to unwrap a text block that comes from copy/paste of a screen
# area, where multilines often end up all concatenated with white space
# to fake the returns.
#
# Example:
# kdbase=> select blah
# from xyz
# where foo='x'
# limit 10;
# comes as: "select blah<spaces>from xyz<spaces>..."
#
# The algorithm assumes that the whole block is made of:
# n lines of width w chars, with the first line having the first a chars
# skipped (not copied; something like the prompts "kdbase=> ") and the last
# line (tail) has only t chars.
# n,w,a and t are unknown.
# a \in [0,12]
# w \in [80,200]
# t \in [1,w]
# find a combination of <n,w,a,t> that is legal (the chars on the right
# are all space) and that maximizes the white space area on the right.
#----------------------------------------------------------------------

sub eval_area {
    my ($line,$w,$a) = @_;
    my @seg = unwrap(@_);
    my $A = 0;
    for (@seg) {
	return length($line)*10 if length($_) >= $w; # no full line allowed
	my $leftspace = /^( *)/ ? length($1) : 0;
	$A += $leftspace;
    }
    return $A;
}

sub unwrap {
    my ($line,$w,$a) = @_;
    my $prefix = ' ' x $a;
    my @seg = unpack("(A$w)*", $prefix.$line);
    substr($seg[0],0,$a) = '';
    return @seg;
}

while (<>) {
    chomp;
    my $best = {A=>length($_)};
    for my $a (0..12) {
	for my $w (100..200) {
	    my $A = eval_area($_,$w,$a);
	    if ($A < $best->{A}) {
		$best = {A=>$A, a=>$a, w=>$w};
	    }
	}
    }
    $A = $best->{A};
    $w = $best->{w};
    $a = $best->{a};
    print "best solution: a=$a, w=$w, A=$A\n";
    print join("\n", unwrap($_,$w,$a)),"\n";
}
