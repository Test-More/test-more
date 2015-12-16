use strict;
use warnings;

BEGIN { require "t/tools.pl" };
use Test2::Util qw/
    try

    get_tid USE_THREADS

    pkg_to_file

    CAN_FORK
    CAN_THREAD
    CAN_REALLY_FORK
/;

{
    local $! = 100;
    local $@ = 'foo';

    for my $try (\&try, Test2::Util->can('_manual_try'), Test2::Util->can('_local_try')) {
        ok($! == 100, "\$! initially set");
        ok($! == 100, "\$! not modified by the 'ok' on the previous line");

        my ($ok, $err) = $try->(sub { die "xxx" });
        ok(!$ok, "cought exception");
        like($err, qr/xxx/, "expected exception");
        is($@, 'foo', '$@ is saved');
        ok($! == 100, "\$! did not change", int($!), "$!");

        ($ok, $err) = $try->(sub { 0 });
        ok($ok,   "Success");
        ok(!$err, "no error");
        is($@, 'foo', '$@ is saved');
        ok($! == 100, "\$! did not change");
    }
}

is(pkg_to_file('A::Package::Name'), 'A/Package/Name.pm', "Converted package to file");

# Make sure running them does not die
# We cannot really do much to test these.
CAN_THREAD();
CAN_FORK();
CAN_REALLY_FORK();

done_testing;
