#!/usr/bin/perl -w
use Test::Stream::Shim;

use strict;
use Test::Builder;

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ('../lib', 'Legacy/lib');
    }
    else {
        unshift @INC, 't/Legacy/lib';
    }
}
use Test::Builder::NoOutput;

my $tb = Test::Builder->new;

$tb->ok( !eval { $tb->subtest() } );
$tb->like( $@, qr/^\Qsubtest()'s second argument must be a code ref/ );

$tb->ok( !eval { $tb->subtest("foo") } );
$tb->like( $@, qr/^\Qsubtest()'s second argument must be a code ref/ );

use Carp qw/confess/;
$tb->subtest('Arg passing', sub {
    my $foo = shift;
    my $child = Test::Builder->new;
    $child->is_eq($foo, 'foo');
    $child->done_testing;
    $child->finalize;
}, 'foo');

$tb->done_testing();
