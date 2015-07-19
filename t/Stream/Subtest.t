use strict;
use warnings;

use Test::More;
use Test::Stream::Tester;

use Data::Dumper;

my $res = intercept {
    subtest foo => sub {
        ok(1, "check");
    };
};

events_are(
    $res,
    events {
        event Note => { message => 'Subtest: foo' };
        event Subtest => sub {
            event_call subevents => events {
                event Ok => { pass => 1, name => 'check' };
                event Plan => { max => 1 };
            };
            event_call pass => 1;
        };
    },
    "Got subtest events"
);

done_testing;
