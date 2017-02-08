package Test2::EventFacet::Assert;
use strict;
use warnings;

use Test2::Util::HashBase qw{ -pass -details };

sub init {
    # Normalize Pass if it is defined
    $_[0]->{+PASS} = $_[0]->{+PASS} ? 1 : 0 if exists $_[0]->{+PASS};
}

1;
