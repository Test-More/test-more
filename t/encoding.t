use strict;
use warnings;

BEGIN {
    unshift @INC, 't/lib';
};

use Test::More;

use Test::Builder;
use Test::Builder::NoOutput;

use Encode;

my $perl_char = {
    A => "\x{0100}",
    D => "\x{00D0}",
};

my $byte_char = {
    A => encode( 'UTF-8', $perl_char->{A} ),
    D => encode( 'UTF-8', $perl_char->{D} ),
};

my @warnings;
local $SIG{__WARN__} = sub {
    push @warnings, @_;
};

# subtest test
my $tb = Test::Builder::NoOutput->create;
$tb->tap_encoding('UTF-8');
$tb->plan(tests => 2);
$tb->ok(1, 'main - ' . $perl_char->{A});
$tb->subtest('encoding subtest', sub {
    ok(1, 'sub - ' . $perl_char->{D});
});

my $msg = $tb->read;
like($msg, qr/main - $byte_char->{A}/, 'wide character test message');
like($msg, qr/sub - $byte_char->{D}/, 'wide character test message - subtest');


# warning test
is_deeply( \@warnings, [], 'no wide character warnings' );

done_testing;
