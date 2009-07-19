#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;

use Test::Builder2::Counter;
my $CLASS = "Test::Builder2::Counter";

{
    my $counter = $CLASS->singleton;
    isa_ok $counter, $CLASS;

    is $counter->get, 1,                "default count";
    is $counter->increment, 1,          "increment's return";
    is $counter->get, 2,                "  and increments";
    is $counter->increment(3), 2,       "  return with argument";
    is $counter->get, 5,                "  and increments";

    is $counter->set(22), 5,            "set's return";
    is $counter->get, 22,               "  and sets";

    is $CLASS->singleton->get, 22,      "singleton()";

    my $other = $CLASS->create;
    is $other->get, 1,                  "create()";
    is $counter->get, 22,               "  separate object";
}


# Test the non-existance of new()
{
    ok !eval { $CLASS->new };
    like $@, qr/there is no new/;
}


# Test bad counts
{
    # The errors from Mouse are messy, just make sure it fails
    my $count = $CLASS->create;
    ok !eval { $count->set(1.1) };
    ok !eval { $count->set(-1) };
    ok !eval { $count->set("John Belushi") };
    ok !eval { $count->set() };
}

done_testing();
