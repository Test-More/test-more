use strict;
use warnings;

use Test::More 'modern';

BEGIN {
    ok(!$INC{'Carp.pm'}, "Carp is not loaded when we start");
}

use ok 'Test::Stream::Carp', 'croak';

ok(!$INC{'Carp.pm'}, "Carp is not loaded");

my $out = eval { croak "xxx"; 1 };
my $err = $@;
ok(!$out, "died");
like($err, qr/xxx/, "Got carp exception");

ok($INC{'Carp.pm'}, "Carp is loaded now");

done_testing;
