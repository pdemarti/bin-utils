#!/usr/bin/perl
#----------------------------------------------------------------------
# PD 20170801
# Compute the time difference between the last line and the first line
# of a log file (or several log files).
#----------------------------------------------------------------------

use Getopt::Std;
use Date::Parse qw/str2time/;
use POSIX qw/strftime/;

our $opt_e = qr/\d{4}-\d{2}-\d{2}[ T]\d\d:\d\d:\d\d/;
our $opt_s = 8000;

sub err_usage {
  print STDERR "
Usage is:
$0 [OPTIONS] [files...]
  -h:        help; print this and exit
  -s nbytes: seek nbytes before the end to look for the last lines (default $opt_s).
  -v:        verbose: print first and last lines where a timestamp was found, to show where they come from.

Compute and display the time difference between the last line (containing a timestamp) and the first line
(containing a timestamp) in a log file. If several log files are provided, then show the duration for each
of them.  For seekable files, the last line containing a timestamp is looked for only in the complete lines
nbytes from the file's end (large speedup). You can disable that by setting -s 0.

Another use case is to somehow filter a log (select a portion of the lines, or grep for a pattern, for example),
then pipe that to log_duration.pl.
";
  exit @_;
}

err_usage(200) unless getopts('hv');
err_usage(0) if $opt_h;
#err_usage(200) unless defined($opt_c) && defined($opt_t);

sub get_first {
  # the argument is a filehandle, e.g. ARGV, assumed to be opened
  # at the beginning of the file or of the stream.
  my $fh = shift;
  while (<$fh>) {
    return $& if /$opt_e/;
  }
  return undef;
}
 
sub get_last {
  # the argument is a filehandle, e.g. ARGV, assumed to be opened
  # and positioned just after the first line containing a timestamp.
  # If the filehandle is seekable, then use seek to go close to the
  # end of the file. Otherwise, iterate through the lines and keep the
  # last k to search for a timestamp in.
  my $fh = shift;
  return if eof($fh);
  my $pos = tell($fh);
  my $blksize = 8000;
  my $klines = 100;
  local $_;
  if (seek($fh, -$blksize, 2)) {
    #printf("seekable; pos = %d, tell = %d\n", $pos, tell($fh));
    # seekable -- good, check if we are still ahead of $pos
    if (tell($fh) < $pos) {
      seek($fh, $pos, 0);
      #printf("now pos = %d\n", tell($fh));
    } else {
      # skip one line so that we start at a full line
      #print("skip one line\n");
      while (<$fh>) { last }
    }
  }
  my $i = 0;
  my @lines;
  while (<$fh>) {
    $lines[$i++ % $klines] = $_;
  }
  #printf("i=%d\n", $i);
  my $j = 0;
  while ($j++ < $klines && $i > 0) {
    $_ = $lines[--$i % $klines];
    #print("i=$i, j=$j, klines=$klines, looking into $_");
    return $& if /$opt_e/;
  }
  return undef;
}

push @ARGV, '-' unless @ARGV;
for my $name (@ARGV) {
  my $fh;
  unless (open($fh, $name)) {
    warn "$!\n";
    next;
  }
  $st0 = get_first($fh);
  $st1 = get_last($fh);
  close $fh;
  if (not defined $st0) {
    warn "no timestamp found in $name";
    next;
  }
  if (not defined $st1) {
    warn "no timestamp found in the tail of $name";
    next;
  }
  $t0 = str2time($st0);
  $t1 = str2time($st1);
  $dts = duration_str($t1 - $t0);
  if ($opt_v) {
    printf("%11s (%s .. %s): %s\n", $dts, $st0, $st1, $name);
  } else {
    printf("%11s: %s\n", $dts, $name);
  }
}

sub duration_str {
  my $remaining = shift;
  my $rdays = int($remaining / (24*3600));
  $remaining -= $rdays*24*3600;
  my $str = $rdays > 0 ? sprintf("%dd+", $rdays) : "";
  return sprintf("%s%s", $str, strftime("%H:%M:%S", gmtime($remaining)));
}
