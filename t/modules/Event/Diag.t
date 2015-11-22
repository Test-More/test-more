use Test::Stream -V1, Compare => ['-all'];

use Test::Stream::Event::Diag;
use Test::Stream::DebugInfo;

use Test::Stream::Formatter::TAP qw/OUT_TODO OUT_ERR/;

my $diag = Test::Stream::Event::Diag->new(
    debug => Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    message => 'foo',
);

warns {
    is(
        [$diag->to_tap(1)],
        [[OUT_ERR, "# foo\n"]],
        "Got tap"
    );

    $diag->set_message("foo\n");
    is(
        [$diag->to_tap(1)],
        [[OUT_ERR, "# foo\n"]],
        "Only 1 newline"
    );

    $diag->debug->set_todo('todo');
    is(
        [$diag->to_tap(1)],
        [[OUT_TODO, "# foo\n"]],
        "Got tap in todo"
    );

    $diag->set_message("foo\nbar\nbaz");
    is(
        [$diag->to_tap(1)],
        [[OUT_TODO, "# foo\n# bar\n# baz\n"]],
        "All lines have proper prefix"
    );
};

$diag = Test::Stream::Event::Diag->new(
    debug => Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    message => undef,
);

is($diag->message, 'undef', "set undef message to undef");

$diag = Test::Stream::Event::Diag->new(
    debug => Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    message => {},
);

like($diag->message, qr/^HASH\(.*\)$/, "stringified the input value");

warns {
    $diag->set_message("");
    is([$diag->to_tap], [], "no tap with an empty message");

    $diag->set_message("\n");
    is([$diag->to_tap], [[OUT_ERR, "\n"]], "newline on its own is unchanged");
};

done_testing;
