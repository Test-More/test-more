use strict;
use warnings;
use Test::More tests => 30;
use Test::SharedFork;

for (1..10) {
    my $pid = Test::SharedFork->fork();
    if ($pid == 0) {
        # child
        ok 1, "child $_";

        exit;
    } elsif (defined($pid)) {
        # parent
        ok 1, "parent $_";

        waitpid($pid, 0);

        ok 1, 'wait ok';
    } else {
        die "fork failed: $!";
    }
}

