package Test2::EventFacet;
use strict;
use warnings;

our $VERSION = '1.302079';

use Test2::Util::HashBase qw/-details/;
use Carp qw/croak/;

my $SUBLEN = length(__PACKAGE__ . '::');
sub facet_key {
    my $key = ref($_[0]) || $_[0];
    substr($key, 0, $SUBLEN, '');
    return lc($key);
}

sub is_list { 0 }

sub clone {
    my $self = shift;
    my $type = ref($self);
    return bless {%$self, @_}, $type;
}

1;
