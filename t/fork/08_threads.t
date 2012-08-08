BEGIN {
     require Config;
     if (!$Config::Config{useithreads}) {
        print "1..0 # Skip: no ithreads\n";
        exit 0;
     }
}
use Test::More;
plan skip_all => "Not implemented yet";
use strict;

# use threads before Test::More!
use threads;
use Test::More;
use_ok "Test::SharedFork";

my $pid = Test::SharedFork->fork();
if (! defined $pid) {
    fail "Could not fork";
} elsif ($pid) {
    ok($_[0], "parent");
    waitpid $pid, 0;
} else {
    ok($_[0], "child");
    exit 0;
}

done_testing;
