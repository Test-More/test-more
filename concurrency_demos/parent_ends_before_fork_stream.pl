use strict;
use warnings;
use Test::More;

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
    done_testing;
    exit 0;
}
else {
    sleep 1;
    ok(1, "In Child");
    exit 0;
}

__END__
prove -v concurrency_demos/parent_ends_before_fork_stream.pl
concurrency_demos/parent_ends_before_fork_stream.pl .. 
# Test::More version: 1.301001108
# PID: 6696
ok 1 - In parent
ok 2 - In Child
1..2
ok
All tests successful.
Files=1, Tests=2,  1 wallclock secs ( 0.02 usr  0.00 sys +  0.04 cusr  0.00 csys =  0.06 CPU)
Result: PASS
