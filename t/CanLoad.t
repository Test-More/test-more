#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

{
    package Some::Thing;

    use TB2::Mouse;
    with "TB2::CanLoad";
}


note("try protection"); {
    local $! = 99;
    local $@ = "foo";
    my $handler = sub { ok(0, "handler should not fire") };
    local $SIG{__DIE__} = $handler;

    ok !$INC{"Text/ParseWords.pm"};
    my $return = Some::Thing->load("Text::ParseWords");

    ok $return,         "load() return";
    ok Text::ParseWords->can("quotewords"), "module loaded";

    cmp_ok $!, '==', 99,'$! protected';
    is $@, "foo",       '$@ protected';
    is $SIG{__DIE__}, $handler, '$SIG{__DIE__} protected';
}

note "module fails to load"; {
    ok !eval { Some::Thing->load("I::Do::Not::Exist"); 1 };
    like $@, qr{^\QCan't locate I/Do/Not/Exist.pm};
}


done_testing;
