#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }


note "LC_AlphaNumUS_Str"; {
    {
        package My::LC::AlphaNumUS::Str;

        use TB2::Mouse;
        use TB2::Types;

        has lc_alphanumus_str =>
          is        => 'rw',
          isa       => 'TB2::LC_AlphaNumUS_Str';
    }

    my $obj = My::LC::AlphaNumUS::Str->new;

    $obj->lc_alphanumus_str("helloworld");
    is $obj->lc_alphanumus_str, "helloworld";

    $obj->lc_alphanumus_str("1337");
    is $obj->lc_alphanumus_str, "1337";

    $obj->lc_alphanumus_str("_");
    is $obj->lc_alphanumus_str, "_";

    $obj->lc_alphanumus_str("1world");
    is $obj->lc_alphanumus_str, "1world";

    $obj->lc_alphanumus_str("hello_world");
    is $obj->lc_alphanumus_str, "hello_world";

    $obj->lc_alphanumus_str("_1337");
    is $obj->lc_alphanumus_str, "_1337";

    $obj->lc_alphanumus_str("1_world");
    is $obj->lc_alphanumus_str, "1_world";

    ok !eval { $obj->lc_alphanumus_str("HelloWorld");   1 }, "upper case";
    ok !eval { $obj->lc_alphanumus_str("hello world");  1 }, "space";
    ok !eval { $obj->lc_alphanumus_str(undef);          1 }, "undef";
    ok !eval { $obj->lc_alphanumus_str("");             1 }, "empty string";
    ok !eval { $obj->lc_alphanumus_str("hello!");       1 }, "punctuation";
}

done_testing;
