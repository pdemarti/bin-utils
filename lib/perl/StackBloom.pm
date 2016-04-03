package StackBloom;

our $VERSION = '1.00';

=head1 NAME

StackedBloom - A stacked version of Bloom filters.

=cut

require 5.000;
use Hash64;
use Bit::Vector;	# why did I even try to write bit ops in pure Perl?

#----------------------------------------------------------------------
# make new instance
#----------------------------------------------------------------------
sub new {
    my $class = shift;
    my $args = { @_ };
    my $self;
    $self->{m}     = $args->{m}     || 2**16;
    $self->{k}     = $args->{k}     || 1;
    $self->{lbits} = $args->{lbits} || 4;
    $self->{r}     = $args->{r}     || 0.5;

    # computed values (should move in an init function?)
    $self->{bitVector} = Bit::Vector->new($self->{m} * $self->{lbits});
    $self->{levels} = (1 << $self->{lbits});
    $self->{hargs} = [(1, map { $self->{m} } (1 .. $self->{k}))];
    $self->{m0} = [ map { $self->{m} } (1 .. $self->{levels}) ];
    bless($self, $class);
    return $self;
}

# use: sb->level($i) give the current level of bucket $i
#      sb->level($i, $j) change the level of bucket $i to max($jprior, $j) and returns $jprior
sub level {
    my $self = shift;
    my ($i,$j) = @_;
    $i *= $self->{lbits};
    my $jprior = $self->{bitVector}->Chunk_Read($self->{lbits}, $i);
    $self->{bitVector}->Chunk_Store($self->{lbits}, $i, $j) if defined($j) && $j > $jprior;
    return $jprior;
}


# use: sb->add(h64) --> returns 1 if item is added (if the bloom filter is modified as a result of the addition)
sub set {
    my $self = shift;
    my $h64 = shift;
    my ($h, @addr) = $h64->value(@{$self->{hargs}});
    # level
    my $j = $self->{levels};
    $j = 1+int(log($h)/log($self->{r})) if $h>0 && $r<1;	# level 0 means never seen before
    $j = $self->{levels}-1 if $j >= $self->{levels};
    my $minjprior = $self->{levels};
    for my $i (@addr) {
	my $jprior = $self->level($i, $j);
	for (my $j0 = $jprior+1; $j0 <= $j; $j0++) {
	    $self->{m0}->[$j0]--;
	}
	$minjprior = $jprior if $jprior < $minjprior;
    }
    return ($j > $minjprior) ? 1 : 0;	# true if at least one of the addresses was updated to the new level
}


# use: sb->contains(h64) --> returns true if the bloom filter thinks this h64 was added at some point
sub contains {
    my $self = shift;
    my $h64 = shift;
    my ($h, @addr) = $h64->value($self->{hargs});
    # level
    my $j = $self->{levels};
    $j = 1+int(log($h)/log($self->{r})) if $h>0 && $r<1;
    $j = $self->{levels}-1 if $j > $self->{levels};
    my $minjprior = $self->{levels};
    for my $i (@addr) {
	my $jprior = $self->level($i);
	$minjprior = $jprior if $jprior < $minjprior;
    }
    return ($j <= $minjprior);	# true if all buckets were at levels greater than or equal to $j
}


# return an estimate of how many unique items have been added
sub card {
    # TBD
}

# number of zero bits at each level
sub m0 {
    my $self = shift;
    return @{$self->{m0}};
}

1;
