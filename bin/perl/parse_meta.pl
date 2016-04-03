#!/usr/bin/perl
# 20101103 PD
# 20101202 PD: adding ctbID and company name
# looking for volume of reports per country,day
# 20111005 PD: options introduced, mostly to handle the stats mode (opt_s)
  
use XML::Parser;
use List::Util qw/min max/;
use Getopt::Std;
binmode STDOUT, ":encoding(utf8)";

sub err_usage {
  print STDERR "
Usage is:
$0 [OPTIONS] file_1 .. file_n
  -h:     help; print this and exit
  -c:     check consistency of IDs (using a Levenshtein to see if it's a name re-arrangement in case of discrepancy)
  -s:     print out stats instead of a csv file
  Note: the files can be in gzip formet (...xml.gz)
";
  exit @_;
}

err_usage(200) unless getopts('hcs');
err_usage(0) if $opt_h;

my $parser = new XML::Parser ( Handlers => { # Creates our parser object
					    Start   => \&hdl_start,
					    End     => \&hdl_end,
					    Char    => \&hdl_char,
					    Default => \&hdl_def,
					   });

for my $file (@ARGV) {
    open(F, $file=~/\.gz$/ ? "zcat $file|" : "<$file") || die "can't read $file: $!\n";
    while (<F>) {
	s/<\?xml[^<>]*\?>$//;
	next unless /</;
	$rec={};
	$parser->parse($_, ProtocolEncoding => 'UTF-8');
	if ($opt_s) {
	    for my $a (sort (keys %{$rec})) {
		my $n = 1;
		if (ref($rec->{$a}) eq 'HASH') {
		    for my $e (keys %{$rec->{$a}}) {
			my $nn = scalar(@{$rec->{$a}->{$e}});
			$n = $nn if $nn>$n;
		    }
		}
		printf("%-15s %3d %s\n", $a, $n, $file);
	    }
	} else {
	    print '"'.join('","',
			   # tags in the diDef section:
			   $rec->{arriveDate},
			   $rec->{releaseDate},
			   $rec->{submitDate},
			   $rec->{fetchDate},
			   $rec->{fileName},
			   $rec->{fileSize},
			   $rec->{docClass},
			   $rec->{docID},
			   $rec->{companyName},
			   $rec->{ctbID},
			   # other tags:
			   val($rec->{headline}->{_str}),
			   pa($rec->{author}->{c}),
			   pa($rec->{author}->{_str}),
			   pa($rec->{cntry}->{_str}),
			   pa($rec->{crncy}->{_str}),
			   PA($rec->{pTkr}->{prtID}),
			   PA($rec->{pTkr}->{_str}),
			   PA($rec->{tkr}->{prtID}),
			   PA($rec->{tkr}->{_str}),
			   PA($rec->{langDesc}->{lang}),
			   pa($rec->{ind}->{c}),
			   pa($rec->{ind}->{_str}),
			   pa($rec->{docTyp}->{c}),
			   pa($rec->{docTyp}->{_str}),
			   pa($rec->{subj}->{c}),
			   pa($rec->{subj}->{_str}),
			   #	       pa($rec->{'author.c'}),
			   #	       pa($rec->{author}),
			   #	       pa($rec->{cntry}),
			   #	       pa($rec->{crncy}),
			   #	       pa($rec->{lang}),
			   #	       pa($rec->{ind}),
			   #	       pa($rec->{docTyp}),
			  ),"\"\n";
	}
    }
    close F;
}

# returns the value of a one-cell array (given by reference). Croaks if the array doesn't contain exactly one value.
sub val {
    my @a = @{(shift)};
    warn "***** [WARN] not a one-cell array at line $." if scalar(@a) != 1;
    return join(';',@a);
}

# returns a "SQL array" string from an array given by reference.
# i.e.: pa(["a","b","c"]) --> "{a;b;c}"
sub pa { '{'.join(';',@{(shift)}).'}' }

# the uppercase version of pa()
sub PA { '{'.uc(join(';',@{(shift)})).'}' }

# The Handlers
sub hdl_start{
    my ($p, $elt, %atts) = @_;
#    print "elt='$elt',atts={",join(',',map {sprintf("'%s'->'%s'", $_, $atts{$_})} (keys %atts)),"}\n";
    if ($elt eq 'diDef') {
	$rec = \%atts;
    } else {
	for my $k (keys %atts) {
	    push @{$rec->{$elt}->{$k}},$atts{$k};
	}
	$atts{'_str'} = '';
	$activeatts{$elt} = \%atts;
    }
}

#	if ($elt eq 'author') {
#	push @{$rec->{$elt.".c"}},$atts{'c'};
#    } elsif ($celems{$elt}) {
#	push @{$rec->{$elt}},uc($atts{'c'});
#    } elsif ($elt eq 'langDesc') {
#	push @{$rec->{'lang'}},uc($atts{'lang'});
#    }
#    if ($selems{$elt}) {
#	$atts{'_str'} = '';
#	$activeatts{$elt} = \%atts;
#    }
#}

sub hdl_char {
    my ($p, $str) = @_;
    $str =~ s/;/./g;		# I decided for ';' as the separator for arrays. For simplicity, I won't let ';' be used in text.
    $str =~ s/\"+/\"\"/g;	# csv formatting: double-quotes to be escaped as two double-quotes
    for my $elt (keys %activeatts) {
	$activeatts{$elt}->{'_str'} .= $str;
    }
}

sub hdl_end{
    my ($p, $elt) = @_;
    if ($activeatts{$elt}) {
	my $str = $activeatts{$elt}->{'_str'};
	$str =~ s/^\s+//;
	$str =~ s/\s+$//;
	if ($opt_c && $ccheck{$elt}) {
	    # check if there is a code (ID) for that string, and if there is, if it is consistent with previous occurences (if any)
	    my $id = $activeatts{$elt}->{'c'};
	    if (defined($id) && $id ne '' && defined($code{$elt}->{$id}) && $str ne $code{$elt}->{$id}) {
		# different string associated with an ID
		# trying to see if it's just a re-arrangement of the name, or a completely different name
		# the algorithm is: in each string, remove punctuations,  re-arrange all words alphabetically, then measure the Levenshtein distance between the two
		my $a = join(' ', sort(split(/\W+/,lc($str))));
		my $b = join(' ', sort(split(/\W+/,lc($code{$elt}->{$id}))));
		my $d = levenshtein($a,$b);
		my $cost = 100*$d/max(length($a),length($b));
		warn "warning, line $.: $elt code $id is changing from to $code{$elt}->{$id} to $str; levenshtein('$a','$b'): $d; cost = $cost\n";
	    }
	    $code{$elt}->{$id} = $str;
	}
	# push the element in the array
	push @{$rec->{$elt}->{_str}},$str;
    }
    delete $activeatts{$elt};
}


sub hdl_def { }			# We just throw everything else

sub levenshtein {
    my ($s,$t) = @_;
    my $m = length($s);
    my $n = length($t);
    my @s = split(//,$s);
    my @t = split(//,$t);
    my $d = [];
    for my $i (0..$m) {
	$d->[$i]->[0] = $i; # deletion
    }
    for my $j (0..$n) {
	$d->[0]->[$j] = $j; # insertion
    }
    for my $j (1..$n) {
	for my $i (1..$m) {
	    if ($s[$i] eq $t[$j]) {
		$d->[$i]->[$j] = $d->[$i-1]->[$j-1];
	    } else {
		$d->[$i]->[$j] = 1 + min
		  ($d->[$i-1]->[$j],  # deletion
		   $d->[$i]->[$j-1],  # insertion
		   $d->[$i-1]->[$j-1] # substitution
		  );
	    }
	}
    }
    return $d->[$m]->[$n];
}
