use strict;
use warnings;
use Test2::IPC qw/cull/;
use if $ENV{PIPE}, 'Test2::IPC::Driver::AtomicPipe';
use Test2::Tools::Tiny;

my $count = $ENV{OK_COUNT} || 100000;
plan($count);

my $procs = $ENV{PROC_COUNT} || 4;

$count /= $procs;

my @PIDS;

for (1 .. $procs) {
    my $pid = fork();
    if ($pid) { # parent;
        push @PIDS => $pid;
    }
    else { # child
        ok(1, "an ok $$") for 1 .. $count;
        exit 0;
    }
}

use POSIX ":sys_wait_h";
while (@PIDS) {
    cull();
    for my $pid (@PIDS) {
        my $got = waitpid($pid, WNOHANG) or next;
        @PIDS = grep { $_ != $got } @PIDS;
    }
}

1;
