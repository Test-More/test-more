use Test::Stream '-Tester';

{
    $INC{'Foo.pm'} = 1;
    package Foo;
    use Test::Stream::Plugin;

    sub load_ts_plugin {
        return 'Foo';
    }
}

can_ok('Foo', 'import');

is(Foo->load_ts_plugin, 'Foo', "got expected return");
is(Foo->import, 'Foo', "Delegated");

done_testing;
