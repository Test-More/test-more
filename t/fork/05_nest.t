use strict;
use warnings;
use Test::More tests => 4;
use Test::SharedFork;

&main;exit 0;

sub main {
    my $pid = Test::SharedFork->fork();
    if ($pid==0) {
        ok 1;
        return;
    } elsif (defined $pid) {
        ok 1;

        1 while wait() == -1;

        my $pid = Test::SharedFork->fork();
        if ($pid==0) {
            ok 1;
            return;
        } elsif (defined $pid) {
            ok 1;
            1 while wait() == -1;
            return;
        } else {
            die $!;
        }
    } else {
        die "fork failed: $!";
    }
}
