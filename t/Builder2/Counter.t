#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use TB2::Counter;
my $CLASS = "TB2::Counter";

{
    my $counter = $CLASS->new;
    isa_ok $counter, $CLASS;

    is $counter->get, 0,                "default count";
    is $counter->increment, 1,          "increment's return";
    is $counter->get, 1,                "  and increments";
    is $counter->increment(3), 4,       "  return with argument";
    is $counter->get, 4,                "  and increments";

    is $counter->set(22), 4,            "set's return";
    is $counter->get, 22,               "  and sets";

    my $other = $CLASS->new;
    is $other->get, 0,                  "create()";
    is $counter->get, 22,               "  separate object";
}


# Test bad counts
{
    # The errors from Mouse are messy, just make sure it fails
    my $count = $CLASS->new;
    ok !eval { $count->set(1.1) };
    ok !eval { $count->set(-1) };
    ok !eval { $count->set("John Belushi") };
    ok !eval { $count->set() };
}

done_testing();
