use Test::Stream -V1, Class => ['Test::Stream::Bundle::SpecTester'];

is(
    [CLASS()->plugins],
    [
        qw/-Tester Spec/,
    ],
    "Loads tester and spec"
);

done_testing;
