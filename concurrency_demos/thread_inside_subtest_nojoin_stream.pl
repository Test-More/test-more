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

my $thr;
subtest "Child Subtest $$" => sub {
    ok(1, "Passing in parent");
    $thr = threads->create(sub {
        sleep 1;
        ok(1, "In Child");
    });
};

$thr->join;

__END__
prove -v concurrency_demos/thread_inside_subtest_nojoin_stream.pl
concurrency_demos/thread_inside_subtest_nojoin_stream.pl .. 
1..1
# Test::More version: 1.301001108
# PID: 6708
# Subtest: Child Subtest 6708
    ok 1 - Passing in parent
    1..1
ok 1 - Child Subtest 6708
Attempted to send an event to subtest that has already completed.  This usually
means you started a new process or thread inside a subtest, but let the subtest
end before the child process or thread completed.
Event: Test::Stream::Event::Ok=HASH(0x13e2a18)
  # ok - In Child

# Looks like you failed 1 test of 1.
Dubious, test returned 1 (wstat 256, 0x100)
All 1 subtests passed 

Test Summary Report
-------------------
concurrency_demos/thread_inside_subtest_nojoin_stream.pl (Wstat: 256 Tests: 1 Failed: 0)
  Non-zero exit status: 1
Files=1, Tests=1,  1 wallclock secs ( 0.02 usr  0.00 sys +  0.07 cusr  0.01 csys =  0.10 CPU)
Result: FAIL
