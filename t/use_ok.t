use Test::More tests => 7;

# Using Symbol because it's core and exports lots of stuff.
{
    package Foo::1;
    ::use_ok("Symbol");
    ::ok( defined &gensym,        'use_ok() no args exports defaults' );
}

{
    package Foo::2;
    ::use_ok("Symbol", qw(qualify));
    ::ok( !defined &gensym,       '  one arg, defaults overriden' );
    ::ok( defined &qualify,       '  right function exported' );
}

{
    package Foo::3;
    ::use_ok("Symbol", qw(gensym ungensym));
    ::ok( defined &gensym && defined &ungensym,   '  multiple args' );
}
