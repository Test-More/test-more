use strict;
use warnings;
use Test2::IPC;
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

waitpid($_, 0) for @PIDS;

1;
