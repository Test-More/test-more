use Test::Stream -V1, Spec, Mock => '*';

use Scalar::Util qw/reftype blessed/;

can_ok(
    __PACKAGE__,
    qw{
        mock_obj mock_class
        mock_do  mock_build
        mock_accessor mock_accessors
        mock_getter   mock_getters
        mock_setter   mock_setters
        mock_building
    }
);

tests generators => sub {
    # These are all thin wrappers around HashBase subs, we just test that we
    # get subs, HashBase tests that the thing we are wrapping produce the
    # correct type of subs.

    my %accessors = mock_accessors qw/foo bar baz/;
    is([sort keys %accessors], [sort qw/foo bar baz/], "All 3 keys set");
    is(reftype($accessors{$_}), 'CODE', "sub as value for $_") for qw/foo bar baz/;

    is(reftype(mock_accessor('xxx')), 'CODE', "Generated an accessor");

    my %getters = mock_getters 'get_' => qw/foo bar baz/;
    is([sort keys %getters], [sort qw/get_foo get_bar get_baz/], "All 3 keys set");
    is(reftype($getters{"get_$_"}), 'CODE', "sub as value for get_$_") for qw/foo bar baz/;

    is(reftype(mock_getter('xxx')), 'CODE', "Generated a getter");

    my %setters = mock_setters 'set_' => qw/foo bar baz/;
    is([sort keys %setters], [sort qw/set_foo set_bar set_baz/], "All 3 keys set");
    is(reftype($setters{"set_$_"}), 'CODE', "sub as value for set_$_") for qw/foo bar baz/;

    is(reftype(mock_setter('xxx')), 'CODE', "Generated a setter");
};

describe mocks => sub {
    my $inst;
    my $control;
    my $class;

    case object => sub {
        $inst      = mock_obj({}, add_constructor => [new => 'hash']);
        ($control) = mocked($inst);
        $class     = $control->class;
    };

    case package => sub {
        $control = mock_class('Fake::Class', add_constructor => [new => 'hash']);
        $class   = $control->class;
        $inst    = $class->new;
    };

    before_each verify => sub {
        isa_ok($control, 'Test::Stream::Mock');
        isa_ok($inst, $class);
        ok($class, "got a class");
    };

    tests mocked => sub {
        ok(!mocked('main'), "main class is not mocked");
        is(mocked($inst), 1, "Only 1 control object for this instance");
        my ($c) = mocked($inst);
        ref_is($c, $control, "got correct control when checking if an object was mocked");

        my $control2 = mock_class($control->class);

        is(mocked($inst), 2, "now 2 control objects for this instance");
        my ($c1, $c2) = mocked($inst);
        ref_is($c1, $control, "got first control");
        ref_is($c2, $control2, "got second control");
    };

    tests build_and_do => sub {
        like(
            dies { mock_build(undef, sub { 1 }) },
            qr/mock_build requires a Test::Stream::Mock object as its first argument/,
            "control is required",
        );

        like(
            dies { mock_build($control, undef) },
            qr/mock_build requires a coderef as its second argument/,
            "Must have a coderef to build"
        );

        like(
            dies { mock_do add => (foo => sub { 'foo' }) },
            qr/Not currently building a mock/,
            "mock_do outside of a build fails"
        );

        ok(!mock_building, "no mock is building");
        my $ran = 0;
        mock_build $control => sub {
            is(mock_building, $control, "Building expected control");

            like(
                dies { mock_do 'foo' => 1 },
                qr/'foo' is not a valid action for mock_do\(\)/,
                "invalid action"
            );

            mock_do add => (
                foo => sub { 'foo' },
            );

            can_ok($inst, 'foo');
            is($inst->foo, 'foo', "added sub");

            $ran++;
        };

        ok(!mock_building, "no mock is building");
        ok($ran, "build sub completed successfully");
    };
};

