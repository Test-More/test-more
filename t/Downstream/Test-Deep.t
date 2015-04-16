use strict;
use warnings;

use Test::More;
use Test::Stream::Tester;
BEGIN { plan skip_all => "Only tested when releasing" unless $ENV{AUTHOR_TESTING} };
BEGIN { eval { require Test::Deep; 1 } || plan skip_all => ($@ =~ m/^(.*) in \@INC/g)}
use ok 'Test::Deep';

events_are(
    intercept {
        cmp_deeply({a => [ 1, 2, 3 ], b => 'foo'}, {a => [ 1, 2, 3 ], b => 'foo'});
        cmp_deeply({a => [ 1, 2, 3 ], b => 'fot'}, {a => [ 1, 2, 3 ], b => 'foo'});
    },
    check {
        event ok => { pass => 1 };
        event ok => { pass => 0 };
        event diag => { message => <<'        EOT' };
Compared $data->{"b"}
   got : 'fot'
expect : 'foo'
        EOT
    },
    "Got expected events"
);

done_testing;
