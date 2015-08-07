use Test::Stream '-Tester';

can_ok(__PACKAGE__, qw/subtest grab intercept/);

like(
    dies {Test::Stream->import(qw/FakeTestTool/)},
    qr/Can't locate/,
    "Exception when loading fake class"
);

done_testing;
