use strict;
use warnings;

use Test::More;
use lib 'lib';

BEGIN {
    $INC{'My/HBase.pm'} = __FILE__;

    package My::HBase;
    use Test::Stream::HashBase(
        accessors => [qw/foo bar baz/],
    );

    use Test::More;
    is(FOO, 'foo', "FOO CONSTANT");
    is(BAR, 'bar', "BAR CONSTANT");
    is(BAZ, 'baz', "BAZ CONSTANT");

    my $bad = eval { Test::Stream::HashBase->import( accessors => [qw/foo/] ); 1 };
    my $error = $@;
    ok(!$bad, "Threw exception");
    like($error, qr/field 'foo' already defined/, "Expected error");
}

BEGIN {
    package My::HBaseSub;
    use Test::Stream::HashBase(
        accessors => [qw/apple pear/],
        base      => 'My::HBase',
    );

    use Test::More;
    is(FOO,   'foo',   "FOO CONSTANT");
    is(BAR,   'bar',   "BAR CONSTANT");
    is(BAZ,   'baz',   "BAZ CONSTANT");
    is(APPLE, 'apple', "APPLE CONSTANT");
    is(PEAR,  'pear',  "PEAR CONSTANT");

    my $bad = eval { Test::Stream::HashBase->import( base => 'foobarbaz' ); 1 };
    my $error = $@;
    ok(!$bad, "Threw exception");
    like($error, qr/My::HBaseSub is already a subclass of 'My::HBase'/, "Expected error");
}

{
    package My::HBase;
    my $bad = eval { Test::Stream::HashBase->import( accessors => [qw/xerxes/] ); 1 };
    my $error = $@;
    ok(!$bad, "Threw exception");
    like($error, qr/Cannot add accessor, metadata is locked due to a subclass being initialized/, "Expected error");
}

{
    package Consumer;
    use My::HBase qw/BAR/;
    use Test::More;

    is(BAR, 'bar', "Can import contants");

    my $bad = eval { Test::Stream::HashBase->import( base => 'Test::More' ); 1 };
    my $error = $@;
    ok(!$bad, "Threw exception");
    like($error, qr/Base class 'Test::More' is not a subclass of Test::Stream::HashBase/, "Expected error");
}

isa_ok('My::HBase', 'Test::Stream::HashBase');
isa_ok('My::HBaseSub', 'Test::Stream::HashBase');
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
