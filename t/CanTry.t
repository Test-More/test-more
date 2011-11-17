#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

{
    package Some::Thing;

    use TB2::Mouse;
    with "TB2::CanTry";
}


note("try protection"); {
    local $!;
    local $@;
    local $SIG{__DIE__};

    my $return = Some::Thing->try(sub {
        $! = 42;
        $@ = "alfkjadkfj";
        $SIG{__DIE__} = sub {};
        return 23;
    });

    is $return, 23,     "try return";
    ok !$!,             '$! protected';
    ok !$@,             '$@ protected';
    ok !$SIG{__DIE__},  '$SIG{__DIE__} protected';
}


note "try array context"; {
    is_deeply [ Some::Thing->try( sub { die "foo\n" } ) ], [ undef, "foo\n" ];
    is_deeply [ Some::Thing->try( sub { 42 } )          ], [ 42, '' ];
}


note "stress test"; {
    local $SIG{__DIE__} = sub { fail("DIE handler called: @_") };
    local $@ = 42;
    local $! = 23;

    is( Some::Thing->try(sub { 2 }), 2 );
    is( Some::Thing->try(sub { return '' }), '' );

    is( Some::Thing->try(sub { die; }), undef );

    is_deeply [Some::Thing->try(sub { die "Foo\n" })], [undef, "Foo\n"];

    is $@, 42;
    cmp_ok $!, '==', 23;
}


note "die_on_fail"; {
    ok !eval {
        Some::Thing->try(sub { die "Died\n" }, die_on_fail => 1);
    };
    is $@, "Died\n";
}


done_testing;
