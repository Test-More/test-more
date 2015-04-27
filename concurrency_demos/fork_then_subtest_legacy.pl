use strict;
use warnings;
use Test::More tests => 3;
use Test::SharedFork;

BEGIN {
    die "$0 must be run with an older version of Test-Simple"
        if $INC{'Test/Stream.pm'};
}

print "# Test::More version: $Test::More::VERSION\n";
print "# PID: $$\n";

my $pid = fork;
die "Could not fork" unless defined $pid;
if ($pid) {
    ok(1, "In parent");
    waitpid($pid, 0);
}
else {
    ok(1, "In Child");
    subtest "Child Subtest $$" => sub {
        ok(1, "Passing in subtest");
    };
    exit 0;
}

__END__
prove -v concurrency_demos/fork_then_subtest_legacy.pl
concurrency_demos/fork_then_subtest_legacy.pl .. 
1..3
# Test::More version: 1.001014
# PID: 6617
ok 1 - In parent
ok 2 - In Child
    # Subtest: Child Subtest 6618
    ok 1 - Passing in subtest
    1..1
ok 3 - Child Subtest 6618
# Looks like you planned 3 tests but ran 2.
Dubious, test returned 255 (wstat 65280, 0xff00)
All 3 subtests passed 

Test Summary Report
-------------------
concurrency_demos/fork_then_subtest_legacy.pl (Wstat: 65280 Tests: 3 Failed: 0)
  Non-zero exit status: 255
Files=1, Tests=3,  0 wallclock secs ( 0.01 usr  0.00 sys +  0.03 cusr  0.00 csys =  0.04 CPU)
Result: FAIL
