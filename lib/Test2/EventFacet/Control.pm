package Test2::EventFacet::Control;
use strict;
use warnings;

our $VERSION = '1.302079';

BEGIN { require Test2::EventFacet; our @ISA = qw(Test2::EventFacet) }
use Test2::Util::HashBase qw{ -global -terminate -halt -has_callback -encoding };

1;
