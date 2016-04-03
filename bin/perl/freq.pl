#!/usr/bin/perl
#
# Compute token frequencies in a text.
# See the help in err_usage().
#
# PD 19970728 first version
# PD 20001207 modified for -l more
# PD 20030202 added -k option
# PD 20030426 renamed -w into -W
#		      added word (-w) option
#		      added sort numerically (-N) option
# PD 20130305 UTF-8 chars
# PD 20130305 implement a -B flag (for unicode Blocks) that looks at counts for each unicode block.
#
# Copyright 2007-2013 Pierre Demartines
# GNU General Public License, see http://www.gnu.org/licenses/gpl.txt

require "asciisymb.pl";
use Getopt::Std;

use open qw/:std :utf8/;

#binmode STDIN, ":encoding(utf8)";
#binmode STDOUT, ":encoding(utf8)";

sub err_usage {
  print STDERR "
Usage is:
$0 [options] [file]
Options:
    -r:   raw mode --don't skip comment lines
    -l:   line mode: entire lines are considered as a symbol, instead
          of being broken first in characters.
    -W:   word mode: words (anything between whitespaces or newline) are the symbols.
    -c:   like -l, but each input line has a count in the first field, one space, and
          the rest is considered to be the symbol (appearing 'count' times in the original
          file)
    -k k: cut at rank k, binning all other entries as 'other'
    -N:   Sort the symbols numerically
    -w:   the input is a count_word file, and the letter frequency is measured
    -n:   suppresses returns
    -s:   suppresses spaces
    -x:   every symbol that occurs only once is replaced by 'other'
    -t name: use 'name' instead of 'other' in -x and -k modes
    -T symbName: use 'symbName' for the header of symbols instead of 'symbol'
    -F fields: output only the fields specified. Default: 'rank,sum(P),P,sum(count),count,symbol'
    -B:   replace each character by the name of the Unicode block to which it belongs

  This program computes the frequency of symbols appearing in a file.
";
  exit @_;
}

err_usage(200) unless getopts('hlwck:NWnrsxt:F:T:B');
err_usage(0) if $opt_h;
$opt_t = "other" unless defined $opt_t;
$opt_T = "symbol" unless defined $opt_T;
$opt_F = "rank,sum(P),P,sum(count),count,$opt_T" unless defined $opt_F;

#use Data::Dump qw(dump);

my $columnDesc =
  {'rank'	=> {fmt=>"%d",	  value=>sub {$rank}},
   'sum(P)'	=> {fmt=>"%6.4f", value=>sub {$cumul/$n}},
   'P'		=> {fmt=>"%6.4f", value=>sub {$symbol{$c}/$n}},
   'sum(count)'	=> {fmt=>"%d",	  value=>sub {$cumul}},
   'count'	=> {fmt=>"%d",	  value=>sub {$symbol{$c}}},
   $opt_T	=> {fmt=>"%s",	  value=>sub {$c}}
  };
my @outCol = map {
    die "unknown column: '$_'" unless defined($columnDesc->{$_});
    +{%{$columnDesc->{$_}}, name => $_}
} split(/\s*,\s*/, $opt_F);

