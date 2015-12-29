use strict;
use warnings;

BEGIN { require "t/tools.pl" };
use Test2::Event::Subtest;
my $st = 'Test2::Event::Subtest';

my $trace = Test2::Util::Trace->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'xxx']);
my $one = $st->new(
    trace     => $trace,
    pass      => 1,
    buffered  => 1,
    name      => 'foo',
);

ok($one->isa('Test2::Event::Ok'), "Inherit from Ok");
is_deeply($one->subevents, [], "subevents is an arrayref");

done_testing;
