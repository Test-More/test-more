use strict;
use warnings;
use utf8;

use Test::More qw/utf8/;
use Test::Tester2;

BEGIN {
    my $norm = eval { require Unicode::Normalize; 1 };
    plan skip_all => 'Unicode::Normalize is required for this test' unless $norm;
}

my $results = intercept {
    my $orig = tap_encoding;
    tap_encoding 'utf8';
    ok(0, "test failure" );

    subtest 'subtest' => sub {
        ok(0, "sub test failure" );
    };

    tap_encoding 'legacy';
    ok(0, "legacy failure");
    tap_encoding($orig);
};

my $legacy_name = __FILE__;
my $utf8_name = Unicode::Normalize::NFKC('encoding_tést.t');
results_are(
    $results,

    ok   => {bool => 0},
    diag => {tap  => qr/\Q$utf8_name\E/},

    child => {action => 'push'},

        ok   => {bool => 0},
        diag => {tap  => qr/\Q$utf8_name\E/},

        plan   => {},
        finish => {},

        diag => {tap  => qr/Looks like you failed 1 test of 1/},
        ok   => {bool => 0,},
        diag => {tap  => qr/\Q$utf8_name\E/},

    child => {action => 'pop'},

    ok   => {bool => 0},
    diag => {tap  => qr/\Q$legacy_name\E/},

    end => "Encoding is honored by the stack tracing",
);

done_testing;
