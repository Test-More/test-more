use strict;
use warnings;
use threads;
use Test::More tests => 1;

BEGIN {
    die "$0 must be run with an older version of Test-Simple"
        if $INC{'Test/Stream.pm'};
}

print "# Test::More version: $Test::More::VERSION\n";
print "# PID: $$\n";

my $thr;
subtest "Child Subtest $$" => sub {
    ok(1, "Passing in parent");
    $thr = threads->create(sub {
        sleep 1;
        ok(1, "In Child");
    });
};

$thr->join;

__END__
prove -v concurrency_demos/thread_inside_subtest_nojoin_legacy.pl
concurrency_demos/thread_inside_subtest_nojoin_legacy.pl .. 
1..1
# Test::More version: 1.001014
# PID: 6633
    # Subtest: Child Subtest 6633
    ok 1 - Passing in parent
    1..1
ok 1 - Child Subtest 6633
    ok 2 - In Child
ok
All tests successful.
Files=1, Tests=1,  1 wallclock secs ( 0.01 usr  0.00 sys +  0.01 cusr  0.00 csys =  0.02 CPU)
Result: PASS
