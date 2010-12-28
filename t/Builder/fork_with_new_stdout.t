#!perl -w

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

if( !$Can_Fork ) {
    $b->plan('skip_all' => "This system cannot fork");
}

my $pipe = IO::Pipe->new;
if ( my $pid = fork ) {
  $pipe->reader;
  my @child = <$pipe>;
  waitpid($pid, 0);

  $b->plan(tests => 3);
  $b->is_eq($child[0], "TAP version 13\n",       "TAP version from child");
  $b->is_eq($child[1], "1..1\n",                 "  plan");
  $b->is_eq($child[2], "ok 1\n",                 "  ok");

  $b->note("Output from child...\n", @child);
}
else {
  $pipe->writer;
  my $pipe_fd = $pipe->fileno;
  close STDOUT;
  open(STDOUT, ">&$pipe_fd");
  my $b = Test::Builder->new;
  $b->output(*STDOUT);
  $b->plan( tests => 1 );
  $b->ok(1);
} 


=pod
#actual
1..2
ok 1
1..1
ok 1
ok 2
#expected
1..2
ok 1
ok 2
=cut
