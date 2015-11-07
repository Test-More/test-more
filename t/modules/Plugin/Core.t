use Test::Stream qw/-V1 -Tester/;

use File::Temp qw/tempfile/;

imported_ok qw{
    ok pass fail
    diag note
    plan skip_all done_testing
    BAIL_OUT
    todo skip
    can_ok isa_ok DOES_ok ref_ok
    imported_ok not_imported_ok
    ref_is ref_is_not
    set_encoding
    cmp_ok
};

not_imported_ok(qw/x y z/);

is(
    intercept { imported_ok('x') },
    array { event Ok => { pass => 0 }; end },
    "Failed, x is not imported"
);

is(
    intercept { not_imported_ok('ok') },
    array { event Ok => { pass => 0 }; end },
    "Failed, 'ok' is imported"
);

pass('Testing Pass');

my @lines;
like(
    intercept {
        pass('pass');               push @lines => __LINE__;
        fail('fail');               push @lines => __LINE__;
        fail('fail', 'added diag'); push @lines => __LINE__;
    },
    array {
        event Ok => sub {
            call pass => 1;
            call name => 'pass';

            prop file    => __FILE__;
            prop package => __PACKAGE__;
            prop line    => $lines[0];
            prop subname => 'Test::Stream::Plugin::Core::pass';
        };
        event Ok => sub {
            call pass => 0;
            call name => 'fail';
            call diag => [ qr/Failed test 'fail'.*line $lines[1]/s ];

            prop file =>    __FILE__;
            prop package => __PACKAGE__;
            prop line =>    $lines[1];
            prop subname =>     'Test::Stream::Plugin::Core::fail';
        };
        event Ok => sub {
            call pass => 0;
            call name => 'fail';
            call diag => [ qr/Failed test 'fail'.*line $lines[2]/s, 'added diag' ];

            prop file =>    __FILE__;
            prop package => __PACKAGE__;
            prop line =>    $lines[2];
            prop subname =>     'Test::Stream::Plugin::Core::fail';
        };
        end;
    },
    "Got expected events for 'pass' and 'fail'"
);

ok(1, 'Testing ok');

@lines = ();
like(
    intercept {
        ok(1, 'pass', 'invisible diag'); push @lines => __LINE__;
        ok(0, 'fail');                   push @lines => __LINE__;
        ok(0, 'fail', 'added diag');     push @lines => __LINE__;
    },
    array {
        event Ok => sub {
            call pass => 1;
            call name => 'pass';
            call diag => undef;
            prop line => $lines[0];
        };
        event Ok => sub {
            call pass => 0;
            call name => 'fail';
            call diag => [ qr/Failed test 'fail'.*line $lines[1]/s ];
            prop trace => 'at ' . __FILE__ . " line $lines[1]";
        };
        event Ok => sub {
            call pass => 0;
            call name => 'fail';
            call diag => [ qr/Failed test 'fail'.*line $lines[2]/s, 'added diag' ];
            prop trace => 'at ' . __FILE__ . " line $lines[2]";
        };
        end;
    },
    "Got expected events for 'ok'"
);

is(1, 1, "testing is");
is('foo', 'foo', "testing is again");

note "Testing Diag";

like(
    intercept {
        diag "foo";
        diag "foo", ' ', "bar";
    },
    array {
        event Diag => { message => 'foo' };
        event Diag => { message => 'foo bar' };
    },
    "Got expected events for diag"
);

note "Testing Note";

like(
    intercept {
        note "foo";
        note "foo", ' ', "bar";
    },
    array {
        event Note => { message => 'foo' };
        event Note => { message => 'foo bar' };
    },
    "Got expected events for note"
);

like(
    intercept {
        BAIL_OUT 'oops';
        # Should not get here
        print STDERR "Something is wrong, did not bail out!\n";
        exit 255;
    },
    array {
        event Bail => { reason => 'oops' };
        end;
    },
    "Got bail event"
);

like(
    intercept {
        skip_all 'oops';
        # Should not get here
        print STDERR "Something is wrong, did not skip!\n";
        exit 255;
    },
    array {
        event Plan => { max => 0, directive => 'SKIP', reason => 'oops' };
        end;
    },
    "Got plan (skip_all) event"
);

