#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

{
    package Some::Thing;

    use Test::Builder2::Mouse;
    with "Test::Builder2::CanTry";
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

done_testing;
