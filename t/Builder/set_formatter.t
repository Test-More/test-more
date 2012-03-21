#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use Test::Builder;
use TB2::Formatter::Null;

note "set the formatter"; {
    my $tb = Test::Builder->create;
    my $null = TB2::Formatter::Null->new;

    $tb->set_formatter($null);
    is $tb->formatter, $null;

    my $state = $tb->test_state;
    is_deeply $state->formatters, [$null];
}


note "set_formatter() with no args"; {
    my $tb = Test::Builder->create;
    ok !eval { $tb->set_formatter };
    is $@, sprintf "No formatter given to set_formatter() at %s line %d.\n", __FILE__, __LINE__-1;
}


note "set_formatter(), wrong arg"; {
    my $tb = Test::Builder->create;

    ok !eval { $tb->set_formatter(42) };
    is $@, sprintf "Argument to set_formatter() is not a TB2::Formatter at %s line %d.\n",
      __FILE__, __LINE__-2;

    require TB2::History;
    ok !eval { $tb->set_formatter( TB2::History->new ) };
    is $@, sprintf "Argument to set_formatter() is not a TB2::Formatter at %s line %d.\n",
      __FILE__, __LINE__-2;
}

done_testing;
