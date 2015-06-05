use strict;
use warnings;

use Test::More;

use ok 'Test::Stream::Util', qw{
    try protect
};

can_ok(__PACKAGE__, qw{
    try protect
});

$! = 100;

my $ok = eval { protect { die "xxx" }; 1 };
ok(!$ok, "protect did not capture exception");
like($@, qr/xxx/, "expected exception");

ok($! == 100, "\$! did not change");

$@ = 'foo';
($ok, my $err) = try { die "xxx" };
ok(!$ok, "cought exception");
like( $err, qr/xxx/, "expected exception");
is($@, 'foo', '$@ is saved');
ok($! == 100, "\$! did not change");

done_testing;
