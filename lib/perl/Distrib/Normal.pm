package Distrib::Normal;

use strict;
our $VERSION = '1.00';

=head1 NAME

Distrib::Normal -- Normal(0,1) variable random generator

=cut

#----------------------------------------------------------------------
# make new instance
#----------------------------------------------------------------------
sub new {
    my $class = shift;
    my $self;
    bless($self, $class);
    return $self;
}

sub nextValue {
    my $self = shift;
    my $v1;
    my $v2;
    my $s;
    do {
	$v1 = 2*rand()-1;
	$v2 = 2*rand()-1;
	$s = $v1*$v1 + $v2*$v2;
    } while ($s >= 1.0 || $s == 0.0);
  $s = sqrt(-2*log($s)/$s);
  return $v1*$s;
}

1;
