#!perl -w
use strict;
use warnings;
use IO::Pipe;
use Test::Builder;

my $b = Test::Builder->new;
$b->reset;
$b->plan('tests' => 2);

my $pipe = IO::Pipe->new;
if ( my $pid = fork ) {
  $pipe->reader;
  $b->ok((<$pipe> =~ /FROM CHILD: ok 1/), "ok 1 from child");
  $b->ok((<$pipe> =~ /FROM CHILD: 1\.\.1/), "1..1 from child");
  waitpid($pid, 0);
}
else {
  $pipe->writer;
  my $pipe_fd = $pipe->fileno;
  close STDOUT;
  open(STDOUT, ">&$pipe_fd");
  my $b = Test::Builder->new;
  $b->reset;
  $b->no_plan;
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
