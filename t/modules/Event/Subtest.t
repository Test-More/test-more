use strict;
use warnings;

use Test::Stream::Tester;
use Test::Stream::Event::Subtest;
my $st = 'Test::Stream::Event::Subtest';

my $dbg = Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'xxx']);
my $one = $st->new(
    debug     => $dbg,
    pass      => 1,
    buffered  => 1,
    name      => 'foo',
);

ok($one->isa('Test::Stream::Event::Ok'), "Inherit from Ok");
is_deeply($one->subevents, [], "subevents is an arrayref");

done_testing;
