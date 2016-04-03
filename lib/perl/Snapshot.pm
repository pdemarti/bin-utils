#!/usr/local/bin/perl
#
# Snapshot.pm
#
# Module containing methods relating to the backup and restore of stuff
# using the LSH style snapshots

=pod

=head1 Snapshot.pm

=head1 NAME

Snapshot.pm

Module to take snapshots using Linux Server Hacks rsync / cp -al method

=head1 SYNOPSIS

  use Snapshot qw/do_snapshot/;

  my $return=do_snapshot({ source => '/home/robartes/',
                           snapshot_dir => '/snapshots/home',
                         }) or die $Snapshot::error;

=head1 DESCRIPTION

=head2 Introduction

Snapshot.pm provides a method to manage snapshots of directory trees. It uses
the method given in Hack #74 in the excellent O'Reilly "Linux Server Hacks"
book (don't be put off by the Linux part - most hacks are applicable to any
Unix, and so is this module). More information about this method can be
found in that book and in this document under L</SNAPSHOT METHOD>.

'Snapshots' are defined as a number of copies of a directory tree,
reflecting the state of said tree I<at the moment the copy was taken>. This
means that a file in a snapshot of five days old will be the version of that
file that existed five days ago, even if the file was modified or even
deleted since then.

=head2 Series and MRS

Snapshot.pm keeps a configurable number of snapshots in so called I<series>.
A series is defined as a number of snapshots using a common naming scheme
and following each other chronologically. One could for example imagine a
series to consist of daily snapshots. Multiple series can be defined and
handled by Snapshot.pm.

The most recent snapshot (MRS) is treated specially. It is the same for all
series and is named seperately from the series. It is also not included in
the count of series snapshots to keep.


                  +------+    +------+    +------+
               +--| S1_1 | -- | S1_2 | -- | S1_3 |
              /   +------+    +------+    +------+
  +-----+    /
  | MRS | --+
  +-----+    \
              \   +------+    +------+    +------+    +------+
               +--| S2_1 | -- | S2_2 | -- | S2_3 | -- | S2_4 |
                  +------+    +------+    +------+    +------+

The figure represents a snapshot scheme consisting of two series - S1 and S2
(the names are configurable). S1 is defined to keep 3 snapshots, S2 keeps 4.
When the do_snapshot() routine is called with these parameters, it will
first rotate the series snapshots:

  S1_3  ==>  Deleted
  S1_2  ==>  S1_3
  S1_1  ==>  S1_2
  MRS   ==>  S1_1
  
... and analogously for S2. After this, the MRS will be updated to reflect
the current state of the directory tree from which the snapshot is taken
(using rsync).

The rotation of MRS to first series member is done by hardlinking files.
This, combined with the fact that rsync creates new versions of modified
files instead of modifying them in place, is where all the magic of this
snapshot method lies.

After the rotations and the snapshot are done, a timetag file is written in
the MRS. This timetag file has a timestamp of just before the rsync step was
started, and contains that time formatted as by C<ctime(3)> (or, more
precisely, as the output from C<localtime> in scalar context). This is done
to ensure that one has a reference point as to the age of the snapshot: the
versions of the files in that snapshot are guaranteed to be those of the
time recorded in the timetag (or later, to be precise). The timetags are not
changed by the series rotation process.

=head2 do_snapshot()

The core routine of Snapshot.pm, and the only one exported is
C<do_snapshot()>. This has to be imported explicitely:

  use Snapshot qw/do_snapshot/;

C<do_snapshot()> is called with a hash or reference to a hash as argument.
This hash lists configuration keys and values. Available keys and values
are listed below. Mandatory options are marked with *.

=over 2

=item source *

The directory tree to take a snapshot from. Trailing slashes
are optional.


=item snapshot_dir *

The directory where the snapshots are located. MRS and
series snapshots are located in this directory.

=item series      

A reference to an array containing hashrefs for series
configuration. Should contain one hashref per series, with mandatory keys
'stub' and 'keep'. stub is the name of the series (number will be appended),
keep is how many snapshots should be kept in the series, excluding MRS.

Default: C<[ { 'stub' => 'daily_', 'keep' => 6 } ]>

=item verbose

When set to a true value, C<Snapshot.pm> becomes talkative. Currently this
only means that you get the output of the rsync step on STDOUT.

