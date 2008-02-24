#!/usr/bin/perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}

use Test::More tests => 2;
use warnings;

{
    my $uni = "\x{11e}";
    
    local $SIG{__WARN__} = sub {
        push @warnings, @_;
    };
    
    is $uni, $uni, "Testing $uni";
    is_deeply \@warnings, [];
}