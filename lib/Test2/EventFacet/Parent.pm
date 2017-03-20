package Test2::EventFacet::Parent;
use strict;
use warnings;

our $VERSION = '1.302079';

use Carp qw/confess/;

BEGIN { require Test2::EventFacet; our @ISA = qw(Test2::EventFacet) }
use Test2::Util::HashBase qw{ -hid -children -buffered };

sub init {
    confess "Attribute 'hid' must be set"
        unless defined $_[0]->{+HID};

    $_[0]->{+CHILDREN} ||= [];
}

1;
