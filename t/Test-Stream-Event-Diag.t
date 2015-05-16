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

my $link = {};
$diag = Test::Stream::Event::Diag->new(
    debug => Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    message => 'foo',
    linked => $link,
);
$link->{link} = $diag;

is($diag->linked, $link, "got link");
$link = 0;
ok(!$diag->linked, "link is weak ref (avoid cycles)");

$link = {link => $diag};
$diag->link($link);
is($diag->linked, $link, "got link");
$link = 0;
ok(!$diag->linked, "link is weak ref (avoid cycles)");

done_testing;
