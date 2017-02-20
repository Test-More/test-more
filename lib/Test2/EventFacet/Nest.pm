package Test2::EventFacet::Nest;
use strict;
use warnings;

use Carp qw/confess/;

use Test2::Util::HashBase qw{ -id -buffered -events };

sub init {
    confess "Attribute 'id' must be set"
        unless defined $_[0]->{+ID};
}

1;
