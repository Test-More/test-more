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

subtest "The Subtest" => sub {
    my $pid = fork;
    die "Could not fork" unless defined $pid;
    if ($pid) {
        ok(1, "In parent $$");
        waitpid($pid, 0);
    }
    else {
        ok(1, "In Child $$");
    }
};

__END__
prove -v concurrency_demos/fork_inside_subtest_noexit_stream.pl
concurrency_demos/fork_inside_subtest_noexit_stream.pl .. 
1..1
# Test::More version: 1.301001108
# PID: 6677
# Subtest: The Subtest
    ok 1 - In parent 6677
    ok 2 - In Child 6678
    New process was started inside of the subtest 'The Subtest', but the process did not
    terminate before the end of the subtest subroutine. All threads and child
    processes started inside a subtest subroutine must complete inside the subtest
    subroutine.
    1..2
    # Looks like you failed 1 test of 2.
not ok 1 - The Subtest

#   Failed test 'The Subtest'
#   at concurrency_demos/fork_inside_subtest_noexit_stream.pl line 25.
# Looks like you failed 1 test of 1.
Dubious, test returned 1 (wstat 256, 0x100)
Failed 1/1 subtests 

Test Summary Report
-------------------
concurrency_demos/fork_inside_subtest_noexit_stream.pl (Wstat: 256 Tests: 1 Failed: 1)
  Failed test:  1
  Non-zero exit status: 1
Files=1, Tests=1,  0 wallclock secs ( 0.01 usr  0.00 sys +  0.04 cusr  0.01 csys =  0.06 CPU)
Result: FAIL
