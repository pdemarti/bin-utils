#----------------------------------------------------------------------
# Copyright 2001 - 2003 AirTx.
#
# AirTx Confidential and Proprietary. Patent pending.
# Do not distribute. Reverse engineering prohibited.
#----------------------------------------------------------------------
# PD 26-Apr-03
#
# Package to compute a "good" multi-word code to encode objects present
# with various frequencies
#----------------------------------------------------------------------
#
# Typical usage
# -------------
#
# $count{$value} : number of occurences of that value;
# $index{$value} : desired index for that value;
#
# Normally, index 0 should be for the most frequent value, index 1 for
# the next most frequent, etc. It is left here to the caller to
# calculate, because when computing a "Golomb numeric" (encoding of
# nonnegative integers), then the index is equal to the value (so that
# no storage of the values table is necessary).
#
# For a tabulated Golomb (each value needs to be stored in a table),
# then the optimal index is calculated as:
# my $k = 0;
# my %index = map { $_ => $k++ } (sort {$count{$b} <=> $count{$a}} (keys %count));
#
# Then,
# my golomb = Golomb::new;
# golomb->init(\%count, \%index);
# golomb->optimize;
#
# After that, the following methods are available:
#
# $totSize = golomb->size;		# total size in bits to represent all objects
# $bitStr  = golomb->encode($index);	# encode $index into a bitstring
# $index   = golomb->decode($bitstr)	# decode a bitstring back to the original index
# @codeKey = golomb->codeKey		# gives the array of keys for that Golomb
#----------------------------------------------------------------------


package Golomb;

use POSIX;
use strict;

