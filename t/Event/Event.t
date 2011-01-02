#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use Test::Builder2::Event;

# For testing porpoises
note "Proper Event role"; {
    ok eval {
        package My::Event;

        use Test::Builder2::Mouse;
        with "Test::Builder2::Event";

        sub as_hash {
            return { foo => 42 };
        }

        sub event_type {
            return "dummy";
        }
    } || diag $@;
}


note "event_id"; {
    my $e1 = My::Event->new;
    my $e2 = My::Event->new;

    ok $e1->event_id;
    ok $e2->event_id;

    isnt $e1->event_id, $e2->event_id, "event_ids are unique";
}


note "Improper Event role";
ok !eval {
    package My::Bad::Event;

    use Test::Builder2::Mouse;
    with "Test::Builder2::Event";
};
like $@, qr/requires the methods/;


done_testing;
