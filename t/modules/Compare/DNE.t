use Test::Stream -Core1, Class => ['Test::Stream::Compare::DNE'];

my $one = $CLASS->new;
isa_ok($one, $CLASS, 'Test::Stream::Compare');

my $line;
like(
    dies {
        my $ctx = context(level => -1); $line = __LINE__;
        $one->verify('whatever');
        $ctx->release;
    },
    qr/DNE->verify\(\) should never be called, was DNE used in a non-hash\? at.*line $line/,
    "verify should never be called"
);

is($one->name, "<DOES NOT EXIST>", "name is obvious");
is($one->operator, '!exists', "operator is obvious");

done_testing;
