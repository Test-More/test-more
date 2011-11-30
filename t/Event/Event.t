#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use TB2::Event;

# For testing porpoises
note "Proper Event role"; {
    ok eval {
        package My::Event;

        use TB2::Mouse;
        with "TB2::Event";

        sub as_hash {
            return { foo => 42 };
        }

        sub build_event_type {
            return "dummy";
        }
    } || diag $@;
}


note "event object_id"; {
    my $e1 = My::Event->new;
    my $e2 = My::Event->new;

    ok $e1->object_id;
    ok $e2->object_id;

    isnt $e1->object_id, $e2->object_id, "event object_ids are unique";
}


note "Improper Event role";
ok !eval {
    package My::Bad::Event;

    use TB2::Mouse;
    with "TB2::Event";
};
like $@, qr/requires the method/;


note "Improper Event Type";
ok !eval {
    package My::Bad::EventType;

    use TB2::Mouse;
    with "TB2::Event";

    sub as_hash {
        return { foo => 42 };
    }

    sub build_event_type {
        return "spaces bad";
    }
};


done_testing;