while (<>) {
    next if (! $opt_r) && /^\s*#/;
    if ($opt_w) {
	chop;
	s/\s*(\d+)\s// || die "bad input for mode -w at line $.\n";
	$count = $1;
	for (split(//, $_)) {
	    $symbol{$_} += $count;
	    $n += $count;
	}
    } elsif ($opt_W) {
	chop;
	for (split) {
	    next if /^$/;
	    $symbol{$_}++;
	    $n++;
	}
    } elsif ($opt_l) {
	chop;
	$symbol{$_}++;
	$n++;
    } elsif ($opt_c) {
	my @a = split;
	$symbol{$a[-1]} += $a[-2];
	$n += $a[-2];
    } else {
	chop if $opt_n;
	s/ //g if $opt_s;
	for my $c (split(//, $_)) {
	    $symbol{$c}++;
	    $n++;
	}
    }
}

# post-processing
if ($opt_B) {
    # reduce to Unicode range
    my %raw_symbol = %symbol;
    %symbol = ();
    for my $c ((keys %raw_symbol)) {
	my $ub = get_ublock($c);
	$symbol{$ub} += $raw_symbol{$c};
    }
}

if ($opt_k) {
    # handle -k flag
    my $k = 0;
    foreach $s (sort {$symbol{$b} <=> $symbol{$a}} (keys %symbol)) {
	if ($k >= $opt_k) {
	    $symbol{$opt_t} += $symbol{$s};
	    delete $symbol{$s};
	}
	$k++;
    }
} elsif ($opt_x) {
    # handle -x flag
    foreach $s (keys %symbol) {
	if ($symbol{$s} == 1) {
	    $symbol{$opt_t} += $symbol{$s};
	    delete $symbol{$s};
	}
    }
}

# sort the output
sub nSort {
    # numerically, except for $opt_t which always comes last
    return -1 if $b eq $opt_t;
    return 1 if $a eq $opt_t;
    return $a <=> $b;
}

if ($opt_N) {
    @clist = sort nSort (keys %symbol);
} else {
    @clist = sort {$symbol{$b} <=> $symbol{$a}} (keys %symbol);
}

# computes precision necessary for the various fields
sub maxrange {
    for my $i (0..$#_) {
	$v = length(sprintf("%.0lf", $_[$i]));
	$maxrange[$i] = $v if $v > $maxrange[$i];
    }
}

$rank = $cumul = 0;
foreach $c (@clist) {
    $cumul += $symbol{$c};
    for my $f (@outCol) {
	my $value = sprintf($f->{fmt}, &{$f->{value}}());
	my $len = length($value);
	$f->{maxlen} = $len if $len > $f->{maxlen};
	maxrange($rank, $cumul, $symbol{$c});
    }
    $rank++;
}

# print header
my @out;
for my $f (@outCol) {
    my $len = length($f->{name});
    $f->{maxlen} = $len if $len > $f->{maxlen};
    $f->{postFmt} = "%".$f->{maxlen}."s";
    push @out, sprintf($f->{postFmt}, $f->{name});
}
my $header = join(" ", @out);
print "$header\n";
print '-' x length($header), "\n";

($fmt = sprintf("_%dd _6.4f _6.4f _%d.0f _%d.0f", @maxrange)) =~ s/_/\%/g;

$rank = $cumul = 0;
# prints out:
# rank cumulative-frequency frequency count symbol
foreach $c (@clist) {
    $cumul += $symbol{$c};
    if ($opt_W || $opt_l || $opt_c) {
	my @out = ();
	for my $f (@outCol) {
	    my $value = sprintf($f->{fmt}, &{$f->{value}}());
	    my $len = length($value);
	    push @out, sprintf($f->{postFmt}, $value);
	}
	print join(" ", @out),"\n";
	#print sprintf($fmt." %s\n",
	#	      $rank, $cumul/$n, $symbol{$c}/$n, $cumul, $symbol{$c}, $c);
    } elsif ($opt_B) {
	print sprintf($fmt." %s\n",
		      $rank, $cumul/$n, $symbol{$c}/$n, $cumul, $symbol{$c}, $c);
    } else {
	print sprintf($fmt." %s=(%s)\n",
		      $rank, $cumul/$n, $symbol{$c}/$n, $cumul, $symbol{$c}, $c, ord($c));
    }
    $rank++;
}

####  definition of Unicode blocks -- see http://www.fileformat.info/info/unicode/block/index.htm
# note, to obtain this list, I did:
# cat file.txt | perl -ne 's/\s*\(\d+\)//g; next unless my ($d,$a,$b)=/^\s*(.*?)\s+U\+([0-9A-F]+)\s+U\+([0-9A-F]+)/; print "qr/[\\x\{$a}-\\x\{$b}]/ => \"$d\",\n"' file.pl
sub init_range {
    $ublock0 =
      [[qr/\s/ => "White Space"],
       [qr/[0-9]/ => "Digits"],
       [qr/[a-zA-Z]/ => "Letters"],
       [qr/[:cntrl:]/ => "Control"],
       [qr/[:punct:]/ => "Punctuation"]
      ];
    %ublock =
      (qr/[\x{0000}-\x{007F}]/ => "Basic Latin",
       qr/[\x{0080}-\x{00FF}]/ => "Latin-1 Supplement",
       qr/[\x{0100}-\x{017F}]/ => "Latin Extended-A",
       qr/[\x{0180}-\x{024F}]/ => "Latin Extended-B",
       qr/[\x{0250}-\x{02AF}]/ => "IPA Extensions",
       qr/[\x{02B0}-\x{02FF}]/ => "Spacing Modifier Letters",
       qr/[\x{0300}-\x{036F}]/ => "Combining Diacritical Marks",
       qr/[\x{0370}-\x{03FF}]/ => "Greek and Coptic",
       qr/[\x{0400}-\x{04FF}]/ => "Cyrillic",
       qr/[\x{0500}-\x{052F}]/ => "Cyrillic Supplement",
       qr/[\x{0530}-\x{058F}]/ => "Armenian",
       qr/[\x{0590}-\x{05FF}]/ => "Hebrew",
       qr/[\x{0600}-\x{06FF}]/ => "Arabic",
       qr/[\x{0700}-\x{074F}]/ => "Syriac",
       qr/[\x{0750}-\x{077F}]/ => "Arabic Supplement",
       qr/[\x{0780}-\x{07BF}]/ => "Thaana",
       qr/[\x{07C0}-\x{07FF}]/ => "NKo",
       qr/[\x{0800}-\x{083F}]/ => "Samaritan",
       qr/[\x{0840}-\x{085F}]/ => "Mandaic",
       qr/[\x{08A0}-\x{08FF}]/ => "Arabic Extended-A",
       qr/[\x{0900}-\x{097F}]/ => "Devanagari",
       qr/[\x{0980}-\x{09FF}]/ => "Bengali",
       qr/[\x{0A00}-\x{0A7F}]/ => "Gurmukhi",
       qr/[\x{0A80}-\x{0AFF}]/ => "Gujarati",
       qr/[\x{0B00}-\x{0B7F}]/ => "Oriya",
       qr/[\x{0B80}-\x{0BFF}]/ => "Tamil",
       qr/[\x{0C00}-\x{0C7F}]/ => "Telugu",
       qr/[\x{0C80}-\x{0CFF}]/ => "Kannada",
       qr/[\x{0D00}-\x{0D7F}]/ => "Malayalam",
       qr/[\x{0D80}-\x{0DFF}]/ => "Sinhala",
       qr/[\x{0E00}-\x{0E7F}]/ => "Thai",
       qr/[\x{0E80}-\x{0EFF}]/ => "Lao",
       qr/[\x{0F00}-\x{0FFF}]/ => "Tibetan",
       qr/[\x{1000}-\x{109F}]/ => "Myanmar",
       qr/[\x{10A0}-\x{10FF}]/ => "Georgian",
       qr/[\x{1100}-\x{11FF}]/ => "Hangul Jamo",
       qr/[\x{1200}-\x{137F}]/ => "Ethiopic",
       qr/[\x{1380}-\x{139F}]/ => "Ethiopic Supplement",
       qr/[\x{13A0}-\x{13FF}]/ => "Cherokee",
       qr/[\x{1400}-\x{167F}]/ => "Unified Canadian Aboriginal Syllabics",
       qr/[\x{1680}-\x{169F}]/ => "Ogham",
       qr/[\x{16A0}-\x{16FF}]/ => "Runic",
       qr/[\x{1700}-\x{171F}]/ => "Tagalog",
       qr/[\x{1720}-\x{173F}]/ => "Hanunoo",
       qr/[\x{1740}-\x{175F}]/ => "Buhid",
       qr/[\x{1760}-\x{177F}]/ => "Tagbanwa",
       qr/[\x{1780}-\x{17FF}]/ => "Khmer",
       qr/[\x{1800}-\x{18AF}]/ => "Mongolian",
       qr/[\x{18B0}-\x{18FF}]/ => "Unified Canadian Aboriginal Syllabics Extended",
       qr/[\x{1900}-\x{194F}]/ => "Limbu",
       qr/[\x{1950}-\x{197F}]/ => "Tai Le",
       qr/[\x{1980}-\x{19DF}]/ => "New Tai Lue",
       qr/[\x{19E0}-\x{19FF}]/ => "Khmer Symbols",
       qr/[\x{1A00}-\x{1A1F}]/ => "Buginese",
       qr/[\x{1A20}-\x{1AAF}]/ => "Tai Tham",
       qr/[\x{1B00}-\x{1B7F}]/ => "Balinese",
       qr/[\x{1B80}-\x{1BBF}]/ => "Sundanese",
       qr/[\x{1BC0}-\x{1BFF}]/ => "Batak",
       qr/[\x{1C00}-\x{1C4F}]/ => "Lepcha",
       qr/[\x{1C50}-\x{1C7F}]/ => "Ol Chiki",
       qr/[\x{1CC0}-\x{1CCF}]/ => "Sundanese Supplement",
       qr/[\x{1CD0}-\x{1CFF}]/ => "Vedic Extensions",
       qr/[\x{1D00}-\x{1D7F}]/ => "Phonetic Extensions",
       qr/[\x{1D80}-\x{1DBF}]/ => "Phonetic Extensions Supplement",
       qr/[\x{1DC0}-\x{1DFF}]/ => "Combining Diacritical Marks Supplement",
       qr/[\x{1E00}-\x{1EFF}]/ => "Latin Extended Additional",
       qr/[\x{1F00}-\x{1FFF}]/ => "Greek Extended",
       qr/[\x{2000}-\x{206F}]/ => "General Punctuation",
       qr/[\x{2070}-\x{209F}]/ => "Superscripts and Subscripts",
       qr/[\x{20A0}-\x{20CF}]/ => "Currency Symbols",
       qr/[\x{20D0}-\x{20FF}]/ => "Combining Diacritical Marks for Symbols",
       qr/[\x{2100}-\x{214F}]/ => "Letterlike Symbols",
       qr/[\x{2150}-\x{218F}]/ => "Number Forms",
       qr/[\x{2190}-\x{21FF}]/ => "Arrows",
       qr/[\x{2200}-\x{22FF}]/ => "Mathematical Operators",
       qr/[\x{2300}-\x{23FF}]/ => "Miscellaneous Technical",
       qr/[\x{2400}-\x{243F}]/ => "Control Pictures",
       qr/[\x{2440}-\x{245F}]/ => "Optical Character Recognition",
       qr/[\x{2460}-\x{24FF}]/ => "Enclosed Alphanumerics",
       qr/[\x{2500}-\x{257F}]/ => "Box Drawing",
       qr/[\x{2580}-\x{259F}]/ => "Block Elements",
       qr/[\x{25A0}-\x{25FF}]/ => "Geometric Shapes",
       qr/[\x{2600}-\x{26FF}]/ => "Miscellaneous Symbols",
       qr/[\x{2700}-\x{27BF}]/ => "Dingbats",
       qr/[\x{27C0}-\x{27EF}]/ => "Miscellaneous Mathematical Symbols-A",
       qr/[\x{27F0}-\x{27FF}]/ => "Supplemental Arrows-A",
       qr/[\x{2800}-\x{28FF}]/ => "Braille Patterns",
       qr/[\x{2900}-\x{297F}]/ => "Supplemental Arrows-B",
       qr/[\x{2980}-\x{29FF}]/ => "Miscellaneous Mathematical Symbols-B",
       qr/[\x{2A00}-\x{2AFF}]/ => "Supplemental Mathematical Operators",
       qr/[\x{2B00}-\x{2BFF}]/ => "Miscellaneous Symbols and Arrows",
       qr/[\x{2C00}-\x{2C5F}]/ => "Glagolitic",
       qr/[\x{2C60}-\x{2C7F}]/ => "Latin Extended-C",
       qr/[\x{2C80}-\x{2CFF}]/ => "Coptic",
       qr/[\x{2D00}-\x{2D2F}]/ => "Georgian Supplement",
       qr/[\x{2D30}-\x{2D7F}]/ => "Tifinagh",
       qr/[\x{2D80}-\x{2DDF}]/ => "Ethiopic Extended",
       qr/[\x{2DE0}-\x{2DFF}]/ => "Cyrillic Extended-A",
       qr/[\x{2E00}-\x{2E7F}]/ => "Supplemental Punctuation",
       qr/[\x{2E80}-\x{2EFF}]/ => "CJK Radicals Supplement",
       qr/[\x{2F00}-\x{2FDF}]/ => "Kangxi Radicals",
       qr/[\x{2FF0}-\x{2FFF}]/ => "Ideographic Description Characters",
       qr/[\x{3000}-\x{303F}]/ => "CJK Symbols and Punctuation",
       qr/[\x{3040}-\x{309F}]/ => "Hiragana",
       qr/[\x{30A0}-\x{30FF}]/ => "Katakana",
       qr/[\x{3100}-\x{312F}]/ => "Bopomofo",
       qr/[\x{3130}-\x{318F}]/ => "Hangul Compatibility Jamo",
       qr/[\x{3190}-\x{319F}]/ => "Kanbun",
       qr/[\x{31A0}-\x{31BF}]/ => "Bopomofo Extended",
       qr/[\x{31C0}-\x{31EF}]/ => "CJK Strokes",
       qr/[\x{31F0}-\x{31FF}]/ => "Katakana Phonetic Extensions",
       qr/[\x{3200}-\x{32FF}]/ => "Enclosed CJK Letters and Months",
       qr/[\x{3300}-\x{33FF}]/ => "CJK Compatibility",
       qr/[\x{3400}-\x{4DBF}]/ => "CJK Unified Ideographs Extension A",
       qr/[\x{4DC0}-\x{4DFF}]/ => "Yijing Hexagram Symbols",
       qr/[\x{4E00}-\x{9FFF}]/ => "CJK Unified Ideographs",
       qr/[\x{A000}-\x{A48F}]/ => "Yi Syllables",
       qr/[\x{A490}-\x{A4CF}]/ => "Yi Radicals",
       qr/[\x{A4D0}-\x{A4FF}]/ => "Lisu",
       qr/[\x{A500}-\x{A63F}]/ => "Vai",
       qr/[\x{A640}-\x{A69F}]/ => "Cyrillic Extended-B",
       qr/[\x{A6A0}-\x{A6FF}]/ => "Bamum",
       qr/[\x{A700}-\x{A71F}]/ => "Modifier Tone Letters",
       qr/[\x{A720}-\x{A7FF}]/ => "Latin Extended-D",
       qr/[\x{A800}-\x{A82F}]/ => "Syloti Nagri",
       qr/[\x{A830}-\x{A83F}]/ => "Common Indic Number Forms",
       qr/[\x{A840}-\x{A87F}]/ => "Phags-pa",
       qr/[\x{A880}-\x{A8DF}]/ => "Saurashtra",
       qr/[\x{A8E0}-\x{A8FF}]/ => "Devanagari Extended",
       qr/[\x{A900}-\x{A92F}]/ => "Kayah Li",
       qr/[\x{A930}-\x{A95F}]/ => "Rejang",
       qr/[\x{A960}-\x{A97F}]/ => "Hangul Jamo Extended-A",
       qr/[\x{A980}-\x{A9DF}]/ => "Javanese",
       qr/[\x{AA00}-\x{AA5F}]/ => "Cham",
       qr/[\x{AA60}-\x{AA7F}]/ => "Myanmar Extended-A",
       qr/[\x{AA80}-\x{AADF}]/ => "Tai Viet",
       qr/[\x{AAE0}-\x{AAFF}]/ => "Meetei Mayek Extensions",
       qr/[\x{AB00}-\x{AB2F}]/ => "Ethiopic Extended-A",
       qr/[\x{ABC0}-\x{ABFF}]/ => "Meetei Mayek",
       qr/[\x{AC00}-\x{D7AF}]/ => "Hangul Syllables",
       qr/[\x{D7B0}-\x{D7FF}]/ => "Hangul Jamo Extended-B",
       qr/[\x{D800}-\x{DB7F}]/ => "High Surrogates",
       qr/[\x{DB80}-\x{DBFF}]/ => "High Private Use Surrogates",
       qr/[\x{DC00}-\x{DFFF}]/ => "Low Surrogates",
       qr/[\x{E000}-\x{F8FF}]/ => "Private Use Area",
       qr/[\x{F900}-\x{FAFF}]/ => "CJK Compatibility Ideographs",
       qr/[\x{FB00}-\x{FB4F}]/ => "Alphabetic Presentation Forms",
       qr/[\x{FB50}-\x{FDFF}]/ => "Arabic Presentation Forms-A",
       qr/[\x{FE00}-\x{FE0F}]/ => "Variation Selectors",
       qr/[\x{FE10}-\x{FE1F}]/ => "Vertical Forms",
       qr/[\x{FE20}-\x{FE2F}]/ => "Combining Half Marks",
       qr/[\x{FE30}-\x{FE4F}]/ => "CJK Compatibility Forms",
       qr/[\x{FE50}-\x{FE6F}]/ => "Small Form Variants",
       qr/[\x{FE70}-\x{FEFF}]/ => "Arabic Presentation Forms-B",
       qr/[\x{FF00}-\x{FFEF}]/ => "Halfwidth and Fullwidth Forms",
       qr/[\x{FFF0}-\x{FFFF}]/ => "Specials",
       qr/[\x{10000}-\x{1007F}]/ => "Linear B Syllabary",
       qr/[\x{10080}-\x{100FF}]/ => "Linear B Ideograms",
       qr/[\x{10100}-\x{1013F}]/ => "Aegean Numbers",
       qr/[\x{10140}-\x{1018F}]/ => "Ancient Greek Numbers",
       qr/[\x{10190}-\x{101CF}]/ => "Ancient Symbols",
       qr/[\x{101D0}-\x{101FF}]/ => "Phaistos Disc",
       qr/[\x{10280}-\x{1029F}]/ => "Lycian",
       qr/[\x{102A0}-\x{102DF}]/ => "Carian",
       qr/[\x{10300}-\x{1032F}]/ => "Old Italic",
       qr/[\x{10330}-\x{1034F}]/ => "Gothic",
       qr/[\x{10380}-\x{1039F}]/ => "Ugaritic",
       qr/[\x{103A0}-\x{103DF}]/ => "Old Persian",
       qr/[\x{10400}-\x{1044F}]/ => "Deseret",
       qr/[\x{10450}-\x{1047F}]/ => "Shavian",
       qr/[\x{10480}-\x{104AF}]/ => "Osmanya",
       qr/[\x{10800}-\x{1083F}]/ => "Cypriot Syllabary",
       qr/[\x{10840}-\x{1085F}]/ => "Imperial Aramaic",
       qr/[\x{10900}-\x{1091F}]/ => "Phoenician",
       qr/[\x{10920}-\x{1093F}]/ => "Lydian",
       qr/[\x{10980}-\x{1099F}]/ => "Meroitic Hieroglyphs",
       qr/[\x{109A0}-\x{109FF}]/ => "Meroitic Cursive",
       qr/[\x{10A00}-\x{10A5F}]/ => "Kharoshthi",
       qr/[\x{10A60}-\x{10A7F}]/ => "Old South Arabian",
       qr/[\x{10B00}-\x{10B3F}]/ => "Avestan",
       qr/[\x{10B40}-\x{10B5F}]/ => "Inscriptional Parthian",
       qr/[\x{10B60}-\x{10B7F}]/ => "Inscriptional Pahlavi",
       qr/[\x{10C00}-\x{10C4F}]/ => "Old Turkic",
       qr/[\x{10E60}-\x{10E7F}]/ => "Rumi Numeral Symbols",
       qr/[\x{11000}-\x{1107F}]/ => "Brahmi",
       qr/[\x{11080}-\x{110CF}]/ => "Kaithi",
       qr/[\x{110D0}-\x{110FF}]/ => "Sora Sompeng",
       qr/[\x{11100}-\x{1114F}]/ => "Chakma",
       qr/[\x{11180}-\x{111DF}]/ => "Sharada",
       qr/[\x{11680}-\x{116CF}]/ => "Takri",
       qr/[\x{12000}-\x{123FF}]/ => "Cuneiform",
       qr/[\x{12400}-\x{1247F}]/ => "Cuneiform Numbers and Punctuation",
       qr/[\x{13000}-\x{1342F}]/ => "Egyptian Hieroglyphs",
       qr/[\x{16800}-\x{16A3F}]/ => "Bamum Supplement",
       qr/[\x{16F00}-\x{16F9F}]/ => "Miao",
       qr/[\x{1B000}-\x{1B0FF}]/ => "Kana Supplement",
       qr/[\x{1D000}-\x{1D0FF}]/ => "Byzantine Musical Symbols",
       qr/[\x{1D100}-\x{1D1FF}]/ => "Musical Symbols",
       qr/[\x{1D200}-\x{1D24F}]/ => "Ancient Greek Musical Notation",
       qr/[\x{1D300}-\x{1D35F}]/ => "Tai Xuan Jing Symbols",
       qr/[\x{1D360}-\x{1D37F}]/ => "Counting Rod Numerals",
       qr/[\x{1D400}-\x{1D7FF}]/ => "Mathematical Alphanumeric Symbols",
       qr/[\x{1EE00}-\x{1EEFF}]/ => "Arabic Mathematical Alphabetic Symbols",
       qr/[\x{1F000}-\x{1F02F}]/ => "Mahjong Tiles",
       qr/[\x{1F030}-\x{1F09F}]/ => "Domino Tiles",
       qr/[\x{1F0A0}-\x{1F0FF}]/ => "Playing Cards",
       qr/[\x{1F100}-\x{1F1FF}]/ => "Enclosed Alphanumeric Supplement",
       qr/[\x{1F200}-\x{1F2FF}]/ => "Enclosed Ideographic Supplement",
       qr/[\x{1F300}-\x{1F5FF}]/ => "Miscellaneous Symbols And Pictographs",
       qr/[\x{1F600}-\x{1F64F}]/ => "Emoticons",
       qr/[\x{1F680}-\x{1F6FF}]/ => "Transport And Map Symbols",
       qr/[\x{1F700}-\x{1F77F}]/ => "Alchemical Symbols",
       qr/[\x{20000}-\x{2A6DF}]/ => "CJK Unified Ideographs Extension B",
       qr/[\x{2A700}-\x{2B73F}]/ => "CJK Unified Ideographs Extension C",
       qr/[\x{2B740}-\x{2B81F}]/ => "CJK Unified Ideographs Extension D",
       qr/[\x{2F800}-\x{2FA1F}]/ => "CJK Compatibility Ideographs Supplement",
       qr/[\x{E0000}-\x{E007F}]/ => "Tags",
       qr/[\x{E0100}-\x{E01EF}]/ => "Variation Selectors Supplement",
       qr/[\x{F0000}-\x{FFFFF}]/ => "Supplementary Private Use Area-A",
       qr/[\x{100000}-\x{10FFFF}]/ => "Supplementary Private Use Area-B"
      );
}

sub get_ublock {
    my $c = shift;
    init_range() unless defined(%ublock);
    for my $d (@{$ublock0}) {
	return $d->[1] if $c =~ $d->[0];
    }
    for my $re ((keys %ublock)) {
	return $ublock{$re} if $c =~ $re;
    }
    return "unknown";
}
