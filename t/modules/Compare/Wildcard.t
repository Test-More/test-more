use Test::Stream -V1, Class => ['Test::Stream::Compare::Wildcard'];

my $one = $CLASS->new(expect => 'foo');
isa_ok($one, $CLASS, 'Test::Stream::Compare');

ok($CLASS->new(expect => 0), "0 is a valid expect value");
ok($CLASS->new(expect => undef), "undef is a valid expect value");
ok($CLASS->new(expect => ''), "'' is a valid expect value");

like(
    dies { $CLASS->new() },
    qr/'expect' is a require attribute/,
    "Need to specify 'expect'"
);

done_testing;
