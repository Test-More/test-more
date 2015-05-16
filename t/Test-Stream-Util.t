use strict;
use warnings;

use Test::More;

use ok 'Test::Stream::Util', qw{
    try protect spoof
};

can_ok(__PACKAGE__, qw{
    try protect spoof
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

my ($ret, $e) = spoof ["The::Moon", "Moon.pm", 11] => "die 'xxx' . __PACKAGE__";
ok(!$ret, "Failed eval");
like( $e, qr/^xxxThe::Moon at Moon\.pm line 11\.?/, "Used correct package, file, and line");

done_testing;
