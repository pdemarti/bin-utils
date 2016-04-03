#!/usr/bin/perl
#----------------------------------------------------------------------
# PD 20131124
#
# This goes and modifies the rhytmbox .xml files to:
# 1) normalize location
# 2) dedup entries (among siblings of <location>;for example,
#    in playlist.xml, the locations among the children of <playlist...> are deduped;
#    in rhythmboxdb.xml, the location among entries are deduped).
#
# Note: if $(gsettings get org.gnome.rhythmbox.rhythmdb locations) doesn't look right, then:
# gsettings set org.gnome.rhythmbox.rhythmdb locations "['file:///data/home/pierred/Music']"
#
#----------------------------------------------------------------------

#use open qw/:std :utf8/;
use XML::Twig;

my $xmlfile = shift @ARGV;	# the file to parse

# in playlist.xml, we dedup locations under <playlist>
# in rhythmboxdb.xml, we dedup locations under <rhythmdb> (in this case
# it is the grandparent of <location>, because there is one <entry> per
# location, so the direct parent is <entry>)
my $t= XML::Twig->new
  (twig_roots =>
   {'location' => \&proc_location,
    'playlist' => \&proc_loc_parent,
    'entry'    => \&proc_loc_parent,
   },
   keep_encoding => 1,
   twig_print_outside_roots => 1, # print the rest
   pretty_print => 'indented',
  );
$t->parsefile($xmlfile);

# this contains locations under some parent (typically we try to delete the array once we've processed a parent)
# locations are deduped among the children of a parent.
our $bags = {};

sub proc_location {
    my ($t, $loc)= @_;
    my $txt = $loc->text;
    $txt =~ s,file:///home,file:///data/home,g;
    $loc->set_text($txt);
    my $parent = $loc->parent;
    my $bag = $parent; # object among which we look for duplicates
    if ($parent->name eq 'entry' && $parent->{att}->{type} eq 'song') {
	# note: we explicitely handle only the songs. This excludes deduping other entries such as 'hidden'
	$bag = $parent->parent;
    }
    if ($bags->{$bag}->{$txt}++) {
	$loc->delete;
    }
}

sub proc_loc_parent {
    my ($t, $el)= @_;
    # remember this is called at the end of processing an element (here: parents of location)
    delete $bags->{$el}; # purge the deduplication bag for this element, we won't use it

    # then we print this item, but only if it has a location (remember: location deleted if found duplicate)
    if ($el->has_child('location')) {
	$el->flush;
    } else {
	$el->delete;
    }
}
