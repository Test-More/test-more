use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
    die "$0 must be run with a newer version of Test-Simple"
        unless $INC{'Test/Stream.pm'};
}

use Test::Stream qw/concurrency/;

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
prove -v concurrency_demos/fork_inside_subtest_nowait-or-exit_stream.pl
concurrency_demos/fork_inside_subtest_nowait-or-exit_stream.pl .. 
1..1
# Test::More version: 1.301001108
# PID: 6680
# Subtest: The Subtest
    ok 1 - In parent 6680
    1..1
ok 1 - The Subtest
Attempted to send an event to subtest that has already completed.  This usually
means you started a new process or thread inside a subtest, but let the subtest
end before the child process or thread completed.
Event: Test::Stream::Event::Ok=HASH(0x1c2f530)
  # ok - In Child 6681

Attempted to send an event to subtest that has already completed.  This usually
means you started a new process or thread inside a subtest, but let the subtest
end before the child process or thread completed.
Event: Test::Stream::Event::Exception=HASH(0x1c2f4a0)
  # New process was started inside of the subtest 'The Subtest', but the process did not
  # terminate before the end of the subtest subroutine. All threads and child
  # processes started inside a subtest subroutine must complete inside the subtest
  # subroutine.

# Looks like you failed 2 tests of 1.
Dubious, test returned 2 (wstat 512, 0x200)
All 1 subtests passed 

Test Summary Report
-------------------
concurrency_demos/fork_inside_subtest_nowait-or-exit_stream.pl (Wstat: 512 Tests: 1 Failed: 0)
  Non-zero exit status: 2
Files=1, Tests=1,  1 wallclock secs ( 0.01 usr  0.00 sys +  0.04 cusr  0.01 csys =  0.06 CPU)
Result: FAIL
