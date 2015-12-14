use strict;
use warnings;
BEGIN { require "t/tools.pl" };

BEGIN {
    $INC{'My/HBase.pm'} = __FILE__;

    package My::HBase;
    use Test2::Util::HashBase qw/foo bar baz/;

    main::is(FOO, 'foo', "FOO CONSTANT");
    main::is(BAR, 'bar', "BAR CONSTANT");
    main::is(BAZ, 'baz', "BAZ CONSTANT");
}

BEGIN {
    package My::HBaseSub;
    use base 'My::HBase';
    use Test2::Util::HashBase qw/apple pear/;

    main::is(FOO,   'foo',   "FOO CONSTANT");
    main::is(BAR,   'bar',   "BAR CONSTANT");
    main::is(BAZ,   'baz',   "BAZ CONSTANT");
    main::is(APPLE, 'apple', "APPLE CONSTANT");
    main::is(PEAR,  'pear',  "PEAR CONSTANT");
}

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

$one->clear_foo;
is_deeply(
    $one,
    {
        bar => 'b',
        baz => 'c',
    },
    'hash'
);

done_testing;
