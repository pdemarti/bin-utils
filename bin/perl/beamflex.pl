#!/usr/bin/perl
# PD20080920
# figure the flexing of a beam

require POSIX;
use Getopt::Std;

my %opt_default =
  ('l' => '10ft',
   'w' => '200lbs',
   'e' => '207GPa',
   's' => 'ibeam',
   'a' => '2in',
   'b' => '4in',
   't' => '1/8in',
  );

our %opts = %opt_default;
our $VERSION = 1.0;

sub HELP_MESSAGE {
  print STDERR "
Usage: $0 [options]

  Compute the flexing of a beam supported at both ends and subject to a static weight
  at the center.

OPTIONS
  -l length: Specifies the length (default $opt_default{l})
  -w weight: Specifies the weight (default $opt_default{w})
  -e modulus: Modulus of elasticity in (default $opt_default{e} -- steel); note: 6063-T6 aluminum: 69GPa
  -s section_type: Type of section (rect: rectangular tubing, round:round tubing, ibeam: I-beam) (default: $opt_default{s})
  -a width: Width of the section (default $opt_default{a})
  -b height: Height of the section (default $opt_default{b})
  -t thickness: Thickness of section (default $opt_default{t}) -- note: for tubing, 0 means full bar, not tube
";
  exit;
}
HELP_MESSAGE() unless getopts('l:w:e:s:a:b:t:', \%opts);

my %IFunc =
  ('rect' => \&I_rect,
   'round' => \&I_round,
   'ibeam' => \&I_beam,
   );

my $number = qr/(?:\d*\.\d+|\d+)(?:[eE][+-]?\d+)?/;
sub mksa {
    local $_ = join(" ", @_);
    s,($number/$number),\($1\),g;
    s,([()&? ]),\\$1,g;
    $_ = `units $_`;
    chomp;
    s/\s*Definition:\s*//;
    return $_;
}

sub inUnits {
    local $_ = shift;
    my $unit = shift;
    s,($number/$number),\($1\),g;
    s,([()&? ]),\\$1,g;
#    print "line: units $_ $unit\n";
    $_ = `units $_ $unit`;
    s/\n[^\001]*//;
    s/\s*\*\s*//;
    return "$_ $unit";
}

sub surround_paren {
    return map { '('.$_.')' } @_;
}

sub is_zero {
    my $x = shift;
    return 1 if !defined($x) || $x =~ /^\s*[0.]*\s*$/;
    return 1 if mksa($x) =~ /^0\s/;
    return 0;
}

sub I_rect {
    my ($a,$b,$t) = surround_paren(@_);
    return mksa("($a*$b^3)/12") if is_zero($t);
    return mksa(I_rect($a,$b),'-',I_rect("$a-2*$t","$b-2*$t"));
}

# really oval...
sub I_round {
    my ($a,$b,$t) = surround_paren(@_);
    return mksa("(pi*$a*$b^3)/12") if is_zero($t);
    return mksa(I_rect($a,$b),'-',I_rect("$a-2*$t","$b-2*$t"));
}

for my $p (qw/a b t l w e/) {
    printf("%s: %8s --> %s\n", $p, $opts{$p}, mksa($opts{$p}));
}
my $I = &{$IFunc{$opts{s}}}($opts{a},$opts{b},$opts{t}),"\n";
printf("section: %s, I = %s = %s\n", $opts{s}, $I, inUnits($I, "in^4"));

my $y = mksa("(($opts{w})*force*($opts{l})^3)/(48*($opts{e})*($I))");
print "deflection: $y\t--> ",inUnits($y,"in"),"\n";