like(
    intercept {
        plan(5);
    },
    array {
        event Plan => { max => 5 };
        end;
    },
    "Got plan"
);

like(
    intercept {
        ok(1);
        ok(2);
        done_testing;
    },
    array {
        event Ok => { pass => 1 };
        event Ok => { pass => 1 };
        event Plan => { max => 2 };
        end;
    },
    "Done Testing works"
);

like(
    intercept {
        ref_ok({}, 'HASH', 'pass');
        ref_ok([], 'ARRAY', 'pass');
        ref_ok({}, 'ARRAY', 'fail');
        ref_ok('xxx');
        ref_ok('xxx', 'xxx');
    },
    array {
        event Ok => { pass => 1 };
        event Ok => { pass => 1 };
        event Ok => sub {
            call pass => 0;
            call diag => [
                qr/Failed test/,
                qr/'HASH\(.*\)' is not a 'ARRAY' reference/
            ],
        };
        event Ok => { pass => 0, diag => [T(), qr/'xxx' is not a reference/] };
        event Ok => { pass => 0, diag => [T(), qr/'xxx' is not a reference/] };
        end;
    },
    "ref_ok tests"
);

{
    package X;

    sub can {
        my $thing = pop;
        return 1 if $thing =~ m/x/;
    }

    sub isa {
        my $thing = pop;
        return 1 if $thing =~ m/x/;
    }

    sub DOES {
        my $thing = pop;
        return 1 if $thing =~ m/x/;
    }
}

{
    package XYZ;
    use Carp qw/croak/;
    sub isa { croak 'oops' };
    sub can { croak 'oops' };
    sub DOES { croak 'oops' };
}

my $file = __FILE__;
my $line = __LINE__ + 2;
like(
    dies { isa_ok('XYZ', 'foo') },
    qr/oops at \Q$file\E line $line/,
    "Exception reports correctly"
);

like(
    intercept {
        isa_ok('X', qw/axe box fox/);
        can_ok('X', qw/axe box fox/);
        DOES_ok('X', qw/axe box fox/);

        isa_ok('X',  qw/foo bar axe box/);
        can_ok('X',  qw/foo bar axe box/);
        DOES_ok('X', qw/foo bar axe box/);
    },
    array {
        event Ok => { pass => 1, name => 'X->isa(...)' };
        event Ok => { pass => 1, name => 'X->can(...)' };
        event Ok => { pass => 1, name => 'X->DOES(...)' };

        event Ok => sub {
            call pass => 0;
            call diag => [
                qr/Failed/,
                "Failed: X->isa('foo')",
                "Failed: X->isa('bar')",
            ];
        };
        event Ok => sub {
            call pass => 0;
            call diag => [
                qr/Failed/,
                "Failed: X->can('foo')",
                "Failed: X->can('bar')",
            ];
        };
        event Ok => sub {
            call pass => 0;
            call diag => [
                qr/Failed/,
                "Failed: X->DOES('foo')",
                "Failed: X->DOES('bar')",
            ];
        };
        end;
    },
    "'can/isa/DOES_ok' events"
);

like(
    intercept {
        ok(0, "not todo");

        {
            my $todo = todo('todo 1');
            ok(0, 'todo fail');
        }

        ok(0, "not todo");

        my $todo = todo('todo 2');
        ok(0, 'todo fail');
        $todo = undef;

        ok(0, "not todo");

        todo 'todo 3' => sub {
            ok(0, 'todo fail');
        };

        ok(0, "not todo");
    },
    array {
        for my $id (1 .. 3) {
            event Ok => sub {
                call pass => 0;
                call effective_pass => 0;
                prop todo => undef;
            };
            event Ok => sub {
                call pass => 0;
                call effective_pass => 1;
                prop todo => "todo $id";
            };
        }
        event Ok => { pass => 0, effective_pass => 0 };
        end;
    },
    "Got todo events"
);

