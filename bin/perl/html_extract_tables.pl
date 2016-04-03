#!/usr/bin/perl
# PD 20120224
# Given an html file, extract all the tables in it.
# The tables are printed out, with \t as column separator and \n as end of line.
# Each table is preceeded by the html <table ...> tag

undef $/;
while (<>) {
    s/\n//gm;
    s/\s+/ /gm;
    s/[\000-\007]//g;
    s/\s*<tr.*?>\s*/\001/gm;
    s/\s*<\/tr.*?>\s*/\002/gm;
    s/\s*<td.*?>\s*/\003/gm;
    s/\s*<\/td.*?>\s*/\004/gm;
    @a = m,(<table.+?)</table,gm;
    for (@a) {
	s/(<table.*?>)// && print "\n$1\n";
	@rows = split(/\002\001/, $_);
	for (@rows) {
	    @cols = split(/\004\003/, $_);
	    for (@cols) {
		s/[\000-\007]//g;
	    }
	    print join("\t", @cols),"\n";
	}
    }
}
