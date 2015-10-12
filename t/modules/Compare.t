use Test::Stream -V1, Spec, Class => ['Test::Stream::Compare'];

tests exporter => sub {
    Test::Stream::Compare->import(qw/compare get_build push_build pop_build build/);
    imported_ok(qw/compare get_build push_build pop_build build/);

    my $check = mock {} => (
        add => [
            run => sub { my $self = shift; return {@_, self => $self} },
        ],
    );

    my $convert = sub { $_[-1]->{ran}++; $_[-1] };
    my $got = compare('foo', $check, $convert);

    like(
        $got,
        {
            self    => {ran => 1},
            id      => undef,
            got     => 'foo',
            convert => sub  { $_ == $convert },
            seen    => {},
        },
        "check got expected args"
    );


    is(get_build(), undef, "no build");

    like(
        dies { pop_build(['a']) },
        qr/INTERNAL ERROR: Attempted to pop incorrect build, have undef, tried to pop ARRAY/,
        "Got error popping from nothing"
    );

    push_build(['a']);
    is(get_build(), ['a'], "pushed build");

    like(
        dies { pop_build() },
        qr/INTERNAL ERROR: Attempted to pop incorrect build, have ARRAY\(.*\), tried to pop undef/,
        "Got error popping undef"
    );

    like(
        dies { pop_build(['a']) },
        qr/INTERNAL ERROR: Attempted to pop incorrect build, have ARRAY\(.*\), tried to pop ARRAY/,
        "Got error popping wrong ref"
    );

    # Don't ever actually do this...
    ok(pop_build(get_build()), "Popped");

    my $inner;
    my $build = sub { build('Test::Stream::Compare::Array', sub {
        local $_ = 1;
        $inner = get_build();
    }) }->();
    is($build->lines, [__LINE__ - 4, __LINE__ - 1], "got lines");
    is($build->file, __FILE__, "got file");

    ref_is($inner, $build, "Build was set inside block");

    like(
        dies { my $x = build('Test::Stream::Compare::Array', sub { die 'xxx' }) },
        qr/xxx at/,
        "re-threw exception"
    );

    like(
        dies { build('Test::Stream::Compare::Array', sub { }) },
        qr/should not be called in void context/,
        "You need to retain the return from build"
    );
};

tests object_base => sub {
    my $one = $CLASS->new();
    isa_ok($one, $CLASS);

    is($one->delta_class, 'Test::Stream::Delta', "Got expected delta class");

    is([$one->deltas],    [], "no deltas");
    is([$one->got_lines], [], "no lines");

    is($one->operator, '', "no default operator");

    like(dies { $one->verify }, qr/unimplemented/, "unimplemented");
    like(dies { $one->name },   qr/unimplemented/, "unimplemented");

    mock $CLASS => (
        override => [
            name => sub { 'bob' },
            verify => sub { shift; my %p = @_; $p{got} eq 'xxx' },
        ],
    );

    is($one->render, 'bob', "got name");

    is(
        [$one->run(id => 'xxx', got => 'xxx', convert => sub { $_[-1] }, seen => {})],
        [],
        "Valid"
    );

    is(
        [$one->run(id => [META => 'xxx'], got => 'xxy', convert => sub { $_[-1] }, seen => {})],
        [
            {
                verified => '',
                id => [META => 'xxx'],
                got => 'xxy',
                chk => {%$one},
                children => [],
            }
        ],
        "invalid"
    );
};

done_testing;
