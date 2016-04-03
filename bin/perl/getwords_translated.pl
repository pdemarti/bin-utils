#!/usr/bin/perl
#----------------------------------------------------------------------
# PD 20130402
# Read the -i file, expecting a tsv: rank sign word
# Open in rw the -o file; look for what's been done so far (last rank of word processed)
# then, serve one word, wait for a block of text entered "at once" (i.e. with less than -t timemout between lines)
# push the word, some markers (incl. rank), then the received block of text, into the -o file.
# Flush. Repeat as there are more words to translate.  The program can be ctrl-C'ed at any point.
#----------------------------------------------------------------------
use open qw/:std :utf8/;
use IO::Select;
use Getopt::Std;

our $opt_t = 0.200;
our $opt_i;
our $opt_o;

# getlines(file_handle, timeout_in_seconds): wait for text on the file-handle. Once text has started to come in,
# then get more lines as long as no more than timeout seconds have elapsed.
sub getlines {
  my ($fh, $timeout) = @_;
  my ($buf, $n);
  my $offset = 0;
  my $s = IO::Select->new();
  $s->add($fh);
  $s->can_read();
  while (@ready = $s->can_read($timeout)) {
    $buf .= <$fh>;
  }
  return $buf;
}

sub err_usage {
  print STDERR "
Usage is:
$0 [OPTIONS] input_file output_file
  OPTIONS:
  -t timeout: timeout in (possibly fractional) seconds to determine contiguous blocks of text (default $opt_t)
  -h:         help
";
  exit @_;
}

# main
err_usage(200) unless getopts('ht:');
$opt_i = shift;
$opt_o = shift || err_usage(200);
err_usage(0) if $opt_h;

open my $fh,$opt_i or die "$opt_i: $!";
while (<$fh>) {
  unless (/^(\d+)\s+\-?\d+\s+(.*)/) {
    warn "skipping line $.: $_";
    next;
  }
  $word{$1} = $2;
}
close $fh;
my $start = 0;
if (open(I, "$opt_o")) {
    # read it to find where we stopped
    while (<I>) {
	/^rank=(\d+)$/ || next;
	$start = $1 if $1 > $start;
    }
}
close(I);
open(O,">>$opt_o") || die "cannot write to $opt_o: $!\n";
select O; $|=1;
select STDOUT;
for my $rank (sort {$a <=> $b} (keys %word)) {
  next if $rank <= $start;
  my $w = $word{$rank};
  print '-' x 80,"\n\nrank=$rank\t\t$w\n\n";
  $txt = getlines(\*STDIN, $opt_t);
  print O "-" x 80,"\n";
  print O "rank=$rank\n";
  print O "word=$w\n";
  print O "$txt";
  print O "=" x 80,"\n";
}
