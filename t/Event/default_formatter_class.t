#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

my $CLASS = 'TB2::EventCoordinator';
use_ok $CLASS;

note "default for default_formatter_class"; {
    local $ENV{TB2_FORMATTER_CLASS};

    my $ec = $CLASS->new;
    is $ec->default_formatter_class, "TB2::Formatter::TAP";
}


note "env override"; {
    local $ENV{TB2_FORMATTER_CLASS} = "TB2::Formatter::Null";

    my $ec = $CLASS->new;
    is $ec->default_formatter_class, "TB2::Formatter::Null";
    is @{$ec->formatters}, 1;
    ok $ec->formatters->[0]->isa("TB2::Formatter::Null");
}

done_testing;
