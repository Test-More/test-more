use Test::Stream -V1, Spec, Class => ['Test::Stream::Compare::Number'];

my $undef = $CLASS->new();
my $num = $CLASS->new(input => '22.0');
my $untrue = $CLASS->new(input => 0);

isa_ok($undef, $CLASS, 'Test::Stream::Compare');
isa_ok($num, $CLASS, 'Test::Stream::Compare');
isa_ok($untrue, $CLASS, 'Test::Stream::Compare');

tests name => sub {
    is($undef->name,  '<UNDEF>', "got expected name for undef");
    is($num->name, '22.0',    "got expected name for number");
    is($untrue->name, '0',       "got expected name for 0");
};

tests operator => sub {
    is($undef->operator(),      '',   "no operator for undef + nothing");
    is($undef->operator(undef), '==', "== for 2 undefs");
    is($undef->operator(1),     '',   "no operator for undef + number");

    is($num->operator(),      '',   "no operator for number + nothing");
    is($num->operator(undef), '',   "no operator for number + undef");
    is($num->operator(1),     '==', "== operator for number + number");

    is($untrue->operator(),      '',   "no operator for 0 + nothing");
    is($untrue->operator(undef), '',   "no operator for 0 + undef");
    is($untrue->operator(1),     '==', "== operator for 0 + number");
};

tests verify => sub {
    ok(!$undef->verify(exists => 0, got => undef), 'does not verify against DNE');
    ok(!$undef->verify(exists => 1, got => {}),    'Ref does not verify against undef');
    ok($undef->verify(exists => 1, got => undef), 'undef verifies against undef');
    ok(!$undef->verify(exists => 1, got => 'x'), 'string will not validate against undef');
    ok(!$undef->verify(exists => 1, got => 1),   'number will not verify against undef');

    ok(!$num->verify(exists => 0, got => undef), 'does not verify against DNE');
    ok(!$num->verify(exists => 1, got => {}),    'ref will not verify');
    ok(!$num->verify(exists => 1, got => undef), 'looking for a number, not undef');
    ok(!$num->verify(exists => 1, got => 'x'),   'not looking for a string');
    ok(!$num->verify(exists => 1, got => 1),     'wrong number');
    ok($num->verify(exists => 1, got => 22),     '22.0 == 22');
    ok($num->verify(exists => 1, got => '22.0'), 'exact match with decimal');

    ok(!$untrue->verify(exists => 0, got => undef), 'does not verify against DNE');
    ok(!$untrue->verify(exists => 1, got => {}),    'ref will not verify');
    ok(!$untrue->verify(exists => 1, got => undef), 'undef is not 0 for this test');
    ok(!$untrue->verify(exists => 1, got => 'x'),   'x is not 0');
    ok(!$untrue->verify(exists => 1, got => 1),     '1 is not 0');
    ok($untrue->verify(exists => 1, got => 0),      'got 0');
    ok($untrue->verify(exists => 1, got => '0.0'),  '0.0 == 0');
    ok($untrue->verify(exists => 1, got => '-0.0'), '-0.0 == 0');
};

done_testing;
