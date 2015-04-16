use strict;
use warnings;

use Test::More;
use Test::Stream::Tester;

events_are(
    intercept {
        diag "foo", "bar", "baz";
        note "flub", "bub", "dub";
    },
    check {
        event diag => { message => "foobarbaz" };
        event note => { message => "flubbubdub" };
        directive 'end';
    },
    "All args to diag and note get joined"
);

done_testing;
