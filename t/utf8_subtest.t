#!/usr/bin/perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}

use strict;
use warnings;

use Test::More;

# The test which checks that the file handle changed by
# binmode is correctly taken over to a subtest 
{
    my $uni = "\x{11e}";

    my @warnings;
    local $SIG{__WARN__} = sub {
        push @warnings, @_;
    };

    binmode Test::More->builder->$_, ":utf8"
        for qw/output failure_output todo_output/;

    is( $uni, $uni, "Testing $uni" );
    subtest( "Testing subtest - $uni", sub { ok(1, "in subtest $uni" ) } );
    is( $uni, $uni, "Testing $uni - again" );
    is_deeply( \@warnings, [] );
}

done_testing;
