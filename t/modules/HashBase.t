use strict;
use warnings;

use Test::Stream;

BEGIN {
    $INC{'My/HBase.pm'} = __FILE__;

    package My::HBase;
    use Test::Stream::HashBase(
        accessors => [qw/foo bar baz/],
    );

    use Test::Stream;
    is(FOO, 'foo', "FOO CONSTANT");
    is(BAR, 'bar', "BAR CONSTANT");
    is(BAZ, 'baz', "BAZ CONSTANT");
}

BEGIN {
    package My::HBaseSub;
    use Test::Stream::HashBase(
        accessors => [qw/apple pear/],
        base      => 'My::HBase',
    );

    use Test::Stream;
    is(FOO,   'foo',   "FOO CONSTANT");
    is(BAR,   'bar',   "BAR CONSTANT");
    is(BAZ,   'baz',   "BAZ CONSTANT");
    is(APPLE, 'apple', "APPLE CONSTANT");
    is(PEAR,  'pear',  "PEAR CONSTANT");

    my $bad = eval { Test::Stream::HashBase->import( base => 'foobarbaz' ); 1 };
    my $error = $@;
    ok(!$bad, "Threw exception");
    like($error, qr/Base class 'foobarbaz' is not a HashBase class/, "Expected error");
}

{
    package Consumer;
    use Test::Stream;

    my $bad = eval { Test::Stream::HashBase->import( base => 'Fake::Thing' ); 1 };
    my $error = $@;
    ok(!$bad, "Threw exception");
    like($error, qr/Base class 'Fake::Thing' is not a HashBase class/, "Expected error");
}

isa_ok('My::HBaseSub', 'My::HBase');

my $one = My::HBase->new(foo => 'a', bar => 'b', baz => 'c');
is($one->foo, 'a', "Accessor");
is($one->bar, 'b', "Accessor");
is($one->baz, 'c', "Accessor");
$one->set_foo('x');
is($one->foo, 'x', "Accessor set");
$one->set_foo(undef);

is(
    $one,
    {
        foo => undef,
        bar => 'b',
        baz => 'c',
    },
    'hash'
);

$one->clear_foo;
is(
    $one,
    {
        bar => 'b',
        baz => 'c',
    },
    'hash'
);


my $obj = bless {}, 'FAKE';

my $accessor = Test::Stream::HashBase->gen_accessor('foo');
my $getter   = Test::Stream::HashBase->gen_getter('foo');
my $setter   = Test::Stream::HashBase->gen_setter('foo');

is($obj, {}, "nothing set");

is($obj->$accessor(), undef, "nothing set");
is($obj->$accessor('foo'), 'foo', "set value");
is($obj->$accessor(), 'foo', "was set");

is($obj, {foo => 'foo'}, "set");

is($obj->$getter(), 'foo', "got the value");
is($obj->$getter(), 'foo', "got the value again");

is($obj, {foo => 'foo'}, "no change");

is( $obj->$setter, undef, "set to nothing" );
is($obj, {foo => undef}, "nothing");
is( $obj->$setter('foo'), 'foo', "set it again" );
is($obj, {foo => 'foo'}, "is set");
is($obj->$getter(), 'foo', "got the value");
is($obj->$accessor('foo'), 'foo', "get via accessor");

is($obj, {foo => 'foo'}, "no change");

done_testing;
