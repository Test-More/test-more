use strict;
use warnings;
use utf8;

use Test::More qw/modern/;
use Test::Tester2;

my $results = intercept {
    ok(0, "test failure" );

    subtest 'subtest' => sub {
        ok(0, "sub test failure" );
    };

    tap_encoding 'latin1';
    ok(0, "latin1 failure");
    tap_encoding 'utf8';
};

results_are(
    $results,

    ok   => {bool => 0},
    diag => {tap  => qr/encoding_tést\.t/},

    child => {action => 'push'},

        ok   => {bool => 0},
        diag => {tap  => qr/encoding_tést\.t/},

        plan   => {},
        finish => {},

        diag => {tap  => qr/Looks like you failed 1 test of 1/},
        ok   => {bool => 0,},
        diag => {tap  => qr/encoding_tést\.t/},

    child => {action => 'pop'},

    ok   => {bool => 0},
    diag => {tap  => qr/encoding_tÃ©st\.t/},

    end => "Encoding is honored by the stack tracing",
);

done_testing;
