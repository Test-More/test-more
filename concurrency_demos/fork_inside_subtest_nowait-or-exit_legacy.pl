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

my $pid;
subtest "The Subtest" => sub {
    $pid = fork;
    die "Could not fork" unless defined $pid;
    if ($pid) {
        ok(1, "In parent $$");
    }
    else {
        sleep 1;
        ok(1, "In Child $$");
    }
};

# This is to demonstrate behavior when the child does not exit, and the subtest
# does not wait. See the parent_ends_before_* demos for what happens when the
# parent exits before the child.
waitpid($pid, 0);

__END__
prove -v concurrency_demos/fork_inside_subtest_nowait-or-exit_legacy.pl
concurrency_demos/fork_inside_subtest_nowait-or-exit_legacy.pl .. 
1..1
# Test::More version: 1.001014
# PID: 6612
    # Subtest: The Subtest
    ok 1 - In parent 6612
    1..1
ok 1 - The Subtest
    ok 1 - In Child 6613
    1..1
ok 1 - The Subtest
All 1 subtests passed 

Test Summary Report
-------------------
concurrency_demos/fork_inside_subtest_nowait-or-exit_legacy.pl (Wstat: 0 Tests: 2 Failed: 1)
  Failed test:  1
  Parse errors: Tests out of sequence.  Found (1) but expected (2)
                Bad plan.  You planned 1 tests but ran 2.
Files=1, Tests=2,  1 wallclock secs ( 0.01 usr  0.00 sys +  0.03 cusr  0.00 csys =  0.04 CPU)
Result: FAIL
