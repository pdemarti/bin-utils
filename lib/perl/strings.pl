# strings.pl -- Some utilities for strings
#
# P. Demartines <pierred@lexicus.mot.com> 15-Nov-2000
#
# Example:
# perl -ne 'require "strings.pl"; print &str_union(split)."\n";'
# abc cde
# (returns abcde)

sub str_intersect {
    local ($_, $i, %a);
    for (@_) {
	foreach $c (split(//)) {
	    $a{$c}++ if ($a{$c} == $i);
	    # pretty nasty hack: at first, both $i and $a{$c} are undefined... so the == op yields true
	    # later on, $i becomes 1, 2, etc. and only the chars that were present in all the previous
	    # strings get a chance to continue to be selected
	}
	$i++;
    }
    $_ = "";
    foreach $c (sort (keys %a)) {
	$_ .= $c if ($a{$c} == $i);
    }
    return $_;
}

sub str_union {
    local ($_, %a);
    for (@_) {
	foreach $c (split(//)) {
	    $a{$c} = 1;
	}
    }
    $_ = "";
    foreach $c (sort (keys %a)) {
	$_ .= $c;
    }
    return $_;
}

1;
