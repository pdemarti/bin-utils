package Hash64;

our $VERSION = '1.00';

=head1 NAME

Hash64 -- Pure-perl implementation of Fowler/Noll/Vo hash on 64 bits.

=cut

require 5.000;

use constant FNV_64_INIT  => 0xcbf29ce484222325;
use constant FNV_64_PRIME => 0x100000001b3;
use constant MAX_64       => 0xFFFFFFFFFFFFFFFF;
use constant MAX_32       => 0xFFFFFFFF;
use constant INVMAX_64	  => 1.0/MAX_64;

#----------------------------------------------------------------------
# make new instance
#----------------------------------------------------------------------
sub new {
    my $class = shift;
    my ($args) = @_;
    $self->{value} = $args->{initial} || FNV_64_INIT;
    bless($self, $class);
    return $self;
}

# add an array of bytes to the item, update and return the hash value
sub add {
    my $self = shift;
    my $str = shift;
    my $hval = $self->{value};
    for my $c (unpack('c*', $str)) {
	use integer;
	$hval = ($hval*FNV_64_PRIME) & MAX_64;
	$hval ^= $c;
    }
    return $self->{value} = $hval;
}

# given $a: unsigned 64 bits and $b: unsigned 32 bits,
# return ($q, $r) where $q = floor $a/$b on 64 bits and $r: remainder on 32 bits
sub _div {
      use integer;
      my ($x,$y) = @_;
      $xlo = $x & MAX_32;
      $xhi = ($x >> 32) & MAX_32;

      # Knuth 4.3.1 exercise 16 (Vol. 2 p. 625)
      $qhi = $xhi / $y;
      $r = $xhi % $y;
      $qlo = (($r << 32) + $xlo)/$y;
      $r = (($r << 32) + $xlo) % $y;
      $q = ($qhi << 32) + $qlo;
      return ($q,$r);
}

# return an array @h of values based on the current hash and an
# array @m of values;
# h[0] is hash(item) % m[0]
# h[1] is hash(item.'\001') % m[1]
# h[2] is hash(item.'\001\001') % m[2]
# etc.
# if m[i] == 0, then the pure hash is returned
# if m[i] <= 1.0, then the hash value is mapped to (0..m[i]( (i.e. h*m[i]/MAX_64)
# otherwise, h % m[i] is returned
# EXAMPLE:
# $x->value(128, 1.0) returns two pseudo-independent hashes (h1,h2).
# h1 is the current hash value % 128, suitable for use as a bit address, for instance.
# h2 is a double between 0 and 1, suitable for use as filtering against a sampling rate
sub value {
    my $self = shift;
    my @m = @_;
    if (@m == 0) {
	# no m value passed, simply return the current value
	return $self->{value};
    } else {
	my @h = ();
	my $hval = $self->{value};
	while (@m) {
	    my $m = shift @m;
	    my $h;
	    if ($m <= 0) {
		$h = $hval;
	    } elsif ($m <= 1) {
		{
		    use integer;
		    $hlo = $hval & MAX_32;
		    $hhi = ($hval >> 32) & MAX_32;
		}
		$h = $m*(($hhi+(($hlo+1)/MAX_32))/MAX_32);
	    } else {
		my $q;
		($q,$h) = _div($hval,$m);
	    }
	    push @h, $h;
	    if (scalar @m > 0) {
		# more values to generate, let's disperse hval
		use integer;
		$hval = ($hval*FNV_64_PRIME) & MAX_64;
		$hval ^= 1;
	    }
	}
	return @h;
    }
}

1;
