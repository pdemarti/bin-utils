#!/usr/bin/perl
#
# Get the text from an html file or an http URL
# PD 20140522 -- start

use Getopt::Std;
use IO::HTML;
use HTML::TreeBuilder;
use HTML::FormatText;
use charnames qw(:full);
use open qw/:std :utf8/;
use Unicode::Normalize;

sub err_usage {
  print STDERR "
$0 -- Get an html file or fetch the html from an http URL, then print out the text elements.
Usage is:
$0 [options] [file|http-url]
Options:
    None for now.
";
  exit @_;
}

err_usage(200) unless getopts('h');
err_usage(0) if $opt_h;

binmode STDOUT, ":encoding(utf8)";
for my $arg (@ARGV) {
    my $tree;
    if ($arg=~m,^http://,) {
	$tree = HTML::TreeBuilder->new_from_url($arg) or die "can't build tree: $!\n";
    } elsif ($notused) {
	# old method that doesn't work well with UTF-8
	use HTTP::Lite;
	my $http = new HTTP::Lite;
	my $req = $http->request($arg) or die "Unable to get URL $arg: $!";
	die "Request failed ($req): ".$http->status_message() if $req ne "200";
	my $body = $http->body();
	$tree = HTML::TreeBuilder->new_from_content($body) or die "can't build tree: $!\n";
    } else {
	$tree = HTML::TreeBuilder->new_from_file(html_file($arg)) or die "can't build tree from file $arg: $!\n";
    }
    my $formatter = HTML::FormatText->new(leftmargin => 0, rightmargin => 120);
    print $formatter->format($tree);
}
1;
