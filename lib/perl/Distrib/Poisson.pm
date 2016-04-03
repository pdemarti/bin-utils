package Distrib::Poisson;

use strict;
our $VERSION = '1.00';

=head1 NAME

BasicStat - Provides super-simple stats (mean, variance, sample variance, etc.) on a series of scalars

=cut

#----------------------------------------------------------------------
# make new instance
#----------------------------------------------------------------------
sub new {
    my $class = shift;
    my $args = { @_ };
    my $self;
    $self->{lambda} = $args->{l} || $args->{lambda} || 1.0;
    bless($self, $class);
    return $self;
}

sub nextValue {
    my $self = shift;
    # algorithm poisson random number (Knuth):
    my $L = exp(-$self->{lambda});
    my $k = 0;
    my $p = 1.0;
    do {
	$k++;
        $p *= rand();
	} while $p >= $L;
    return $k-1;
}

1;
