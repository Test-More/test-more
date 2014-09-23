use strict;
use warnings;
no utf8;

use Test::More qw/modern/;
use Test::Tester2;

BEGIN {
    my $norm = eval { require Unicode::Normalize; require Encode; 1 };
    plan skip_all => 'Unicode::Normalize is required for this test' unless $norm;
}

my $filename = "encoding_tést.t";
ok(!utf8::is_utf8($filename), "filename is not in utf8 yet");
my $utf8name = Unicode::Normalize::NFKC(Encode::decode('utf8', "$filename", Encode::FB_CROAK));
ok( $filename ne $utf8name, "sanity check" );

my $scoper = sub { context()->snapshot };

tap_encoding 'utf8';
my $ctx_utf8 = $scoper->();
$ctx_utf8->frame->[1] = $filename;

tap_encoding 'legacy';
my $ctx_legacy = $scoper->();;
$ctx_legacy->frame->[1] = $filename;

is($ctx_utf8->encoding,   'utf8',   "got a utf8 context");
is($ctx_legacy->encoding, 'legacy', "got a legacy context");

my $diag_utf8 = Test::Stream::Event::Diag->new(
    $ctx_utf8,
    [],
    0,
    "failed blah de blah\nFatal error in $filename line 42.\n",
);

my $diag_legacy = Test::Stream::Event::Diag->new(
    $ctx_legacy,
    [],
    0,
    "failed blah de blah\nFatal error in $filename line 42.\n",
);

ok( $diag_legacy->to_tap->[1] ne $diag_utf8->to_tap->[1], "The utf8 diag has a different output" );

is(
    $diag_legacy->to_tap->[1],
    "# failed blah de blah\n# Fatal error in $filename line 42.\n",
    "Got unaltered filename in legacy"
);

# Change encoding for the scope of the next test so that errors make more sense.
tap_encoding 'utf8' => sub {
    is(
        $diag_utf8->to_tap->[1],
        "# failed blah de blah\n# Fatal error in $utf8name line 42.\n",
        "Got transcoded filename in utf8"
    );
};

{
    my $file = __FILE__;
    my $success = eval { tap_encoding 'invalid_encoding'; 1 }; my $line = __LINE__;
    chomp(my $error = $@);
    ok(!$success, "Threw an exception when using invalid encoding");
    like($error, qr/^encoding 'invalid_encoding' is not valid, or not available at $file line $line/, 'validate encoding');
};



done_testing;
