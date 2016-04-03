#!/usr/bin/perl
#
# Listen to failed ssh attempts (from journalctl) and immediately blocks the offending IP addresses
# using iptables.
#
# This is meant to be put in root's crontab, but it can also be run manually to see what happens.
#
# A typical crontab entry is:
# * * * * * block-ssh-attacks.pl >> /var/log/block-ssh-attacks.log 2>&1
#
# Note that it uses a file lock, so only one instance can run at a time.
#
# Caveats: over time, this potentially fills up the iptables with a bunch of rules
# We should remove old entries at some point.  That said, the entries are not
# persisted, so they would disappear at the next reboot.

use strict;
use warnings FATAL => 'all';
use POSIX qw(strftime);

# obtain our file lock or exit
use Fcntl qw(:flock);
my $lockfile = '/tmp/block-ssh-attacks.lock';
open(my $fhpid, '>', $lockfile) or die "error: open '$lockfile': $!";
flock($fhpid, LOCK_EX|LOCK_NB) or exit;

# autoflush output
$| = 1;

my %n;

# start listening to journalctl, and immediately ban intruders
open(J, 'journalctl -f -u sshd|') || die "Couldn't listen to journalctl: $!\n";
while (<J>) {
    next unless /connection closed by ([\d\.]+) \[preauth\]/i;
    $_=$1;
    next if $n{$_}++;
    printf("%s: ban %s\n", strftime("%F %T", localtime(time)), $_);
    qx{iptables -A INPUT -s $_ -j DROP};
}
