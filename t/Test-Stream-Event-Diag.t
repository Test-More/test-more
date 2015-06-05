use Test::More;
use strict;
use warnings;

use Test::Stream::Event::Diag;
use Test::Stream::DebugInfo;

use Test::Stream::TAP qw/OUT_TODO OUT_ERR/;

my $diag = Test::Stream::Event::Diag->new(
    debug => Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    message => 'foo',
);

is_deeply(
    [$diag->to_tap(1)],
    [[OUT_ERR, "# foo\n"]],
    "Got tap"
);

$diag->set_message("foo\n");
is_deeply(
    [$diag->to_tap(1)],
    [[OUT_ERR, "# foo\n"]],
    "Only 1 newline"
);

$diag->debug->set_todo('todo');
is_deeply(
    [$diag->to_tap(1)],
    [[OUT_TODO, "# foo\n"]],
    "Got tap in todo"
);

$diag->set_message("foo\nbar\nbaz");
is_deeply(
    [$diag->to_tap(1)],
    [[OUT_TODO, "# foo\n# bar\n# baz\n"]],
    "All lines have '#'"
);

done_testing;
