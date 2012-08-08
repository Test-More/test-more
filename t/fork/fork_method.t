use strict;
use warnings;
use Test::More tests => 43;
use Test::SharedFork;

my $pid = Test::SharedFork->fork();
if ($pid == 0) {
    # child
    my $i = 0;
    for (1..20) {
        $i++;
        ok 1, "child $_"
    }
    is $i, 20, 'child finished';

    exit;
} elsif ($pid) {
    # parent
    my $i = 0;
    for (1..20) {
        $i++;
        ok 1, "parent $_";
    }
    is $i, 20, 'parent finished';
    waitpid($pid, 0);

    ok 1, 'wait ok';

    exit;
} else {
    die $!;
}

