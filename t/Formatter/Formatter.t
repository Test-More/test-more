#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use TB2::Formatter;

# For testing porpoises
note "Formatter Subclass"; {
    ok eval {
        package My::Formatter;

        use TB2::Mouse;
        extends "TB2::Formatter";

    } || diag $@;
}


note "formatter object_id"; {
    my $f1 = My::Formatter->new;
    my $f2 = My::Formatter->new;

    ok $f1->object_id;
    ok $f2->object_id;

    isnt $f1->object_id, $f2->object_id, "formatter object_ids are unique";
}


done_testing;
