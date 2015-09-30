use strict;
use warnings;

use Test::More;
BEGIN { plan skip_all => "Only tested when releasing" unless $ENV{AUTHOR_TESTING} };
BEGIN { eval { require Test::Deep; 1 } || plan skip_all => ($@ =~ m/^(.*) in \@INC/g)}
use Test::Stream 'Intercept', 'Compare' => [qw/event/, array => {-as => 'events'}, like => {-as => 'events_are'}];
use ok 'Test::Deep';

events_are(
    intercept {
        local $ENV{HARNESS_ACTIVE} = 0;
        cmp_deeply({a => [ 1, 2, 3 ], b => 'foo'}, {a => [ 1, 2, 3 ], b => 'foo'});
        cmp_deeply({a => [ 1, 2, 3 ], b => 'fot'}, {a => [ 1, 2, 3 ], b => 'foo'});
    },
    events {
        event Ok => { pass => 1 };
        event Ok => { pass => 0 };
        event Diag => { message => qr/Failed test at/ };
        event Diag => { message => <<'        EOT' };
Compared $data->{"b"}
   got : 'fot'
expect : 'foo'
        EOT
    },
    "Got expected events"
);

done_testing;
