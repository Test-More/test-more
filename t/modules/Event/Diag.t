use strict;
use warnings;
use Test::Stream::Tester;
use Test::Stream::Event::Diag;
use Test::Stream::Trace;

my $diag = Test::Stream::Event::Diag->new(
    trace => Test::Stream::Trace->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    message => 'foo',
);

$diag = Test::Stream::Event::Diag->new(
    trace => Test::Stream::Trace->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    message => undef,
);

is($diag->message, 'undef', "set undef message to undef");

$diag = Test::Stream::Event::Diag->new(
    trace => Test::Stream::Trace->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    message => {},
);

like($diag->message, qr/^HASH\(.*\)$/, "stringified the input value");

done_testing;
