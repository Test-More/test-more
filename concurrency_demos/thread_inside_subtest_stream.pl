use strict;
use warnings;
use threads;
use Test::More tests => 1;
use Test::Stream::Concurrency;

BEGIN {
    die "$0 must be run with a newer version of Test-Simple"
        unless $INC{'Test/Stream.pm'};
}

print "# Test::More version: $Test::More::VERSION\n";
print "# PID: $$\n";

subtest "Child Subtest $$" => sub {
    ok(1, "Passing in parent");
    my $thr = threads->create(sub {
        ok(1, "In Child");
    });
    $thr->join;
};

__END__
prove -v concurrency_demos/thread_inside_subtest_stream.pl
concurrency_demos/thread_inside_subtest_stream.pl .. 
1..1
# Test::More version: 1.301001108
# PID: 6713
# Subtest: Child Subtest 6713
    ok 1 - Passing in parent
    ok 2 - In Child
    1..2
ok 1 - Child Subtest 6713
ok
All tests successful.
Files=1, Tests=1,  0 wallclock secs ( 0.01 usr  0.00 sys +  0.06 cusr  0.00 csys =  0.07 CPU)
Result: PASS
