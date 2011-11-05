#!/usr/bin/perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}

my $handler_called = 0;
BEGIN {
    $SIG{__DIE__} = sub { $handler_called++ };
}

BEGIN { require 't/test.pl'; }
plan(2);

ok !eval { die };
is $handler_called, 1, 'existing DIE handler not overridden';
