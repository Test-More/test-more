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
        exit 0;
    }
}

__END__
prove -v concurrency_demos/fork_inside_subtest_stream.pl
concurrency_demos/fork_inside_subtest_stream.pl .. 
1..1
# Test::More version: 1.301001108
# PID: 6690
# Subtest: The Subtest
    ok 1 - In parent 6690
    ok 2 - In Child 6691
    1..2
ok 1 - The Subtest
ok
All tests successful.
Files=1, Tests=1,  1 wallclock secs ( 0.01 usr  0.00 sys +  0.05 cusr  0.00 csys =  0.06 CPU)
Result: PASS
