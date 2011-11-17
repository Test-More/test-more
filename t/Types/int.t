#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }


note "Positive_Int"; {
    {
        package My::Positive::Int;

        use TB2::Mouse;
        use TB2::Types;

        has positive_int =>
          is        => 'rw',
          isa       => 'TB2::Positive_Int';
    }

    my $obj = My::Positive::Int->new;

    $obj->positive_int(0);
    is $obj->positive_int, 0;

    $obj->positive_int(1);
    is $obj->positive_int, 1;

    $obj->positive_int(2_000_000);
    is $obj->positive_int, 2_000_000;

    ok !eval { $obj->positive_int(-1);    1 },  "negative integer";
    ok !eval { $obj->positive_int(1.5);   1 },  "decimals";
    ok !eval { $obj->positive_int(undef); 1 },  "undef";
    ok !eval { $obj->positive_int("one"); 1 },  "strings";
    ok !eval { $obj->positive_int("");    1 },  "empty strings";
    ok !eval { $obj->positive_int(" 12 "); 1 }, "stringy numbers";
}


note "Positive_NonZero_Int"; {
    {
        package My::Positive::NonZero::Int;

        use TB2::Mouse;
        use TB2::Types;

        has positive_nonzero_int =>
          is        => 'rw',
          isa       => 'TB2::Positive_NonZero_Int';
    }

    my $obj = My::Positive::NonZero::Int->new;

    $obj->positive_nonzero_int(1);
    is $obj->positive_nonzero_int, 1;

    $obj->positive_nonzero_int(2_000_000);
    is $obj->positive_nonzero_int, 2_000_000;

    ok !eval { $obj->positive_nonzero_int(0);     1 },  "zero";
    ok !eval { $obj->positive_nonzero_int(-1);    1 },  "negative integer";
    ok !eval { $obj->positive_nonzero_int(1.5);   1 },  "decimals";
    ok !eval { $obj->positive_nonzero_int(undef); 1 },  "undef";
    ok !eval { $obj->positive_nonzero_int("one"); 1 },  "strings";
    ok !eval { $obj->positive_nonzero_int("");    1 },  "empty strings";
    ok !eval { $obj->positive_nonzero_int(" 12 "); 1 }, "stringy numbers";
}

done_testing;
