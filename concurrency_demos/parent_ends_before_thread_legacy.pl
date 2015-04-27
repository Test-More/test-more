use strict;
use warnings;
use threads;
use Test::More;

BEGIN {
    die "$0 must be run with an older version of Test-Simple"
        if $INC{'Test/Stream.pm'};
}

print "# Test::More version: $Test::More::VERSION\n";
print "# PID: $$\n";

ok(1, "In parent");

my $thr = threads->create(sub {
    sleep 1;
    ok(1, "In Child");
});

done_testing;

__END__
prove -v concurrency_demos/parent_ends_before_thread_legacy.pl
concurrency_demos/parent_ends_before_thread_legacy.pl .. 
# Test::More version: 1.001014
# PID: 6627
ok 1 - In parent
1..1
Perl exited with active threads:
	1 running and unjoined
	0 finished and unjoined
	0 running and detached
ok
All tests successful.
Files=1, Tests=1,  0 wallclock secs ( 0.02 usr  0.00 sys +  0.01 cusr  0.00 csys =  0.03 CPU)
Result: PASS
