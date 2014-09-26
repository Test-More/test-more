use strict;
use warnings;

BEGIN {
    if ($INC{'Carp.pm'}) {
        print "1..0 # Carp is already loaded before we even begin.\n";
        exit 0;
    }
}

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
