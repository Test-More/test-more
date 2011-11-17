#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use Config;
my $Can_Fork = $Config{d_fork} ||
               (($^O eq 'MSWin32' || $^O eq 'NetWare') and
                $Config{useithreads} and 
                $Config{ccflags} =~ /-DPERL_IMPLICIT_SYS/
               );

plan skip_all => "This system cannot fork" unless $Can_Fork;

use TB2::Events;
use TB2::History;

my $Top_PID = $$;

note "Parent PID: $$";
my $history = TB2::History->new;
ok !$history->pid_at_test_start,        "PID not recorded until test start";
ok !$history->is_child_process;

$history->accept_event( TB2::Event::TestStart->new );
is $history->pid_at_test_start, $Top_PID, "PID recorded at test start";
ok !$history->is_child_process;


if( my $child = fork ) {                # parent
    # Wait until our children have output their tests
    waitpid $child, 0;
}
else {                                  # child
    note "Child PID: $$";
    is $history->pid_at_test_start, $Top_PID;
    ok $history->is_child_process;

    if( !fork ) {                       # grandchild
        note "Grandchild PID: $$";
        is $history->pid_at_test_start, $Top_PID;
        ok $history->is_child_process;
    }

    exit;
}


# Account for what our children ran.
next_test() for 1..4;

is $history->pid_at_test_start, $Top_PID;
ok !$history->is_child_process;

done_testing;