like(
    intercept {
        ok(1, 'pass');
        SKIP: {
            skip 'oops' => 5;

            ok(1, "Should not see this");
        }
    },
    array {
        event Ok => sub {
            call pass => 1;
            prop skip => undef;
        };
        event Ok => sub {
            call pass => 1;
            prop skip => 'oops';
        } for 1 .. 5;
        end;
    },
    "got skip events"
);

my $x = [];
my $y = [];
like(
    intercept {

        ref_is($x, $x, 'same x');
        ref_is($x, $y, 'not same');

        ref_is_not($x, $y, 'not same');
        ref_is_not($y, $y, 'same y');

        ref_is('x', $x, 'no ref');
        ref_is($x, 'x', 'no ref');

        ref_is_not('x', $x, 'no ref');
        ref_is_not($x, 'x', 'no ref');

        ref_is(undef, $x, 'undef');
        ref_is($x, undef, 'undef');

        ref_is_not(undef, $x, 'undef');
        ref_is_not($x, undef, 'undef');
    },
    array {
        event Ok => sub { call pass => 1 };
        event Ok => sub {
            call pass => 0;
            call diag => [ qr/Failed/, "'$x' is not the same reference as '$y'" ];
        };

        event Ok => sub { call pass => 1 };
        event Ok => sub {
            call pass => 0;
            call diag => [ qr/Failed/, "'$y' is the same reference as '$y'" ];
        };

        event Ok => sub {
            call pass => 0;
            call diag => [ qr/Failed/, "First argument 'x' is not a reference" ];
        };
        event Ok => sub {
            call pass => 0;
            call diag => [ qr/Failed/, "Second argument 'x' is not a reference" ];
        };

        event Ok => sub {
            call pass => 0;
            call diag => [ qr/Failed/, "First argument 'x' is not a reference" ];
        };
        event Ok => sub {
            call pass => 0;
            call diag => [ qr/Failed/, "Second argument 'x' is not a reference" ];
        };

        event Ok => sub {
            call pass => 0;
            call diag => [ qr/Failed/, "First argument '<undef>' is not a reference" ];
        };
        event Ok => sub {
            call pass => 0;
            call diag => [ qr/Failed/, "Second argument '<undef>' is not a reference" ];
        };

        event Ok => sub {
            call pass => 0;
            call diag => [ qr/Failed/, "First argument '<undef>' is not a reference" ];
        };
        event Ok => sub {
            call pass => 0;
            call diag => [ qr/Failed/, "Second argument '<undef>' is not a reference" ];
        };

        end;
    },
    "Ref checks"
);

my $warnings;
intercept {
    $warnings = warns {
        use utf8;

        my ($fh, $name) = tempfile();

        Test::Stream::Sync->stack->top->format(
            Test::Stream::Formatter::TAP->new(
                handles => [$fh, $fh, $fh],
            ),
        );

        set_encoding('utf8');
        ok(1, '†');
    };
};

ok(!$warnings, "set_encoding worked");

my $exception;
intercept {
    $exception = dies {
        set_encoding('utf8');
    };
};

like(
    $exception,
    qr/Unable to set encoding on formatter '<undef>'/,
    "Cannot set encoding without a formatter"
);

cmp_ok('x', 'eq', 'x', 'string pass');
cmp_ok(5, '==', 5, 'number pass');
cmp_ok(5, '==', 5.0, 'float pass');

$line = __LINE__ + 2;
like(
    warns { cmp_ok(undef, '==', undef, 'undef pass') },
    [
        qr/uninitialized value.*at \(eval in cmp_ok\) \Q$file\E line $line/,
    ],
    "got expected warnings (number)"
);

$line = __LINE__ + 2;
like(
    warns { cmp_ok(undef, 'eq', undef, 'undef pass') },
    [
        qr/uninitialized value.*at \(eval in cmp_ok\) \Q$file\E line $line/,
    ],
    "got expected warnings (string)"
);

