use strict;
use warnings;
use Test::More tests => 3;

BEGIN {
    die "$0 must be run with a newer version of Test-Simple"
        unless $INC{'Test/Stream.pm'};
}

use Test::Stream qw/concurrency/;

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
prove -v concurrency_demos/fork_then_subtest_stream.pl
concurrency_demos/fork_then_subtest_stream.pl .. 
1..3
# Test::More version: 1.301001108
# PID: 6693
ok 1 - In parent
    ok 1 - Passing in subtest
    1..1
ok 2 - In Child
# Subtest: Child Subtest 6694
ok 3 - Child Subtest 6694
ok
All tests successful.
Files=1, Tests=3,  0 wallclock secs ( 0.01 usr  0.00 sys +  0.04 cusr  0.01 csys =  0.06 CPU)
Result: PASS
