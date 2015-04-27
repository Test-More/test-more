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
        exit 0;
    }
};

# This is to demonstrate behavior when the child does not exit, and the subtest
# does not wait. See the parent_ends_before_* demos for what happens when the
# parent exits before the child.
waitpid($pid, 0);

__END__
prove -v concurrency_demos/fork_inside_subtest_nowait_stream.pl
concurrency_demos/fork_inside_subtest_nowait_stream.pl .. 
1..1
# Test::More version: 1.301001108
# PID: 6685
# Subtest: The Subtest
    ok 1 - In parent 6685
    1..1
ok 1 - The Subtest
Attempted to send an event to subtest that has already completed.  This usually
means you started a new process or thread inside a subtest, but let the subtest
end before the child process or thread completed.
Event: Test::Stream::Event::Ok=HASH(0x1907590)
  # ok - In Child 6686

# Looks like you failed 1 test of 1.
Dubious, test returned 1 (wstat 256, 0x100)
All 1 subtests passed 

Test Summary Report
-------------------
concurrency_demos/fork_inside_subtest_nowait_stream.pl (Wstat: 256 Tests: 1 Failed: 0)
  Non-zero exit status: 1
Files=1, Tests=1,  1 wallclock secs ( 0.01 usr  0.01 sys +  0.06 cusr  0.00 csys =  0.08 CPU)
Result: FAIL
