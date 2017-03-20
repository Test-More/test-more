package Test2::EventFacet::Amnesty;
use strict;
use warnings;

our $VERSION = '1.302079';

sub is_list { 1 }

BEGIN { require Test2::EventFacet; our @ISA = qw(Test2::EventFacet) }
use Test2::Util::HashBase qw{ -tag -inherited };

1;
