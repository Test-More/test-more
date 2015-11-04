use Test::Stream -V1, Spec, class => 'Test::Stream::Compare::Undef';

my $undef = $CLASS->new();
my $isdef = $CLASS->new(negate => 1);

isa_ok($undef, $CLASS, 'Test::Stream::Compare');
isa_ok($isdef, $CLASS, 'Test::Stream::Compare');

tests name => sub {
    is($undef->name, '<UNDEF>', "got expected name for undef");
    is($isdef->name, '<UNDEF>', "got expected name for negated undef");
};

tests operator => sub {
    is($undef->operator(),    'IS', "Operator is 'IS'");
    is($undef->operator('a'), 'IS', "Operator is 'IS'");

    is($isdef->operator(),    'IS NOT', "Operator is 'IS NOT'");
    is($isdef->operator('a'), 'IS NOT', "Operator is 'IS NOT'");
};

tests verify => sub {
    ok(!$undef->verify(exists => 0, got => undef), 'does not verify against DNE');
    ok(!$undef->verify(exists => 1, got => {}),    'ref will not verify');
    ok(!$undef->verify(exists => 1, got => 'x'),   'not looking for a string');
    ok(!$undef->verify(exists => 1, got => 1),     'not looking for a number');
    ok(!$undef->verify(exists => 1, got => 0),     'not looking for a 0');
    ok($undef->verify(exists => 1, got => undef),  'got undef');

    ok(!$isdef->verify(exists => 0, got => undef), 'does not verify against DNE');
    ok(!$isdef->verify(exists => 1, got => undef), 'got undef');
    ok($isdef->verify(exists => 1, got => {}),    'ref is defined');
    ok($isdef->verify(exists => 1, got => 'x'),   'string is defined');
    ok($isdef->verify(exists => 1, got => 1),     'number is defined');
    ok($isdef->verify(exists => 1, got => 0),     '0 is defined');
};

done_testing;
