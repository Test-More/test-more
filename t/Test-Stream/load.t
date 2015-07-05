use Test::Stream(
    'Subtest' => [subtest_buffered => {-as => 'subtest'}],
    'Interceptor' => [qw/dies/],
    'Tester',
);

# Make sure we imported some defaults from Tester, and also our renamed subtest
# sub.
can_ok(__PACKAGE__, qw/subtest grab intercept/);

like(
    dies {Test::Stream->import(qw/FakeTestTool/)},
    qr/Can't locate/,
    "Exception when loading fake class"
);

done_testing;
