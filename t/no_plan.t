#!/usr/bin/perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}

use Test::Builder;
my $tb = Test::Builder->create;
$tb->level(0);
$tb->plan( tests => 12 );

package main;

require Test::Simple;

require Test::Simple::Catch;
my($out, $err) = Test::Simple::Catch::caught();

eval {
    Test::Simple->import;
};

$tb->is_eq($$out, '');
$tb->is_eq($$err, '');
$tb->is_eq($@, '');

eval {
    Test::Simple->import(tests => undef);
};

$tb->is_eq($$out, '');
$tb->is_eq($$err, '');
$tb->like($@, '/Got an undefined number of tests/');

eval {
    Test::Simple->import(tests => 0);
};

$tb->is_eq($$out, '');
$tb->is_eq($$err, '');
$tb->like($@, '/You said to run 0 tests!/');

eval {
    Test::Simple::ok(1);
};
$tb->like( $@, '/You tried to run a test without a plan!/');


END {
    $tb->is_eq($$out, '');
    $tb->is_eq($$err, "");

    # Prevent Test::Simple from exiting with non zero.
    exit 0;
}
