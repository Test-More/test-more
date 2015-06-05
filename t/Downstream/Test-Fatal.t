use strict;
use warnings;

use Test::More;
BEGIN { plan skip_all => "Only tested when releasing" unless $ENV{AUTHOR_TESTING} };
BEGIN { eval { require Test::Fatal; 1 } || plan skip_all => ($@ =~ m/^(.*) in \@INC/g)}
use Test::Stream::Tester;
use ok 'Test::Fatal';

events_are(
    intercept {
        ok(1, "pass");
        like( exception { die "xxx" }, qr/xxx/ );
        is( exception { 1 }, undef );
    },
    events {
        event Ok => { pass => 1 };
        event Ok => { pass => 1 };
    },
    "Got expected events"
);

done_testing;
