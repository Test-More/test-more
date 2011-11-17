#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN { require 't/test.pl' }

{
    package Foo;

    use TB2::Mouse;
    with 'TB2::HasDefault';
}

{
    my $foo = Foo->default;
    isa_ok $foo, "Foo";

    my $same = Foo->default;
    is $foo, $same;

    my $other = Foo->create;
    isa_ok $other, "Foo";
    isnt $foo, $other;

    ok !eval { Foo->new };
    like $@, qr/there is no new/;
}

# Set the default
{
    my $orig  = Foo->default;
    my $thing = Foo->create;
    Foo->default($thing);

    is( Foo->default, $thing );
}

done_testing();
