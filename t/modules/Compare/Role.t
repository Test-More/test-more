use Test2::Bundle::Extended -target => 'Test2::Compare::Role';

plan skip_all => 'Role::Tiny is required for Role checks' unless eval { require Role::Tiny; 1 };

{

    package Foo { };

    package Foo::Role {
        use Role::Tiny;
    };

    package Foo::Role::Over {
        use Role::Tiny;
    };

    package Foo::Bar {
        use Role::Tiny::With;
        with 'Foo::Role';
    };

    package Foo::Quux {
        use Role::Tiny::With;
        with 'Foo::Role', 'Foo::Role::Over';
    };

    package Baz { };
}

my $role_foo      = $CLASS->new(input => 'Foo::Role');
my $role_foo_over = $CLASS->new(input => 'Foo::Role::Over');
my $not_role_foo  = $CLASS->new(input => 'Foo::Role', negate => 1);

isa_ok($_, $CLASS, 'Test2::Compare::Base') for $role_foo, $role_foo_over, $not_role_foo;

subtest name => sub {
    is($role_foo->name,      'Foo::Role',       "got expected name");
    is($role_foo_over->name, 'Foo::Role::Over', "got expected name");
    is($not_role_foo->name,  'Foo::Role',       "got expected name");
};

subtest operator => sub {
    is($role_foo->operator,      'role',  "got expected operator");
    is($role_foo_over->operator, 'role',  "got expected operator");
    is($not_role_foo->operator,  '!role', "got expected operator");
};

subtest verify => sub {
    my $foo      = bless {}, 'Foo';
    my $foo_bar  = bless {}, 'Foo::Bar';
    my $foo_quux = bless {}, 'Foo::Quux';
    my $baz      = bless {}, 'Baz';

    ok(!$role_foo->verify(exists => 0, got => undef),     'does not verify against DNE');
    ok(!$role_foo->verify(exists => 1, got => undef),     'undef has no role Foo::Role');
    ok(!$role_foo->verify(exists => 1, got => 42),        '42 has no role Foo::Role');
    ok(!$role_foo->verify(exists => 1, got => $foo),      '$foo has no role Foo::Role');
    ok($role_foo->verify(exists  => 1, got => $foo_bar),  '$foo_bar has role Foo::Role');
    ok($role_foo->verify(exists  => 1, got => $foo_quux), '$foo_quux has role Foo::Role');
    ok(!$role_foo->verify(exists => 1, got => $baz),      '$baz has no role Foo::Role');

    ok(!$role_foo_over->verify(exists => 0, got => undef),     'does not verify against DNE');
    ok(!$role_foo_over->verify(exists => 1, got => undef),     'undef has no role Foo::Role::Over');
    ok(!$role_foo_over->verify(exists => 1, got => 42),        '42 has no role Foo::Role::Over');
    ok(!$role_foo_over->verify(exists => 1, got => $foo),      '$foo has no role Foo::Role::Over');
    ok(!$role_foo_over->verify(exists => 1, got => $foo_bar),  '$foo_bar has no role Foo::Role::Over');
    ok($role_foo_over->verify(exists  => 1, got => $foo_quux), '$foo_quux has role Foo::Role::Over');
    ok(!$role_foo_over->verify(exists => 1, got => $baz),      '$baz has no role Foo::Role::Over');

    ok(!$not_role_foo->verify(exists => 0, got => undef),     'does not verify against DNE');
    ok($not_role_foo->verify(exists  => 1, got => undef),     'undef has no role Foo::Role');
    ok($not_role_foo->verify(exists  => 1, got => 42),        '42 has no role Foo::Role');
    ok($not_role_foo->verify(exists  => 1, got => $foo),      '$foo has no role Foo::Role');
    ok(!$not_role_foo->verify(exists => 1, got => $foo_bar),  '$foo_bar has role Foo::Role');
    ok(!$not_role_foo->verify(exists => 1, got => $foo_quux), '$foo_quux has role Foo::Role');
    ok($not_role_foo->verify(exists  => 1, got => $baz),      '$baz has no role Foo::Role');
};

like(dies { $CLASS->new() }, qr/input must be defined for 'Role' check/, "Cannot use undef as a class name");

done_testing;
