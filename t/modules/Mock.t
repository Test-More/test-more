use Test::Stream '-SpecTester';

use Scalar::Util qw/blessed/;

# Make sure the Fake package is empty for each test
around_each local_fake => sub {
    local $Carp::Level = ($Carp::Level || 0) + 1;
    my $inner = shift;
    local *Fake::;
    $inner->();
};

tests construction => sub {
    my %calls;
    my $c = mock 'Test::Stream::Mock' => (
        before => [ class => sub { $calls{class}++ } ],
        override => [
            parent => sub { $calls{parent}++ },
            child  => sub { $calls{child}++  },
        ],
        add => [
            foo => sub { $calls{foo}++ },
        ],
    );

    my $one = Test::Stream::Mock->new(
        class  => 'Fake',
        parent => 'Fake',
        child  => 'Fake',
        foo    => 'Fake',
    );
    isa_ok($one, 'Test::Stream::Mock');

    is(
        \%calls,
        { foo => 1 },
        "Only called foo, did not call class, parent or child"
    );

    $c->reset_all;

    my @args;
    $c->add(foo => sub { push @args => \@_ });

    $one = Test::Stream::Mock->new(
        class => 'Fake',
        foo   => 'string',
        foo   => [qw/a list/],
        foo   => {a => 'hash'},
    );
    isa_ok($one, 'Test::Stream::Mock');

    is(
        \@args,
        [
            [$one, 'string'],
            [$one, qw/a list/],
            [$one, qw/a hash/],
        ],
        "Called foo with proper args, called it multiple times"
    );

    like(
        dies { Test::Stream::Mock->new },
        qr/The 'class' field is required/,
        "Must specify a class"
    );

    like(
        dies { Test::Stream::Mock->new(class => 'Fake', foo => sub { 1 }) },
        qr/'CODE\(.*\)' is not a valid argument for 'foo'/,
        "Val must be sane"
    );
};

tests check => sub {
    my $one = Test::Stream::Mock->new(class => 'Fake');

    ok(lives { $one->_check }, "did not die");

    $one->set_child(1);

    like(
        dies {$one->_check},
        qr/There is an active child controller, cannot proceed/,
        "Cannot use a controller when it has a child"
    );
};

tests purge_on_destroy => sub {
    my $one = Test::Stream::Mock->new(class => 'Fake');

    ok(!$one->purge_on_destroy, "Not set by default");
    $one->purge_on_destroy(1);
    ok($one->purge_on_destroy, "Can set");
    $one->purge_on_destroy(0);
    ok(!$one->purge_on_destroy, "Can Unset");

    {
        # need to hide the glob assignment from the parser.
        no strict 'refs';
        *{"Fake::foo"} = sub { 'foo' };
    }

    can_ok('Fake', 'foo');
    $one = undef;
    can_ok('Fake', 'foo'); # Not purged

    $one = Test::Stream::Mock->new(class => 'Fake');
    $one->purge_on_destroy(1);
    $one = undef;
    my $stash = do { no strict 'refs'; \%{"Fake::"}; };
    ok(!keys %$stash, "no keys left in stash");
    ok(!Fake->can('foo'), 'purged sub');
};

tests stash => sub {
    my $one = Test::Stream::Mock->new(class => 'Fake');
    my $stash = $one->stash;

    ok($stash, "got a stash");
    is($stash, {}, "stash is empty right now");

    {
        # need to hide the glob assignment from the parser.
        no strict 'refs';
        *{"Fake::foo"} = sub { 'foo' };
    }

    ok($stash->{foo}, "See the new sub in the stash");
    ok(*{$stash->{foo}}{CODE}, "Code slot is populated");
};

tests file => sub {
    my $fake = Test::Stream::Mock->new(class => 'Fake');
    my $complex = Test::Stream::Mock->new(class => "A::Fake'Module::With'Separators");

    is($fake->file, "Fake.pm", "Got simple filename");

    is($complex->file, "A/Fake/Module/With/Separators.pm", "got complex filename");
};

