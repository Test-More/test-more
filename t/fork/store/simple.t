use strict;
use warnings;
use Test::More tests => 1;
use Test::SharedFork::Store;

my $s = Test::SharedFork::Store->new(cb => sub { });
$s->set(foo => 'bar');
is $s->get('foo'), 'bar';

