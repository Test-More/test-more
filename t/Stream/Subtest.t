use strict;
use warnings;

use Test::More;
use Test::Stream 'Intercept', Compare => ['-all', like => {-as => 'ts_like'}, is => {-as => 'ts_is'}];

my $res = intercept {
    subtest foo => sub {
        ok(1, "check");
    };
};

ts_like(
    $res,
    array {
        event Note => { message => 'Subtest: foo' };
        event Subtest => sub {
            call subevents => array {
                event Ok => { pass => 1, name => 'check' };
                event Plan => { max => 1 };
            };
            call pass => 1;
        };
    },
    "Got subtest events"
);

done_testing;
