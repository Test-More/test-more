use strict;
use warnings;

use Test::Stream::Tester;
use Test::Stream::Util qw/
    try protect

    get_tid USE_THREADS

    pkg_to_file
/;

for my $protect (\&protect, Test::Stream::Util->can('_manual_protect'), Test::Stream::Util->can('_local_protect')) {
    local $! = 100;
    my $ok = eval { $protect->(sub { die "xxx" }); 1 };
    ok($! == 100, "\$! did not change");
    ok(!$ok, "protect did not capture exception");
    like($@, qr/xxx/, "expected exception");

    local $! = 100;
    local $@ = 'apple';
    $ok = $protect->(sub { 1 });
    ok($! == 100, "\$! did not change");
    like($@, qr/apple/, '$@ has not changed');
}

for my $try (\&try, Test::Stream::Util->can('_manual_try'), Test::Stream::Util->can('_local_try')) {
    local $! = 100;
    local $@ = 'foo';
    my ($ok, $err) = $try->(sub { die "xxx" });
    ok(!$ok, "cought exception");
    like( $err, qr/xxx/, "expected exception");
    is($@, 'foo', '$@ is saved');
    ok($! == 100, "\$! did not change");

    ($ok, $err) = $try->(sub { 0 });
    ok($ok, "Success");
    ok(!$err, "no error");
    is($@, 'foo', '$@ is saved');
    ok($! == 100, "\$! did not change");
}

is(pkg_to_file('A::Package::Name'), 'A/Package/Name.pm', "Converted package to file");

done_testing;
