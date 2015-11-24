use Test::Stream -V1;
use strict;
use warnings;

use Test::Stream::Event::Skip;
use Test::Stream::DebugInfo;

my $skip = Test::Stream::Event::Skip->new(
    debug  => Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    name   => 'skip me',
    reason => 'foo',
);

isa_ok($skip, 'Test::Stream::Event::Skip');
is($skip->name, 'skip me', "set name");
is($skip->reason, 'foo', "got skip reason");

done_testing;
