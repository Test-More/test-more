use strict;
use warnings;
use Test::More tests => 43;
use Test::SharedFork;
use Time::HiRes qw/sleep/;

my $pid = fork();
if ($pid == 0) {
    # child
    Test::SharedFork->child;

    my $i = 0;
    for (1..20) {
        $i++;
        ok 1, "child $_";
        sleep(rand()/100);
    }
    is $i, 20, 'child finished';

    1 while wait() != -1;
    exit;
} elsif ($pid) {
    # parent
    Test::SharedFork->parent;

    my $i = 0;
    for (1..20) {
        $i++;
        ok 1, "parent $_";
        sleep(rand()/100);
    }
    is $i, 20, 'parent finished';
    waitpid($pid, 0);

    ok 1, 'wait ok';

    exit;
} else {
    die $!;
}

