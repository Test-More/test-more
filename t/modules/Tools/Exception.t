use Test2::Bundle::Extended -target => 'Test2::Tools::Exception';

{
    package Foo;
    use Test2::Tools::Exception qw/dies lives/;
    ::imported_ok(qw/dies lives/);
}

like(
    dies { die 'xyz' },
    qr/xyz/,
    "Got exception"
);

is(dies { 0 }, undef, "no exception");

{
    local $@ = 'foo';
    ok(lives { 0 }, "it lives!");
    is($@, "foo", "did not change \$@");
}

ok(!lives { die 'xxx' }, "it died");
like($@, qr/xxx/, "Exception is available");

done_testing;
