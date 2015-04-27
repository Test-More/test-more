use strict;
use warnings;
use Test::More tests => 1;
use Test::SharedFork;

BEGIN {
    die "$0 must be run with an older version of Test-Simple"
        if $INC{'Test/Stream.pm'};
}

print "# Test::More version: $Test::More::VERSION\n";
print "# PID: $$\n";

subtest "The Subtest" => sub {
    my $pid = fork;
    die "Could not fork" unless defined $pid;
    if ($pid) {
        ok(1, "In parent $$");
        waitpid($pid, 0);
    }
    else {
        sleep 1;
        ok(1, "In Child $$");
    }
};

__END__
prove -v concurrency_demos/fork_inside_subtest_noexit_legacy.pl
concurrency_demos/fork_inside_subtest_noexit_legacy.pl .. 
1..1
# Test::More version: 1.001014
# PID: 6602
    # Subtest: The Subtest
    ok 1 - In parent 6602
    ok 1 - In Child 6603
    1..1
ok 1 - The Subtest
    1..1
ok 1 - The Subtest
All 1 subtests passed 

Test Summary Report
-------------------
concurrency_demos/fork_inside_subtest_noexit_legacy.pl (Wstat: 0 Tests: 2 Failed: 1)
  Failed test:  1
  Parse errors: Tests out of sequence.  Found (1) but expected (2)
                Bad plan.  You planned 1 tests but ran 2.
Files=1, Tests=2,  1 wallclock secs ( 0.01 usr  0.00 sys +  0.04 cusr  0.00 csys =  0.05 CPU)
Result: FAIL
