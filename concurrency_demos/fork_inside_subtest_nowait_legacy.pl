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
        exit 0;
    }
};

# This is to demonstrate behavior when the child does not exit, and the subtest
# does not wait. See the parent_ends_before_* demos for what happens when the
# parent exits before the child.
waitpid($pid, 0);

__END__
prove -v concurrency_demos/fork_inside_subtest_nowait_legacy.pl
concurrency_demos/fork_inside_subtest_nowait_legacy.pl .. 
1..1
# Test::More version: 1.001014
# PID: 6607
    # Subtest: The Subtest
    ok 1 - In parent 6607
    1..1
ok 1 - The Subtest
    ok 1 - In Child 6608
ok
All tests successful.
Files=1, Tests=1,  1 wallclock secs ( 0.02 usr  0.00 sys +  0.03 cusr  0.01 csys =  0.06 CPU)
Result: PASS
