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
        eq_or_diff("apple", "apple", "pass");
        eq_or_diff("apple", "orange", "fail");
    },
    check {
        event ok => { pass => 1, name => 'pass' };
        event ok => { pass => 0, name => 'fail' };
        event diag => { message => <<"        EOT" };
+---+---------+----------+
| Ln|Got      |Expected  |
+---+---------+----------+
*  1|'apple'  |'orange'  *
+---+---------+----------+
        EOT
        directive 'end';
    },
    "Got expected events"
);

done_testing;