#----------------------------------------------------------------------
# makes a bit string from an integer (no compression)
#----------------------------------------------------------------------
sub bits {
    my ($size, $value) = @_;
    my @bits = split(//, unpack("B*", pack("N", $value)));
    my @ret = splice(@bits, -$size);
    @ret = () if ($size == 0);
    return wantarray ? @ret : join("", @ret);
}


#----------------------------------------------------------------------
# make new instance
#----------------------------------------------------------------------
sub new {
    my $class = shift;
    my $self =
      {codeKey	=> [()],	# array of bit widths for this Golomb code
       cumulCount => [()],	# cumulative counts
       index	  => {()},	# mapping from symbol to index
       totalCount => 0,
      };
    bless($self, $class);
    return $self;
}


#----------------------------------------------------------------------
# shortcut: make new instance, compute cumulative count, optimize
# Usages:
#   my $g = Golomb->make(\%count)
#   my $g = Golomb->make(\%count, numeric => 1)
#----------------------------------------------------------------------
sub make {
    my $class = shift;
    my $pcount = shift;
    my %opt = @_;
    my $self = new $class;
    my $k = 0;
    my %index;
    if ($opt{numeric}) {
	# not implemented yet
	return 0;
    } else {
	%index = map { $_ => $k++ } (sort {$pcount->{$b} <=> $pcount->{$a}} (keys %{$pcount}));
    }
    $self->init($pcount, \%index);
    $self->optimize;
    return $self;
}


#----------------------------------------------------------------------
# Returns the codeKey
#----------------------------------------------------------------------
sub codeKey {$_[0]->{codeKey}}


#----------------------------------------------------------------------
# Returns the number of objects that can be represented with that
# codeKey  (NMax = Sum_1^n (2^a_i - 1) + 1)
#----------------------------------------------------------------------
sub NMax {
    my ($self) = @_;
    my $N = 1;
    for my $bits (@{$self->{codeKey}}) {
	$N += 2**$bits - 1;
    }
    return $N;
}


#----------------------------------------------------------------------
# Initialization
# Computes:  $totalCount, @cumulCount, $maxIndex
#----------------------------------------------------------------------
sub init {
    my ($self, $count, $index) = @_;
    my $tc = 0;
    my @cc = ();
    my $max = 0;
    for my $value (keys %{$index}) {
	my $ix = $index->{$value};
	$cc[$ix] = $count->{$value};
	$max = $ix if $ix > $max;
    }
    for my $ix (0 .. $max) {
	$tc += $cc[$ix];
	$cc[$ix] = $tc;
    }
    $self->{totalCount} = $tc;
    $self->{cumulCount} = [ @cc ];
    $self->{maxIndex} = $max;
    $self->{index} = { %{$index} };	# make our own copy of the index map
}


#----------------------------------------------------------------------
# evaluate a code key
# (compute the size and store the bits used)
#----------------------------------------------------------------------
sub evaluate {
    my ($self, @bits) = @_;	# array of number_bits
    my $total_size = 0;
    my $high = -1;		# object with highest address for this seg
    my $nbits = 0;
    my @bused = ();             # array of #bits, normally = @bits,
                                # except sometimes for the last one, if
                                # not all those bits were necessary
    push(@bits,24);             # last element: to give enough room to
				# finish the representation, no matter what
    my $maxi = $self->{maxIndex};
    my $lastCumul = 0;
    foreach my $b (@bits) {
        # for each segment, we compute $high = address of the last object
        # represented by numbers in this segment. This is equal to the
        # $high of the previous segment, plus 2^$b (with $b the #bits
        # for that segment). Then, we just calculate how many bits all
        # these addresses will take in the final representation (given
        # the count of each object --actually given in an alternative
        # form: the cumulative count, which makes the calculation
        # faster).
	my $nitemleft = $maxi - $high;
	last if ($nitemleft < 2);
	my $bb = POSIX::ceil(log($nitemleft)/log(2));
	$b = $bb if ($bb < $b);
	push(@bused, $b);
	$nbits += $b;
	my $n = 2**$b - 1;
	$n = $nitemleft if ($nitemleft <= $n+1);
	$high += $n;
	my $size = $nbits*($self->{cumulCount}->[$high] - $lastCumul);
	$lastCumul = $self->{cumulCount}->[$high];
	$total_size += $size;
    }
    return ($total_size, @bused);
}


#----------------------------------------------------------------------
# Search for an optimal code to represent the indices given their
# cumulative count
#
# Return the hypothetical total size in bits
#----------------------------------------------------------------------
sub optimize {
    my ($self) = @_;
    my $maxbit = POSIX::ceil(log(scalar(@{$self->{cumulCount}}))/log(2));
    my $best = ($maxbit+1)*($self->{totalCount}+1);
    my $positions = 5;
    my $i;
    my @bits = split(//, "1" x $positions);
    while ($bits[0] <= $maxbit) {
	my ($total_size, @bused) = $self->evaluate(@bits);
	if ($total_size < $best) {
	    #print STDERR "*** bits used: " . join(',',@bused) . "  total size = " . $total_size . " bits (". POSIX::ceil($total_size/8) . " bytes)\n";
	    $best = $total_size;
	    $self->{codeKey} = [@bused];
	}
	for ($i = $#bused-1; $i >= 0; $i--) {
	    $bits[$i]++;
	    last if ($bits[$i] <= $maxbit);
	}
	last if $i < 0;
	splice(@bits, $i+1, $positions, split(//, "1" x ($positions-$i-2)));
    }
    return $best;
}


#----------------------------------------------------------------------
# Encode a symbol
#----------------------------------------------------------------------
sub encode {
    my ($self, $symbol) = @_;
    my @bits = @{$self->{codeKey}};		# array of #bits (segment sizes)
    my $code = "";
    my $index = $self->{index}->{$symbol};
    return $index unless defined($index);	# undef is returned if symbol not found
    foreach my $b (@bits) {
	my $n = 2**$b - 1;
	if ($index < $n) {
	    $code .= bits($b, $index);
	    last;
	}
	$code .= '1' x $b;
	$index -= $n;
    }
    return $code;
}
1;
