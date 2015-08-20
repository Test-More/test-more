use Test::Stream -Spec, Class => ['Test::Stream::Compare'];

tests exporter => sub {
    Test::Stream::Compare->import(qw/compare get_build push_build pop_build build/);
    imported(qw/compare get_build push_build pop_build build/);

    my $check = mock {} => (
        add => [
            run => sub { return [@_] },
        ],
    );

    my $convert = sub { $_[-1]->{ran}++; $_[-1] };
    my $got = compare('foo', $check, $convert);

    like(
        $got,
        [
            { ran => 1 },
            undef,
            'foo',
            sub { $_[0] == $convert },
            {},
        ],
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
        $inner = get_build();
    }) }->();
    is($build->lines, [__LINE__ - 3, __LINE__ - 1], "got lines");
    is($build->file, __FILE__, "got file");

    same_ref($inner, $build, "Build was set inside block");

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

    my $mock = mock $CLASS => (
        override => [
            name => sub { 'bob' },
            verify => sub { $_[-1] eq 'xxx' },
        ],
    );

    is($one->render, 'bob', "got name");

    is(
        [$one->run('xxx', 'xxx', sub { $_[-1] }, {})],
        [],
        "Valid"
    );

    is(
        [$one->run([META => 'xxx'], 'xxy', sub { $_[-1] }, {})],
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

    is(
        [$one->run('xxx', 'xxy', sub { $_[-1] }, {xxy => 1})],
        [],
        "Break cycles"
    );
};

done_testing;