like(
    intercept { cmp_ok('x', 'ne', 'x', 'string fail', 'extra diag') },
    array {
        event Ok => sub {
            call pass => 0;
            call name => 'string fail';
            call diag => [
                qr/Failed test/,
                '+-----+----+-------+',
                '| got | op | check |',
                '+-----+----+-------+',
                '| x   | ne | x     |',
                '+-----+----+-------+',
                'extra diag',
            ];
        };
        end;
    },
    "Got 1 string fail event"
);

like(
    intercept { cmp_ok(5, '==', 42, 'number fail', 'extra diag') },
    array {
        event Ok => sub {
            call pass => 0;
            call name => 'number fail';
            call diag => [
                qr/Failed test/,
                '+-----+----+-------+',
                '| got | op | check |',
                '+-----+----+-------+',
                '| 5   | == | 42    |',
                '+-----+----+-------+',
                'extra diag',
            ];
        };
        end;
    },
    "Got 1 number fail event"
);

my $warning;
$line = __LINE__ + 2;
like(
    intercept { $warning = warning { cmp_ok(5, '&& die', 42, 'number fail', 'extra diag') } },
    array {
        event Exception => { error => qr/42 at \(eval in cmp_ok\) \Q$file\E line $line/ };
        event Ok => sub {
            call pass => 0;
            call name => 'number fail';
            call diag => [
                qr/Failed test/,
                '+-----+--------+-------------+',
                '| got | op     | check       |',
                '+-----+--------+-------------+',
                '| 5   | && die | <EXCEPTION> |',
                '+-----+--------+-------------+',
                'extra diag',
            ];
        };
        end;
    },
    "Got exception in test"
);
like(
    $warning,
    qr/operator '&& die' is not supported \(you can add it to %Test::Stream::Plugin::Core::OPS\)/,
    "Got warning about unsupported operator"
);

{
    package Overloaded::Foo42;
    use overload
        'fallback' => 1,
        '0+' => sub { 42    },
        '""' => sub { 'foo' };
}

my $foo = bless {}, 'Overloaded::Foo42';

cmp_ok($foo, '==', 42, "numeric compare with overloading");
cmp_ok($foo, 'eq', 'foo', "string compare with overloading");

like(
    intercept {
        local $ENV{TS_TERM_SIZE} = 10000;
        cmp_ok($foo, 'ne', $foo, 'string fail', 'extra diag')
    },
    array {
        event Ok => sub {
            call pass => 0;
            call name => 'string fail';
            call diag => [
                qr/Failed test/,
                T(),
                qr/type.*got.*op.*check/,
                T(),
                qr/str.*foo.*ne.*foo/,
                qr/orig.*Overloaded::Foo42=HASH.*\|    \| Overloaded::Foo42=HASH/,
                T(),
                'extra diag',
            ];
        };
        end;
    },
    "Failed string compare, overload"
);

like(
    intercept {
        local $ENV{TS_TERM_SIZE} = 10000;
        cmp_ok($foo, '!=', $foo, 'number fail', 'extra diag')
    },
    array {
        event Ok => sub {
            call pass => 0;
            call name => 'number fail';
            call diag => [
                qr/Failed test/,
                T(),
                qr/type.*got.*op.*check/,
                T(),
                qr/num.*42.*!=.*42/,
                qr/orig.*Overloaded::Foo42=HASH.*\|    \| Overloaded::Foo42=HASH/,
                T(),
                'extra diag',
            ];
        };
        end;
    },
    "Failed number compare, overload"
);

$line = __LINE__ + 2;
like(
    intercept {
        local $ENV{TS_TERM_SIZE} = 10000;
        warning {
            cmp_ok($foo, '&& die', $foo, 'overload exception', 'extra diag')
        }
    },
    array {
        event Exception => { error => T() };
        event Ok => sub {
            call pass => 0;
            call name => 'overload exception';
            call diag => [
                qr/Failed test/,
                T(),
                qr/type.*got.*op.*check/,
                T(),
                qr/unsupported.*foo.*&& die.*<EXCEPTION>/,
                qr/orig.*Overloaded::Foo42=HASH.*\|\s+\| Overloaded::Foo42=HASH/,
                T(),
                'extra diag',
            ];
        };
        end;
    },
    "Got exception in test"
);

done_testing;
