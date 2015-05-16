use Test::More;
use strict;
use warnings;

use Test::Stream::Event::Note;
use Test::Stream::DebugInfo;

use Test::Stream::TAP qw/OUT_STD/;

my $note = Test::Stream::Event::Note->new(
    debug => Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    message => 'foo',
);

is_deeply(
    [$note->to_tap(1)],
    [[OUT_STD, "# foo\n"]],
    "Got tap"
);

$note->set_message("foo\n");
is_deeply(
    [$note->to_tap(1)],
    [[OUT_STD, "# foo\n"]],
    "Only 1 newline"
);

$note->set_message("foo\nbar\nbaz");
is_deeply(
    [$note->to_tap(1)],
    [[OUT_STD, "# foo\n# bar\n# baz\n"]],
    "All lines have '#'"
);

done_testing;
