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
else {
    $b->plan('tests' => 2);
}

my $pipe = IO::Pipe->new;
if ( my $pid = fork ) {
  $pipe->reader;
  my ($one, $two) = <$pipe>;
  $b->like($one, qr/ok 1/, "ok 1 from child");
  $b->like($two, qr/1\.\.1/, "1..1 from child");
  waitpid($pid, 0);
}
else {
  $pipe->writer;
  $b->reset;
  $b->no_plan;
  $b->output($pipe);
  $b->ok(1);
  $b->done_testing;
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
