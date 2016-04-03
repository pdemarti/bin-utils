#!/usr/bin/perl
#
# Calc the mean (adapted from add.pl)

while (<>) {
    while (s/\b[-]?(\d+\.?\d*|\.\d+)([eE][-]?\d+)?\b//) {
	$sum += $&; $n++;
    }
}

print $sum/$n, "\n";
