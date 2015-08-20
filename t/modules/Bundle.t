use Test::Stream;

BEGIN {
    package Test::Stream::Bundle::FakeTestBundle;
    $INC{'Test/Stream/Bundle/FakeTestBundle.pm'} = __FILE__;

    use Test::Stream::Bundle;

    our @CALLERS;

    sub plugins {
        'Core' => ['ok', 'imported', 'not_imported'],
        sub { push @CALLERS => shift }
    };
}

my @LINES;

{
    package Foo;
    push @LINES => __LINE__ + 1;
    use Test::Stream '-FakeTestBundle';

    imported('ok');
    not_imported('done_testing');
}

{
    package Bar;
    push @LINES => __LINE__ + 1;
    use Test::Stream::Bundle::FakeTestBundle;
    imported('ok');
    not_imported('done_testing');
}

is(
    \@Test::Stream::Bundle::FakeTestBundle::CALLERS,
    [
        ['Foo', __FILE__, $LINES[0]],
        ['Bar', __FILE__, $LINES[1]],
    ],
    "Caller was correct for all cases"
);

done_testing;
