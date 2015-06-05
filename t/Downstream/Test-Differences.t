use strict;
use warnings;

use Test::Builder;
use Test::More;
use Test::Stream::Tester;
BEGIN { plan skip_all => "Only tested when releasing" unless $ENV{AUTHOR_TESTING} };
BEGIN { eval { require Test::Differences; 1 } || plan skip_all => ($@ =~ m/^(.*) in \@INC/g)}
use ok 'Test::Differences';

events_are(
    intercept {
        local $ENV{HARNESS_ACTIVE} = 0;
        eq_or_diff("apple", "apple", "pass");
        eq_or_diff("apple", "orange", "fail");
    },
    events {
        event Ok => { pass => 1, name => 'pass' };
        event Ok => { pass => 0, name => 'fail' };
        event Diag => { message => qr/Failed test/ };
        event Diag => { message => qr/at/ };
        event Diag => { message => <<"        EOT" };
+---+---------+----------+
| Ln|Got      |Expected  |
+---+---------+----------+
*  1|'apple'  |'orange'  *
+---+---------+----------+
        EOT
        end_events;
    },
    "Got expected events"
);

done_testing;
