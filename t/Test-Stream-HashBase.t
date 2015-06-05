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

is_deeply(
    $one,
    {
        foo => undef,
        bar => 'b',
        baz => 'c',
    },
    'hash'
);

done_testing;
