package BasicStat;

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
    $self->{n}     = 0;
    bless($self, $class);
    $self->clear();
    return $self;
}

sub clear() {
    my $self = shift;
    $self->{a}     = 0;
    $self->{q}     = 0;
    $self->{n}     = 0;
    $self->{max}   = undef;
    $self->{min}   = undef;
}

sub add {
    my $s = shift;
    $s->{min} = $s->{max} = $_[0] unless $s->{n} > 0;
    $s->{n} += scalar(@_);
    for my $x (@_) {
        $s->{q} += ($s->{n}-1)*($x-$s->{a})*($x-$s->{a})/$s->{n};
	$s->{a} += ($x-$s->{a})/$s->{n}; # reduces the rounding errors (see http://en.wikipedia.org/wiki/Standard_deviation)
	$s->{max} = $x if ($x > $s->{max});
	$s->{min} = $x if ($x < $s->{min});
    }
}
sub size {
    my $s = shift;
    return $s->{n};
}
sub sum {
    my $s = shift;
    return $s->{n}<=0 ? 0 : $s->{a}*$s->{n};
}
sub  mean {
    my $s = shift;
    return $s->{n}<=0 ? undef : $s->{a};
}

# return the sample variance (unbiased estimator)
sub var_sample {
    my $s = shift;
    return $s->{n}<=0 ? undef : $s->{q}/($s->{n}-1);
}
sub var {
    my $s = shift;
    return $s->{n}<=0 ? undef : $s->{q}/$s->{n};
}
sub stddev_sample {
    my $s = shift;
    return $s->{n}<=0 ? undef : sqrt($s->var_sample());
}
sub stddev {
    my $s = shift;
    return $s->{n}<=0 ? undef : sqrt($s->var());
}
sub min {
    my $s = shift;
    return $s->{n}<=0 ? undef : $s->{min};
}
sub max {
    my $s = shift;
    return $s->{n}<=0 ? undef : $s->{max};
}

1;
