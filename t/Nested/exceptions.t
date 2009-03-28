#!/usr/bin/perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ( '../lib', 'lib' );
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;
use warnings;
use Test::Builder::NoOutput;
use Test::More tests => 5;

{
    my $tb = Test::Builder::NoOutput->create;
    $tb->child('one');
    eval { $tb->child('two') };
    my $error = $@;
    like $error, qr/\QYou already have a child named (one) running/,
      'Trying to create a child with another one active should fail';
}
{
    my $tb    = Test::Builder::NoOutput->create;
    my $child = $tb->child('one');
    ok my $child2 = $child->child('two'), 'Trying to create nested children should succeed';
    eval { $child->finalize };
    my $error = $@;
    like $error, qr/\QCan't call &finalize with child (two) active/,
      '... but trying to finalize() a child with open children should fail';
}
{
    my $tb    = Test::Builder::NoOutput->create;
    my $child = $tb->child('one');
    undef $child;
    like $tb->read, qr/\QChild (one) exited without calling &finalize/,
      'Failing to call finalize should issue an appropriate diagnostic';
    ok !$tb->suite_passed, '... and should cause the test suite to fail';
}
