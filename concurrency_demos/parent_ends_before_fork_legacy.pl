use strict;
use warnings;
use Test::More;
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
    done_testing;
    exit 0;
}
else {
    sleep 1;
    ok(1, "In Child");
    exit 0;
}

__END__
prove -v concurrency_demos/parent_ends_before_fork_legacy.pl
concurrency_demos/parent_ends_before_fork_legacy.pl .. 
# Test::More version: 1.001014
# PID: 6622
ok 1 - In parent
1..1
Magic number checking on storable file failed at /home/exodist/perl5/perlbrew/perls/main/lib/5.20.1/x86_64-linux-thread-multi/Storable.pm line 399, at /home/exodist/perl5/perlbrew/perls/main/lib/site_perl/5.20.1/Test/SharedFork/Store.pm line 51.
ok
All tests successful.
Files=1, Tests=1,  1 wallclock secs ( 0.02 usr  0.00 sys +  0.02 cusr  0.00 csys =  0.04 CPU)
Result: PASS
