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
        ok(1, "In Child $$");
        exit 0;
    }
}

__END__
prove -v concurrency_demos/fork_inside_subtest_legacy.pl
concurrency_demos/fork_inside_subtest_legacy.pl .. 
1..1
# Test::More version: 1.001014
# PID: 6599
    # Subtest: The Subtest
    ok 1 - In parent 6599
    ok 1 - In Child 6600
    1..1
ok 1 - The Subtest
ok
All tests successful.
Files=1, Tests=1,  0 wallclock secs ( 0.01 usr  0.00 sys +  0.03 cusr  0.00 csys =  0.04 CPU)
Result: PASS
