#!/usr/bin/perl

my $missing_value = 0;

while (<>) {
    s/^\s+//; s/\s+$//;
    chomp;
    @a=split(/\s*\|\s*/);
    if ($.==1) {
	# header
	print "# ",join(", ", map { sprintf("%d:%s", $_,$a[$_]) } (0..$#a)),"\n";
	$fields = scalar(@a);
    }
    next if $. < 3 || /^\(\d+\s+rows\)/ || /^$/;
    for (@a[0..$fields-1]) {
	$_ = $missing_value unless /./;
    }
    print join(",", @a),"\n";
}
