use strict;
use warnings;
use threads;
use Test::More tests => 3;
use Test::Stream::Concurrency;

BEGIN {
    die "$0 must be run with a newer version of Test-Simple"
        unless $INC{'Test/Stream.pm'};
}

print "# Test::More version: $Test::More::VERSION\n";
print "# PID: $$\n";

ok(1, "In parent");
my $thr = threads->create(sub {
    ok(1, "In Child");
    subtest "Child Subtest $$" => sub {
        ok(1, "Passing in subtest");
    };
});
$thr->join;

__END__
prove -v concurrency_demos/thread_then_subtest_stream.pl
concurrency_demos/thread_then_subtest_stream.pl .. 
1..3
# Test::More version: 1.301001108
# PID: 6716
ok 1 - In parent
    ok 1 - Passing in subtest
    1..1
ok 2 - In Child
# Subtest: Child Subtest 6716
ok 3 - Child Subtest 6716
ok
All tests successful.
Files=1, Tests=3,  0 wallclock secs ( 0.02 usr  0.00 sys +  0.07 cusr  0.00 csys =  0.09 CPU)
Result: PASS
