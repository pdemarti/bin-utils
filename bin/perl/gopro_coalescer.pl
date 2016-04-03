#!/usr/bin/perl
#----------------------------------------------------------------------
# PD 20130425
# Finds all the gopro movies in the provided dir (recursively)
# and for each set GOPR<nnnn>.MP4, GP01<nnnn>.MP4, GP02<nnnn>.MP4, etc.
# it merges them into a vid_<nnnn>.mp4
#----------------------------------------------------------------------

use Getopt::Std;
use File::Find;

sub err_usage {
  print STDERR "
Usage is:
$0 [OPTIONS] [dir]
  OPTIONS:
  -h:      help; print this and exit.
  -n:      dry-run, don't actually merge files
  -d:      delete the original files after merging
";
  exit @_;
}

err_usage(200) unless getopts('hnd');
$d = shift || '.';

@flist = ();
File::Find::find({wanted => \&wanted}, $d);

sub wanted {
    my ($dev,$ino,$mode,$nlink,$uid,$gid);
    (($dev,$ino,$mode,$nlink,$uid,$gid) = lstat($_)) &&
    -f _ && /^G[OPR\d]+.MP4$/ && push @flist,$File::Find::name;
}

for (@flist) {
    if (m,.*/GOPR(\d{4}).MP4$,) {
	$f->{$1}->[0] = $_;
    } elsif (m,.*/GP(\d\d)(\d{4}).MP4$,) {
	$f->{$2}->[$1+0] = $_;
    } else {
	warn "Ignoring file: $_\n";
    }
}

# now do the merges
for my $i (sort (keys %{$f})) {
    my @a; my $j=0;
    print "$i: ", join (",", @{$f->{$i}}),"\n";
    for $m (@{$f->{$i}}) {
	my $t = "/tmp/tmp_$j.ts"; $j++;
	print "$m to $t\n";
	qx{ffmpeg -i $m -c copy -bsf:v h264_mp4toannexb -f mpegts $t} unless $opt_n;
	push @a,$t;
    }
    my $concat = join("|",@a);
    my $o = "vid_$i.mp4";
    print "$concat to $o\n";
    qx{ffmpeg -i "concat:$concat" -c copy -bsf:a aac_adtstoasc $o} unless $opt_n;
    for my $t (@a) {
	unlink $t;
    }
}
