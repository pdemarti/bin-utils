#!/usr/bin/perl

while(<>) {
s/(.*)/\| $1 \|/;
s/\|/\|\|/g if $.==1;
push @o,$_ unless $.==2;
}

for (@o) { print }

