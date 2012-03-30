#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }


note "Stringify"; {
    {
        package My::Stringify;

        use TB2::Mouse;
        use TB2::Types;

        has stringify =>
          is        => 'rw',
          isa       => 'TB2::Stringify',
          coerce    => 1;
    }

    my $obj = My::Stringify->new;

    my $tests_ref = {
        'regex' => qr/hello/,
        'empty string' => '',
        'string' => 'string',
        'hashref' => { my => 'test' },
        'arrayref' => ['my','test'],
        'object' => $obj,
        'sub' => sub { 1 },
    };

    while(my ($test, $ref) = each %$tests_ref) {
        is $obj->stringify($ref), "$ref", 'stringify '.$test;
    }

}


done_testing;

