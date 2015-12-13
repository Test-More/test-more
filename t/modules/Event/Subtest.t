use strict;
use warnings;

use Test2::Tester;
use Test2::Event::Subtest;
my $st = 'Test2::Event::Subtest';

my $trace = Test2::Context::Trace->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'xxx']);
my $one = $st->new(
    trace     => $trace,
    pass      => 1,
    buffered  => 1,
    name      => 'foo',
);

ok($one->isa('Test2::Event::Ok'), "Inherit from Ok");
is_deeply($one->subevents, [], "subevents is an arrayref");

done_testing;