describe block_load => sub {
    my $one;

    before_case not_set => sub {
        $one = undef;
        ok(!$INC{'Fake.pm'}, "Does not appear to be loaded yet");
    };

    after_each not_set => sub {
        $one = undef;
        ok(!$INC{'Fake.pm'}, "Does not appear to be loaded anymore");
    };

    case 'construction' => sub {
        $one = Test::Stream::Mock->new(class => 'Fake', block_load => 1);
    };

    case 'post construction' => sub {
        $one = Test::Stream::Mock->new(class => 'Fake');
        $one->block_load;
    };

    tests loaded => sub {
        ok($INC{'Fake.pm'}, '%INC is populated');
    };
};

tests block_load_fail => sub {
    $INC{'Fake.pm'} = 'path/to/Fake.pm';

    my $one = Test::Stream::Mock->new(class => 'Fake');

    like(
        dies { $one->block_load },
        qr/Cannot block the loading of module 'Fake', already loaded in file/,
        "Fails if file is already loaded"
    );
};

tests constructors => sub {
    my $one = Test::Stream::Mock->new(
        class => 'Fake',
        add_constructor => [new => 'hash'],
    );

    can_ok('Fake', 'new');

    my $i = Fake->new(foo => 'bar');
    isa_ok($i, 'Fake');
    is($i, { foo => 'bar' }, "Has params");

    $one->override_constructor(new => 'ref');

    my $ref = { 'foo' => 'baz' };
    $i = Fake->new($ref);
    isa_ok($i, 'Fake');
    is($i, { foo => 'baz' }, "Has params");
    is($i, $ref, "same reference");
    ok(blessed($ref), "blessed original ref");

    $one->override_constructor(new => 'ref_copy');
    $ref = { 'foo' => 'bat' };
    $i = Fake->new($ref);
    isa_ok($i, 'Fake');
    is($i, { foo => 'bat' }, "Has params");
    ok($i != $ref, "same reference");
    ok(!blessed($ref), "original ref is not blessed");

    like(
        dies { $one->override_constructor(new => 'bad') },
        qr/'bad' is not a known constructor type/,
        "Bad constructor type (override)"
    );

    like(
        dies { $one->add_constructor(uhg => 'bad') },
        qr/'bad' is not a known constructor type/,
        "Bad constructor type (add)"
    );
};

