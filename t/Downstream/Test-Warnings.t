use strict;
use warnings;

use Test::More;
BEGIN { plan skip_all => "Only tested when releasing" unless $ENV{AUTHOR_TESTING} };
BEGIN { eval { require Test::Warnings; 1 } || plan skip_all => ($@ =~ m/^(.*) in \@INC/g)}
use Test::Stream::Tester;
use Test::Stream::Context;
use ok 'Test::Warnings', qw/warning/;

events_are(
    intercept {
        ok(1, "pass");
        like( warning { warn "xxx" }, qr/xxx/ );
        done_testing;
    },
    check {
        event ok => { pass => 1 };
        event ok => { pass => 1 };
        event ok => { pass => 1 };
        event plan => { };
    },
    "Got expected events"
);

events_are(
    intercept {
        ok(1, "pass");
        warn "ignore this\n";
        done_testing;
    },
    check {
        event ok => { pass => 1 };
        event ok => { pass => 0 };
        event plan => { };
    },
    "Got expected events"
);

# Avoid the Test::Builder monkeypatching
Test::Stream->shared->done_testing(context());
