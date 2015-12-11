use strict;
use warnings;

use Test::Stream::Tester;
use Test::Stream::Event::Note;
use Test::Stream::Trace;

my $note = Test::Stream::Event::Note->new(
    trace => Test::Stream::Trace->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    message => 'foo',
);

$note = Test::Stream::Event::Note->new(
    trace => Test::Stream::Trace->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    message => undef,
);

is($note->message, 'undef', "set undef message to undef");

$note = Test::Stream::Event::Note->new(
    trace => Test::Stream::Trace->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    message => {},
);

like($note->message, qr/^HASH\(.*\)$/, "stringified the input value");

done_testing;
