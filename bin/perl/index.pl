#!/usr/bin/perl
#----------------------------------------------------------------------
# PD 20120510
# Port to Perl of the old shell script 'index', in order to save us
# from recomputing the MD5 of an inode that has already been computed.
# It should save quite some time since, esp. in backup disks with daily snapshots,
# a lot of the files actually point to the same inode.
#
# Also, the output can directly be loaded into GP, as we use tab-separated
# values, '\N' for null, etc. (See one of the XML2GP java classes).
#----------------------------------------------------------------------
use utf8;
use Unicode::Normalize;
use File::Find;
use vars qw/*name *dir *prune/;
*name   = *File::Find::name;
*dir    = *File::Find::dir;
*prune  = *File::Find::prune;
use Getopt::Std;
use Digest::MD5;
use File::Spec;
use Cwd;

our $opt_m = 0;
our $opt_c;
our $opt_d;
our $opt_n = $ENV{GP_SEGMENT_COUNT} || 1;
our $opt_i = $ENV{GP_SEGMENT_ID} || 0;

sub err_usage {
  print STDERR "
Usage is:
$0 [OPTIONS] [dir]
  OPTIONS:
  -h:      help; print this and exit.
  -a:      list all files from the filesystem containing dir, instead of just the files under dir.
  -c:      print the DDL to create the table.
  -m time: don't compute the md5 of files older than that time (seconds since the epoch).
  -d:      just print information on the mounted devices and exit
  -i i:    handles slice i out of n (default: $opt_i).
  -n n:    number of slices (default: $opt_n).
";
  exit @_;
}

err_usage(200) unless getopts('ahcm:di:n:');
err_usage(0) if $opt_h;
err_usage(200) if $opt_i >= $opt_n;

my $topdir = shift || '.';

$t0 = time();

binmode STDOUT, ":encoding(utf8)";
sub sanitize {
    local $_ = shift;
    utf8::decode($_);
    $_ = NFD($_);
    return $_;
}

sub rowout {
    print join("\t", map { s/\\/\\\\/gm; s/\t/\\t/gm; s/\n/\\n/gm; sanitize($_) } @_),"\n";
}

sub get_info {
    my $topdir = shift;
    my $cmd = "df -k -P -l \"$topdir\"";
    local $_ = qx{$cmd};
    # skip header
    s/[^\n]*\n//m;
    warn "multiline response for $cmd: $_" if scalar(@dummy=m/\n/gm)>1;
    chomp; s/\%//;
    my ($dev,$total,$used,$avail,$pct,$mounted,$other) = split;
    warn "trailing stuff after df: $_\n" if $other=~/./;
    my $line = $_ = qx{/sbin/blkid $dev};
    warn "multiline response for blkid $dev: $_" if scalar(@dummy=m/\n/gm)>1;
    s/\n.*//;
    my ($ddev,$uuid,$type,$label) = ('\N','\N','\N','\N');
    $ddev = $1 if s/^([^ :]+):\s*//;
    $uuid = $1 if s/UUID=\"([^\"]+)\"\s*//;
    $type = $1 if s/TYPE=\"([^\"]+)\"\s*//;
    $label= $1 if s/LABEL=\"([^\"]+)\"\s*//;
    warn "couldn't read info for device $dev from $line" unless $ddev eq $dev;
    my ($devno,@other) = lstat($mounted);
    return ($devno,$dev,$type,$total,$used,$avail,$pct,$mounted,$uuid,$label);
}

sub compute_md5 {
    my $path = shift;
    open(F,$path) || return "\\N";
    my $ctx = Digest::MD5->new;
    $ctx->addfile(F);
    close(F);
    return $ctx->hexdigest;
}

my %md5 = ();

sub get_md5 {
    my ($path,$mtime,$ino) = @_;
    if (!defined($md5{$ino}) || $mtime >= $t0) {
	$md5{$ino} = compute_md5($path);
    }
    return $md5{$ino};
}

sub process {
#    my $ccwd = qx{pwd};
#    print STDERR "process of '$_'\ncwd=$ccwd\n";
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
        $atime,$mtime,$ctime,$blksize,$blocks) = lstat($_);
    return unless !($File::Find::prune |= ($dev != $File::Find::topdev));
    return unless -f _;
    return if $opt_n > 1 && ($ino % $opt_n)!=$opt_i;  # take only slice i out of n
    my $md5 = $ctime < $opt_m ? '\N' : get_md5($_,$mtime,$ino);
    rowout(time,$dev,$ino,$mode,$nlink,$uid,$gid,$size,$atime,$mtime,$ctime,$md5,$name);
}

if ($opt_d) {
    if ($opt_c) {
	print "
  exec    int,   -- 0: exec time
  dev     int,   -- 1: device number of filesystem
  devnm   text,  -- 2: device name
  type    text,  -- 3: filesystem type
  total   int8,  -- 4: total size, in bytes
  used    int8,  -- 5: size used, in bytes
  avail   int8,  -- 6: size available, in bytes
  pct     int,   -- 7: percent used
  mounted text,  -- 8: mountpoint
  uuid    text,  -- 9: uuid of the device
  label   text   --10: label of the device
";
    } else {
	rowout(time,get_info($topdir)) if $opt_i == 0;
    }
} else {
    if ($opt_c) {
	print "
  exec  int,   --  0: exec time
  dev   int,   --  1: device number of filesystem
  ino   int,   --  2: inode number
  mode  int,   --  3: file mode  (type and permissions)
  nlink int,   --  4: number of (hard) links to the file
  uid   int,   --  5: numeric user ID of file's owner
  gid   int,   --  6: numeric group ID of file's owner
  size  int8,  --  7: total size of file, in bytes
  atime int,   --  8: last access time in seconds since the epoch
  mtime int,   --  9: last modify time in seconds since the epoch
  ctime int,   -- 10: inode change time in seconds since the epoch
  md5   text,  -- 11: md5sum of the file's content
  path  text   -- 12: path relative to mountpoint
";
    } else {
	my ($dev,$devnm,$type,$total,$used,$avail,$pct,$mounted,$uuid,$label) = get_info($topdir);
	$topdir = File::Spec->abs2rel(Cwd::realpath($topdir), $mounted);
        $topdir = '.' unless $topdir=~/\S/;
        print STDERR "topdir=$topdir\nimounted=$mounted\n\n";
        chdir $mounted;
	File::Find::find({ wanted => \&process}, $topdir);
    }
}
