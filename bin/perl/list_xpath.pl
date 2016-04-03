#!/bin/env perl

use strict;

use XML::LibXML qw( XML_ELEMENT_NODE );
use Statistics::TopK;
use List::Util qw(max);
use Data::Dumper;

my $parser = XML::LibXML->new();
my $topk = ();
my %n;

# keep track of usage and top-k content for an xpath with a value (terminal node or attribute)
sub account {
    my ($xpath,$value) = @_;
    $n{$xpath}++;
    $topk->{$xpath} = Statistics::TopK->new(20) unless defined($topk->{$xpath});
    $value = '\N' unless defined($value);
    $topk->{$xpath}->add($value);
}

sub visit {
    my $node = shift;
    my @path = @_;
    push @path, $node->nodeName();
    my $ppath = join("/", @path);

    my @children = grep $_->nodeType() == XML_ELEMENT_NODE, $node->childNodes();
    my @attr = $node->getAttributes();
    for my $attr (@attr) {
	account("$ppath/@".$attr->getName(), $attr->getValue());
    }
    unless (@children) {
	account($ppath, $node->textContent());
    }
    if (@children and $node->nodeValue()) {
	warn "\n\n*************** NODE $ppath has children and a value = ".$node->nodeValue()."\n\n\n";
    }

    visit($children[$_], @path)
      for 0..$#children;
}

sub proc {
    my $str  = shift;
    return unless $str;
    my $doc  = $parser->parse_string($str);
    my $root = $doc->documentElement();
    visit($root);
}

my $part_no = 0;
my $str;
my $nseg = 0;
while (<>) {
    if (/^<\?xml /) {
	#last if $nseg++ > 10;
	proc($str);
	$str = undef;
    }
    $str .= $_;
}
proc($str);

my $mlen = max(map { length } (keys %n));
for my $xpath (sort (keys %n)) {
    my $tot = $n{$xpath};
    my $tk = $topk->{$xpath};
    my %counts = $topk->{$xpath}->counts();
    my @k = sort {$counts{b} <=> $counts{a}} (grep { $counts{$_} > $tot/5 } (keys %counts));
    @k = max (keys %counts) unless @k;
    my @kv = map { sprintf("'%s' (%.0f%%)", $_, 100.0*$counts{$_}/$tot) } @k;
    #splice(@kv, 3, -1);
    printf("%8d %-${mlen}s [%s]\n", $n{$xpath}, $xpath, join(", ", @kv));
}