Default: false

=item MRS     

The name of the Most Recent Snapshot.

Default: current

=item exclude

A reference to an array listing file patterns to exclude or include. This is
passed on to the rsync stage, and goes straight through to L<File::Rsync>.

Default: empty

=item rsync_args

A hash reference of extra arguments to L<File::Rsync>. Any valid option to
File::Rsync will work, and will override options set through other means,
notably C<verbose> and C<delete>. For the sake of the integrity of your
snapshots, you are advised to know what you are doing when you fiddle with
these.

Default: empty

=item fatal_errors

When set to true, any error encountered will result in an exception being
thrown. You can catch this with C<eval> and examine C<$@> in the usual way.

Default: false

=item timetag

The filename of the timetag file.

Default: .snaptime

=back

=head1 RETURN VALUE

C<Snapshot.pm> returns the output from the rsync step in a scalar if all
goes well.

In case of an error, false is returned and $Snapshot::error will contain a
more or less informative message loosely related to the cause of the
error.

Unless asked to do so, C<Snapshot.pm> should never throw exceptions.

=head1 PORTABILITY

This version is restricted to platforms that have cp -al. That probably
means Unix. Later versions will cater for additional platforms, namely those
that support the link function and the L</File::Find> module.

=head1 DEPENDENCIES

Snapshot.pm uses these non standard modules:

  File::Rsync

=head1 SNAPSHOT METHOD

C<Snapshot.pm> uses a method from Hack #74 in Linux Server Hacks. The method
is based on hard links and the fact that rsync creates new versions of files
it modifies, as opposed to modifying them in place.

The magic is in the copy step from MRS to the first series member. This step
is done using C<cp -al>, which creates hardlinks (C<-l>) of the files
instead of straight copies. If a file F is later changed in the MRS, the
hardlink still points to the I<original> version of it: rsync does an unlink
on it, which decreases the reference count of the inode. The inode does not
wink out of existence, as there still is a reference to it created by hard
linking to it during the copy step.

Rotating the series elements is done with a simple C<move> (there is no need
to take more hard links).

The beauty of this method is that the copy step from MRS to S1 is a true
snapshot: only directories are actually created in S1, the files are simply
hard links. When files in the MRS are subsequently changed, only the changed
files will take up extra space on the disk. So for each snapshot, you only
need extra space for the files that have changed compared with the MRS.

=head1 SEE ALSO

L<File::Rsync> -- Documentation for the File::Rsync module
L<http://www.oreilly.com/catalog/linuxsvrhack/> -- Linux Server Hacks book

=head1 AUTHOR

Bart Vetters, L<robartes@nirya.be>

=head1 Copyrights

Copyright (c) 2003 Bart Vetters.  All rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


=cut

use strict;
use warnings;

package Snapshot;
require Exporter;
our @ISA = qw/Exporter/;
use File::Rsync;
use File::Copy;
use File::Path;

our @EXPORT_OK=qw/do_snapshot/;
our $VERSION="0.02";

my $globals;
our $error;
my %rsync_out;

sub do_snapshot {

  my $config = parse_args(@_) or return 0;

  rotate_series($config->{'snapshot_dir'},
                $config->{'MRS'},
                $config->{'series'},
                $config->{'num_series'},
               ) or return 0;
  my $now=localtime();
  my $retval=do_sync($config->{'source'},
                     $config->{'snapshot_dir'},
                     $config->{'MRS'},
                     $config->{'exclude'},
                     $config->{'rsync_args'},
                    ) or return 0;
  chdir $config->{'snapshot_dir'}.$config->{'MRS'} or return _croak("This is weird: MRS is not accessible after snapshot: $!\n");
  unlink $config->{'timetag'} if (-f $config->{'timetag'});
  if (open TIMETAG, ">".$config->{'timetag'} ) {
    print TIMETAG $now."\n" or _warn("Could not write snapshot time to timetag file. Snapshot has been taken successfully though.\n");
    close TIMETAG;
  } else {
    _warn("Could not write snapshot time to timetag file. Snapshot has been taken successfully though.\n");
  }
  return $retval;
}