tests autoload => sub {
    my $one = Test::Stream::Mock->new(
        class => 'Fake',
        add_constructor => [new => 'hash'],
    );

    my $i = Fake->new;
    isa_ok($i, 'Fake');

    ok(!$i->can('foo'), "Cannot do 'foo'");
    like(dies {$i->foo}, qr/Can't locate object method "foo" via package "Fake"/, "Did not autload");

    $one->autoload;

    ok(lives { $i->foo }, "Created foo") || return;
    can_ok($i, 'foo'); # Added the sub to the package

    is($i->foo, undef, "no value");
    $i->foo('bar');
    is($i->foo, 'bar', "set value");
    $i->foo(undef);
    is($i->foo, undef, "unset value");

    ok(
        dies { $one->autoload },
        qr/Class 'Fake' already has an AUTOLOAD/,
        "Cannot add additional autoloads"
    );

    $one->reset_all;

    ok(!$i->can('AUTOLOAD'), "AUTOLOAD removed");
    ok(!$i->can('foo'), "AUTOLOADed sub removed");

    $one->autoload;
    $i->foo;

    ok($i->can('AUTOLOAD'), "AUTOLOAD re-added");
    ok($i->can('foo'), "AUTOLOADed sub re-added");

    $one = undef;

    ok(!$i->can('AUTOLOAD'), "AUTOLOAD removed (destroy)");
    ok(!$i->can('foo'), "AUTOLOADed sub removed (destroy)");
};

tests autoload_failures => sub {
    my $one = Test::Stream::Mock->new(class => 'fake');

    $one->add('AUTOLOAD' => sub { 1 });

    like(
        dies { $one->autoload },
        qr/Class 'fake' already has an AUTOLOAD/,
        "Cannot add autoload when there is already an autoload"
    );

    $one = undef;

    $one = Test::Stream::Mock->new(class => 'bad package');
    like(
        dies { $one->autoload },
        qr/syntax error/,
        "Error inside the autoload eval"
    );
};

tests ISA => sub {
    # This is to satisfy perl that My::Parent is loaded
    no warnings 'once';
    local *My::Parent::foo = sub { 'foo' };

    my $one = Test::Stream::Mock->new(
        class => 'Fake',
        add_constructor => [new => 'hash'],
        add => [
            -ISA => ['My::Parent'],
        ],
    );

    isa_ok('Fake', 'My::Parent');
    is(Fake->foo, 'foo', "Inherited sub from parent");
};

tests before => sub {
    {
        # need to hide the glob assignment from the parser.
        no strict 'refs';
        *{"Fake::foo"} = sub { 'foo' };
    }

    my $thing;

    my $one = Test::Stream::Mock->new(class => 'Fake');
    $one->before('foo' => sub { $thing = 'ran before foo' });

    ok(!$thing, "nothing ran yet");
    is(Fake->foo, 'foo', "got expected return");
    is($thing, 'ran before foo', "ran the before");
};

tests before => sub {
    my $want;
    {
        # need to hide the glob assignment from the parser.
        no strict 'refs';
        *{"Fake::foo"} = sub {
            $want = wantarray;
            return qw/f o o/ if $want;
            return 'foo' if defined $want;
            return;
        };
    }

    my $ran = 0;

    my $one = Test::Stream::Mock->new(class => 'Fake');
    $one->after('foo' => sub { $ran++ });

    is($ran, 0, "nothing ran yet");

    is(Fake->foo, 'foo', "got expected return (scalar)");
    is($ran, 1, "ran the before");
    ok(defined($want) && !$want, "scalar context");

    is([Fake->foo], [qw/f o o/], "got expected return (list)");
    is($ran, 2, "ran the before");
    is($want, 1, "list context");

    Fake->foo; # Void return
    is($ran, 3, "ran the before");
    is($want, undef, "void context");
};

tests around => sub {
    my @things;
    {
        # need to hide the glob assignment from the parser.
        no strict 'refs';
        *{"Fake::foo"} = sub {
            push @things => ['foo', \@_];
        };
    }

    my $one = Test::Stream::Mock->new(class => 'Fake');
    $one->around(foo => sub {
        my ($orig, @args) = @_;
        push @things => ['pre', \@args];
        $orig->('injected', @args);
        push @things => ['post', \@args];
    });

    Fake->foo(qw/a b c/);

    is(
        \@things,
        [
            ['pre'  => [qw/Fake a b c/]],
            ['foo'  => [qw/injected Fake a b c/]],
            ['post' => [qw/Fake a b c/]],
        ],
        "Got all the things!"
    );
};

tests 'add and current' => sub {
    my $one = Test::Stream::Mock->new(
        class => 'Fake',
        add_constructor => [new => 'hash'],
        add => [
            foo => { val => 'foo' },
            bar => 'rw',
            baz => { is => 'rw', field => '_baz' },
            -DATA => { my => 'data' },
            -DATA => [ qw/my data/ ],
            -DATA => sub { 'my data' },
            -DATA => \"data",
        ],
    );

    # Do some outside constructor to test both paths
    $one->add(
        reader => 'ro',
        writer => 'wo',
        -UHG   => \"UHG",
        rsub   => { val => sub { 'rsub' } },

        # Without $x the compiler gets smart and makes it always return the
        # same reference.
        nsub   => sub { my $x = ''; sub { $x . 'nsub' } },
    );

    can_ok('Fake', qw/new foo bar baz DATA reader writer rsub nsub/);

    like(
        dies { $one->add(foo => sub { 'nope' }) },
        qr/Cannot add '&Fake::foo', symbol is already defined/,
        "Cannot add a CODE symbol that is already defined"
    );

    like(
        dies { $one->add(-UHG => \'nope') },
        qr/Cannot add '\$Fake::UHG', symbol is already defined/,
        "Cannot add a SCALAR symbol that is already defined"
    );

    my $i = Fake->new();
    is($i->foo, 'foo', "by value");

    is($i->bar, undef, "Accessor not set");
    is($i->bar('bar'), 'bar', "Accessor setting");
    is($i->bar, 'bar', "Accessor was set");

    is($i->baz, undef, "no value yet");
    ok(!$i->{_bar}, "hash element is empty");
    is($i->baz('baz'), 'baz', "setting");
    is($i->{_baz}, 'baz', "set field");
    is($i->baz, 'baz', "got value");

    is($i->reader, undef, "No value for reader");
    is($i->reader('oops'), undef, "No value set");
    is($i->reader, undef, "Still No value for reader");
    is($i->{reader}, undef, 'element is empty');
    $i->{reader} = 'yay';
    is($i->{reader}, 'yay', 'element is set');

    is($i->{writer}, undef, "no value yet");
    $i->writer;
    is($i->{writer}, undef, "Set to undef");
    is($i->writer('xxx'), 'xxx', "Adding value");
    is($i->{writer}, 'xxx', "was set");
    is($i->writer, undef, "writer always writes");
    is($i->{writer}, undef, "Set to undef");

    is($i->rsub, $i->rsub, "rsub always returns the same ref");
    is($i->rsub->(), 'rsub', "ran rsub");

    ok($i->nsub != $i->nsub, "nsub returns a new ref each time");
    is($i->nsub->(), 'nsub', "ran nsub");

    is($i->DATA, 'my data', "direct sub assignment");
    # These need to be eval'd so the parser does not shortcut the glob references
    ok(eval <<'    EOT', "Ran glob checks") || diag "Error: $@";
        is($Fake::UHG, 'UHG', "Set package scalar (UHG)");
        is($Fake::DATA, 'data', "Set package scalar (DATA)");
        is(\%Fake::DATA, { my => 'data' }, "Set package hash");
        is(\@Fake::DATA, [ my => 'data' ], "Set package array");
        1;
    EOT

    is($one->current($_), $i->can($_), "current works for sub $_")
        for qw/new foo bar baz DATA reader writer rsub nsub/;

    is(${$one->current('$UHG')}, 'UHG', 'got current $UHG');
    is(${$one->current('$DATA')}, 'data', 'got current $DATA');
    is($one->current('&DATA'), $i->can('DATA'), 'got current &DATA');
    is($one->current('@DATA'), [qw/my data/], 'got current @DATA');
    is($one->current('%DATA'), {my => 'data'}, 'got current %DATA');

    $one = undef;

    ok(!Fake->can($_), "Removed sub $_") for qw/new foo bar baz DATA reader writer rsub nsub/;

    $one = Test::Stream::Mock->new(class => 'Fake');

    # Scalars are tricky, skip em for now.
    is($one->current('&DATA'), undef, 'no current &DATA');
    is($one->current('@DATA'), undef, 'no current @DATA');
    is($one->current('%DATA'), undef, 'no current %DATA');
};

tests 'override and orig' => sub {
    # Define things so we can override them
    eval <<'    EOT' || die $@;
        package Fake;

        sub new { 'old' }

        sub foo { 'old' }
        sub bar { 'old' }
        sub baz { 'old' }

        sub DATA { 'old' }
        our $DATA = 'old';
        our %DATA = (old => 'old');
        our @DATA = ('old');

        our $UHG = 'old';

        sub reader { 'old' }
        sub writer { 'old' }
        sub rsub   { 'old' }
        sub nsub   { 'old' }
    EOT

    my $check_initial = sub {
        is(Fake->$_, 'old', "$_ is not overriden") for qw/new foo bar baz DATA reader writer rsub nsub/;
        ok(eval <<'        EOT', "Ran glob checks") || diag "Error: $@";
            is($Fake::UHG,  'old',  'old package scalar (UHG)');
            is($Fake::DATA, 'old', "Old package scalar (DATA)");
            is(\%Fake::DATA, {old => 'old'}, "Old package hash");
            is(\@Fake::DATA, ['old'], "Old package array");
            1;
        EOT
    };

    $check_initial->();

    my $one = Test::Stream::Mock->new(
        class => 'Fake',
        override_constructor => [new => 'hash'],
        override => [
            foo => { val => 'foo' },
            bar => 'rw',
            baz => { is => 'rw', field => '_baz' },
            -DATA => { my => 'data' },
            -DATA => [ qw/my data/ ],
            -DATA => sub { 'my data' },
            -DATA => \"data",
        ],
    );

    # Do some outside constructor to test both paths
    $one->override(
        reader => 'ro',
        writer => 'wo',
        -UHG   => \"UHG",
        rsub   => { val => sub { 'rsub' } },

        # Without $x the compiler gets smart and makes it always return the
        # same reference.
        nsub   => sub { my $x = ''; sub { $x . 'nsub' } },
    );

    like(
        dies { $one->override(nuthin => sub { 'nope' }) },
        qr/Cannot override '&Fake::nuthin', symbol is not already defined/,
        "Cannot override a CODE symbol that is not defined"
    );

    like(
        dies { $one->override(-nuthin => \'nope') },
        qr/Cannot override '\$Fake::nuthin', symbol is not already defined/,
        "Cannot override a SCALAR symbol that is not defined"
    );

    my $i = Fake->new();
    is($i->foo, 'foo', "by value");

    is($i->bar, undef, "Accessor not set");
    is($i->bar('bar'), 'bar', "Accessor setting");
    is($i->bar, 'bar', "Accessor was set");

    is($i->baz, undef, "no value yet");
    ok(!$i->{_bar}, "hash element is empty");
    is($i->baz('baz'), 'baz', "setting");
    is($i->{_baz}, 'baz', "set field");
    is($i->baz, 'baz', "got value");

    is($i->reader, undef, "No value for reader");
    is($i->reader('oops'), undef, "No value set");
    is($i->reader, undef, "Still No value for reader");
    is($i->{reader}, undef, 'element is empty');
    $i->{reader} = 'yay';
    is($i->{reader}, 'yay', 'element is set');

    is($i->{writer}, undef, "no value yet");
    $i->writer;
    is($i->{writer}, undef, "Set to undef");
    is($i->writer('xxx'), 'xxx', "Adding value");
    is($i->{writer}, 'xxx', "was set");
    is($i->writer, undef, "writer always writes");
    is($i->{writer}, undef, "Set to undef");

    is($i->rsub, $i->rsub, "rsub always returns the same ref");
    is($i->rsub->(), 'rsub', "ran rsub");

    ok($i->nsub != $i->nsub, "nsub returns a new ref each time");
    is($i->nsub->(), 'nsub', "ran nsub");

    is($i->DATA, 'my data', "direct sub assignment");
    # These need to be eval'd so the parser does not shortcut the glob references
    ok(eval <<'    EOT', "Ran glob checks") || diag "Error: $@";
        is($Fake::UHG, 'UHG', "Set package scalar (UHG)");
        is($Fake::DATA, 'data', "Set package scalar (DATA)");
        is(\%Fake::DATA, { my => 'data' }, "Set package hash");
        is(\@Fake::DATA, [ my => 'data' ], "Set package array");
        1;
    EOT

    is($one->current($_), $i->can($_), "current works for sub $_")
        for qw/new foo bar baz DATA reader writer rsub nsub/;

    is(${$one->current('$UHG')}, 'UHG', 'got current $UHG');
    is(${$one->current('$DATA')}, 'data', 'got current $DATA');
    is($one->current('&DATA'), $i->can('DATA'), 'got current &DATA');
    is($one->current('@DATA'), [qw/my data/], 'got current @DATA');
    is($one->current('%DATA'), {my => 'data'}, 'got current %DATA');

    is($one->orig($_)->(), 'old', "got original $_") for qw/new foo bar baz DATA reader writer rsub nsub/;

    is(${$one->orig('$UHG')},  'old',  'old package scalar (UHG)');
    is(${$one->orig('$DATA')}, 'old', "Old package scalar (DATA)");
    is($one->orig('%DATA'), {old => 'old'}, "Old package hash");
    is($one->orig('@DATA'), ['old'], "Old package array");

    like(
        dies { $one->orig('not_mocked') },
        qr/Symbol '&not_mocked' is not mocked/,
        "Cannot get original for something not mocked"
    );

    like(
        dies { Test::Stream::Mock->new(class => 'Fake2')->orig('no_mocks') },
        qr/No symbols have been mocked yet/,
        "Cannot get original when nothing is mocked"
    );

    $one = undef;

    $check_initial->();

    $one = Test::Stream::Mock->new(class => 'Fake');
};

tests parse_sym => sub {
    my $p = Test::Stream::Mock->can('_parse_sym');

    is([$p->('foo')],  [foo  => 'CODE'],   "parsed no sigil");
    is([$p->('_foo')], [_foo => 'CODE'],   "parsed underscore");
    is([$p->('&foo')], [foo  => 'CODE'],   "parsed code sigil");
    is([$p->('$foo')], [foo  => 'SCALAR'], "parsed scalar sigil");
    is([$p->('@foo')], [foo  => 'ARRAY'],  "parsed array sigil");
    is([$p->('%foo')], [foo  => 'HASH'],   "parsed hash sigil");

    like(
        dies { $p->('*foo') },
        qr/'\*' is not a supported sigil/,
        "Cannot parse globs"
    );
};

tests restore_reset => sub {
    my $one = Test::Stream::Mock->new( class => 'Fake' );

    $one->add(foo => sub { 'a' });
    $one->add(-foo => \'a');
    $one->add(-foo => ['a']);

    $one->override(foo => sub { 'b' });
    $one->override(foo => sub { 'c' });
    $one->override(foo => sub { 'd' });
    $one->override(foo => sub { 'e' });

    is(Fake->foo, 'e', "latest override");
    is(eval '$Fake::foo', 'a', "scalar override remains");
    is(eval '\@Fake::foo', ['a'], "array override remains");

    $one->restore('foo');
    is(Fake->foo, 'd', "second latest override");
    is(eval '$Fake::foo', 'a', "scalar override remains");
    is(eval '\@Fake::foo', ['a'], "array override remains");

    $one->restore('foo');
    is(Fake->foo, 'c', "second latest override");
    is(eval '$Fake::foo', 'a', "scalar override remains");
    is(eval '\@Fake::foo', ['a'], "array override remains");

    $one->reset('foo');
    ok(!Fake->can('foo'), "no more override");
    is(eval '$Fake::foo', 'a', "scalar override remains");
    is(eval '\@Fake::foo', ['a'], "array override remains");

    $one->add(foo => sub { 'a' });
    is(Fake->foo, 'a', "override");

    $one->reset_all;
    ok(!Fake->can('foo'), "no more override");
    is(eval '$Fake::foo', undef, "scalar override removed");

    no strict 'refs';
    ok(!*{'Fake::foo'}{ARRAY}, "array override removed");
};

done_testing;
