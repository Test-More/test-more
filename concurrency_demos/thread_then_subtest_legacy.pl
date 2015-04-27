use strict;
use warnings;
use threads;
use Test::More;

BEGIN {
    die "$0 must be run with an older version of Test-Simple"
        if $INC{'Test/Stream.pm'};
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

done_testing;

__END__
prove -v concurrency_demos/thread_then_subtest_legacy.pl
concurrency_demos/thread_then_subtest_legacy.pl .. 
# Test::More version: 1.001014
# PID: 6638
ok 1 - In parent
ok 2 - In Child
    # Subtest: Child Subtest 6638
    ok 1 - Passing in subtest
    1..1
ok 3 - Child Subtest 6638
1..2
Failed -1/2 subtests 

Test Summary Report
-------------------
concurrency_demos/thread_then_subtest_legacy.pl (Wstat: 0 Tests: 3 Failed: 0)
  Parse errors: Bad plan.  You planned 2 tests but ran 3.
Files=1, Tests=3,  0 wallclock secs ( 0.01 usr  0.00 sys +  0.00 cusr  0.01 csys =  0.02 CPU)
Result: FAIL
