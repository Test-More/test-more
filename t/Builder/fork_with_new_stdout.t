#!perl -w

# Ensure that reset() grabs a new copy of STDOUT/STDERR

use strict;
use warnings;
use IO::Pipe;
use Test::Builder;
use Config;

my $b = Test::Builder->new;
$b->reset;

my $Can_Fork = $Config{d_fork} ||
  (($^O eq 'MSWin32' || $^O eq 'NetWare') and
     $Config{useithreads} and
     $Config{ccflags} =~ /-DPERL_IMPLICIT_SYS/
  );

if ( !$Can_Fork ) {
    $b->plan('skip_all' => "This system cannot fork");
}

my $pipe = IO::Pipe->new;
if ( my $pid = fork ) {
    $pipe->reader;
    my @child = <$pipe>;
    waitpid($pid, 0);

    $b->plan(tests => 3);

    # Deliberately not checking the newline, pipes on Strawberry mess them up
    $b->like($child[0], qr{^TAP version 13},       "TAP version from child");
    $b->like($child[1], qr{^1..1},                 "  plan");
    $b->like($child[2], qr{^ok 1},                 "  ok");

    $b->note("Output from child...\n", @child);
} else {
    $pipe->writer;
    my $pipe_fd = $pipe->fileno;
    close STDOUT;
    open(STDOUT, ">&$pipe_fd");
    my $b = Test::Builder->new;
    $b->reset;
    $b->plan( tests => 1 );
    $b->ok(1);
} 
