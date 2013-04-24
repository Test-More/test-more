#!/usr/bin/env perl

use strict;
use warnings;

BEGIN { require "t/test.pl" }

note "Setting up test class"; {
    package Some::Object;
    use TB2::Mouse;
    with "TB2::CanAsHash";

    has foo =>
      is        => 'rw';

    has _private =>
      is        => 'rw';
}


note "empty object"; {
    my $obj = Some::Object->new;

    is_deeply $obj->as_hash, {}, "undefined attributes are ignored";
}


note "private accessors"; {
    my $obj = Some::Object->new(
        foo             => 23,
        _private        => 42,
    );

    is_deeply $obj->as_hash, { foo => 23 };
}

done_testing;
