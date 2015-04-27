use strict;
use warnings;
use threads;
use Test::More;
use Test::Stream::Concurrency;

BEGIN {
    die "$0 must be run with a newer version of Test-Simple"
        unless $INC{'Test/Stream.pm'};
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
prove -v concurrency_demos/parent_ends_before_thread_stream.pl
concurrency_demos/parent_ends_before_thread_stream.pl .. 
# Test::More version: 1.301001108
# PID: 6701
ok 1 - In parent
ok 2 - In Child
1..2
ok
All tests successful.
Files=1, Tests=2,  1 wallclock secs ( 0.01 usr  0.00 sys +  0.06 cusr  0.01 csys =  0.08 CPU)
Result: PASS