sub parse_args {

  my %allowed_args = ( 'source' => undef,
                       'snapshot_dir' => undef,
                       'exclude' => undef,
                       'MRS' => 'current',
                       'series' => [ { 'stub' => 'daily_',
                                       'keep' => 6,
                                   } ],
                       'rsync_args' => undef,
                       'fatal_errors' => undef,
                       'verbose' => undef,
                       'timetag' => '.snaptime'
                     );
  my @mandatory_args = qw /source snapshot_dir/;
  my @global_flags=qw/fatal_errors verbose/;

  my @args=@_;
  my %config;

  eval {
    if ( ref($args[0]) ) { 
      my $hashref=$args[0];
      %config = %$hashref;
    } else {
      %config=@args;
    }
  };

  if ($@) {return _croak("Please give a hashref or hash as arguments.\n") };

  foreach my $key (keys(%config)) {
    return _croak("Unknown argument: $key.\n") unless exists $allowed_args{$key};
    $allowed_args{$key}=$config{$key};
  }

  foreach (@mandatory_args)  {
    return _croak("Missing arg: $_\n") unless defined ( $allowed_args{$_} );
  }

  foreach (@global_flags) {
    $globals->{$_}=$allowed_args{$_};
  }

  $allowed_args{'source'} =~ s|([^/])$|$1/|;
  $allowed_args{'snapshot_dir'} =~ s|([^/])$|$1/|;

  return \%allowed_args;

}

sub rotate_series {

  my ($directory, $current, $series, $num_series) = @_;

  chdir $directory or return _croak("Problem accessing snapshot directory: $!\n");
  
  if (defined ($num_series)) {
    return _croak("Invalid number of series: $num_series\n") if ( $num_series < 1 );
    return _croak("Not enough series data.\n") if ( scalar @$series < $num_series );
  } else {
    $num_series = @$series;
  }

  for (0 .. ($num_series - 1)) {
    my $stub=$series->[$_]{'stub'};
    my $keep=$series->[$_]{'keep'};
    rotate_files($stub,$keep,$current) or return 0;
  }

  return 1;
  
}

sub rotate_files {

  my ($stub, $max, $current) = @_;

  return _croak("Invalid number of snapshots to retain: $max\n") if ($max < 1);
  _warn("Only 1 version to keep. No rotating of files will be done.\n") if $max == 1;

  my $maxdir="$stub$max";
  if ( -d $maxdir ) {
    rmtree($maxdir,0,1) or return _croak("Could not delete $stub$max\n");
  };
  if ($max > 2 ) {
    my $x=($max - 1);
    while  ($x) {
      if ( -d $stub.$x ) {
        move( $stub.$x, $stub.( $x + 1 ) ) or return _croak("A move went wrong: $!\nI'm aborting to avoid possible data corruption.\nThe move that failed is $stub$x to $stub".( $x + 1 )."\n");
      }
      $x--;
    }
  }

  my $target=$stub."1";
  if ( -d $current) {
    return _croak("Problem with copy step: ".($? >> 8) ."\n") if system("cp -al $current/ $target");
  } else {
    _warn("No MRS found. Will be created in rsync step.\n");
  }
  return 1; 
}

sub do_sync {

  my ($source, $snapshot_dir, $current, $exclude, $rsync_args) = @_;
  my $dest=${snapshot_dir}.$current;
  my %extra_args;

  if (defined($rsync_args)) {
    eval { %extra_args = %$rsync_args };
    return _croak("Problem with extra rsync args: $@\n") if ($@);
  }

  unless (defined($extra_args{'exclude'})) {
    $extra_args{'exclude'}=$exclude if defined($exclude);
  }

  my $rsync = File::Rsync -> new(archive => 1,
                                 update => 1,
                                 compress => 1,
                                 verbose => 1,
                                 delete => 1,
                                 outfun => \&rsync_output,
                                 errfun => \&rsync_output,
                                 %extra_args,
                                );
  $rsync->exec ( { 'src' => $source, 'dest' => $dest } ) or return _croak("Rsync failed: ".$rsync_out{'err'}."\n");
  return $rsync_out{'out'};

}

sub rsync_output {

  my ($message,$type)=@_;

  $rsync_out{$type}.="$message\n";
  print $message if ( defined($globals->{'verbose'}) && $globals->{'verbose'});

}

sub _warn {

  my $message=shift;
  print STDERR $message;

}

sub _croak {

  $error=shift;
  die $error if $globals->{'fatal_errors'};
  return 0;

}

# I am a good little module
1;
