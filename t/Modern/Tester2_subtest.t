use strict;
use warnings;
use utf8;

use Test::More qw/modern/;
use Test::Tester2;

my $events = intercept {
    ok(0, "test failure" );
    ok(1, "test success" );

    subtest 'subtest' => sub {
        ok(0, "subtest failure" );
        ok(1, "subtest success" );

        subtest 'subtest_deeper' => sub {
            ok(0, "deeper subtest failure" );
            ok(1, "deeper subtest success" );
        };
    };

    ok(0, "another test failure" );
    ok(1, "another test success" );
};

events_are(
    $events,

    check {
        event ok   => {bool => 0};
        event diag => {};
        event ok   => {bool => 1};

        event child => {action => 'push'};
        event     note => {message => 'Subtest: subtest'};
        event     ok   => {bool => 0};
        event     diag => {};
        event     ok   => {bool => 1};

        event     child => {action => 'push'};
        event         note => {message => 'Subtest: subtest_deeper'};
        event         ok   => {bool => 0};
        event         diag => {};
        event         ok   => {bool => 1};

        event         plan   => {};
        event         finish => {};

        event         diag => {tap  => qr/Looks like you failed 1 test of 2/};
        event     child => {action => 'pop'};
        event     ok   => {bool => 0};
        event     diag => {};

        event     plan   => {};
        event     finish => {};

        event     diag => {tap  => qr/Looks like you failed 2 tests of 3/};
        event child => {action => 'pop'};
        event ok   => {bool => 0};
        event diag => {};

        event ok   => {bool => 0};
        event diag => {};
        event ok   => {bool => 1};

        dir end => "subtest events as expected";
    }
);

done_testing;
