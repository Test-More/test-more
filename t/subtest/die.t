#!/usr/bin/perl -w

# What happens when a subtest dies?

use lib 't/lib';

use strict;
use Test::Builder::NoOutput;

BEGIN { require "t/test.pl" }

note "death of a subtest"; {
    my $tb = Test::Builder::NoOutput->create;

    $tb->ok(1);

    ok( !eval {
        $tb->subtest("death" => sub {
            die "Death in the subtest";
        });
        1;
    });
    like( $@, qr/^Death in the subtest at $0 line /);
}


done_testing();