tests mock_obj => sub {
    my $ref = {};
    my $obj = mock_obj $ref;
    is($ref, $obj, "blessed \$ref");
    is($ref->foo(1), 1, "is vivifying object");

    my $ran = 0;
    $obj = mock_obj(sub { $ran++ });
    is($ref->foo(1), 1, "is vivifying object");
    is($ran, 1, "code ran");

    $obj = mock_obj { foo => 'foo' } => (
        add => [ bar => sub { 'bar' }],
    );

    is($obj->foo, 'foo', "got value for foo");
    is($obj->bar, 'bar', "got value for bar");

    my ($c) = mocked($obj);
    ok($c, "got control");
    is($obj->{'~~MOCK~CONTROL~~'}, $c, "control is stashed");

    my $class = $c->class;
    my $file = $c->file;
    ok($INC{$file}, "Mocked Loaded");

    $obj = undef;
    $c = undef;

    ok(!$INC{$file}, "Not loaded anymore");
};

tests mock_class_basic => sub {
    my $c = mock_class 'Fake';
    isa_ok($c, 'Test::Stream::Mock');
    is($c->class, 'Fake', "Control for 'Fake'");
    $c = undef;

    # Check with an instance
    my $i = bless {}, 'Fake';
    $c = mock_class $i;
    isa_ok($c, 'Test::Stream::Mock');
    is($c->class, 'Fake', "Control for 'Fake'");

    is([mocked($i)], [$c], "is mocked");
};

describe mock_class_spec => sub {
    mock_class Fake1 => ( add => [ check => sub { 1 } ] );

    before_all  ba => sub { mock_class Fake2 => ( add => [ check => sub { 2 } ])};
    before_each be => sub { mock_class Fake3 => ( add => [ check => sub { 3 } ])};

    is( Fake1->check, 1, "mock applies to describe block");

    around_each ae => sub {
        my $inner = shift;
        mock_class Fake4 => ( add => [check => sub { 4 } ]);
        $inner->();
    };

    tests the_test => sub {
        mock_class Fake5 => ( add => [check => sub { 5 } ]);

        is( Fake1->check, 1, "mock 1");
        is( Fake2->check, 2, "mock 2");
        is( Fake3->check, 3, "mock 3");
        is( Fake4->check, 4, "mock 4");
        is( Fake5->check, 5, "mock 5");
    };

    describe nested => sub {
        tests inner => sub {
            is( Fake1->check, 1, "mock 1");
            is( Fake2->check, 2, "mock 2");
            is( Fake3->check, 3, "mock 3");
            is( Fake4->check, 4, "mock 4");
            ok(!Fake5->can('check'), "mock 5 did not leak");
        };
    };
};

tests post => sub {
    ok(!"Fake$_"->can('check'), "mock $_ did not leak") for 1 .. 5;
};

ok(!"Fake$_"->can('check'), "mock $_ did not leak") for 1 .. 5;

tests just_mock => sub {
    like(
        dies { mock undef },
        qr/undef is not a valid first argument to mock/,
        "Cannot mock undef"
    );

    like(
        dies { mock 'fakemethodname' },
        qr/'fakemethodname' does not look like a package name, and is not a valid control method/,
        "invalid mock arg"
    );

    my $c = mock 'Fake';
    isa_ok($c, 'Test::Stream::Mock');
    is($c->class, 'Fake', "mocked correct class");
    mock $c => sub {
        mock add => (foo => sub { 'foo' });
    };

    can_ok('Fake', 'foo');
    is(Fake->foo(), 'foo', "mocked build, mocked do");

    my $o = mock;
    ok(blessed($o), "created object");
    $c = mocked($o);
    ok($c, "got control");

    $o = mock { foo => 'foo' };
    is($o->foo, 'foo', "got the expected result");
    is($o->{foo}, 'foo', "blessed the reference");

    $c = mock $o;
    isa_ok($o, $c->class);


    my $code = mock accessor => 'foo';
    ok(reftype($code), 'CODE', "Generated an accessor");
};

done_testing;
