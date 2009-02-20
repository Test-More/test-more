#!perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}


# Turn on threads here, if available, since this test tends to find
# lots of threading bugs.
use Config;
BEGIN {
    if( $] >= 5.008001 && $Config{useithreads} ) {
        require threads;
        'threads'->import;
    }
}


use strict;

use Test::More tests => 7;

my $test = Test::Builder->create;

# Test diag() goes to todo_output() in a todo test.
{
    $test->todo_start();

    my $output = '';
    $test->todo_output(\$output);

    $test->diag("a single line");
    is( $output, <<'DIAG',   'diag() with todo_output set' );
# a single line
DIAG

    $output = '';
    my $ret = $test->diag("multiple\n", "lines");
    is( $output, <<'DIAG',   '  multi line' );
# multiple
# lines
DIAG
    ok( !$ret, 'diag returns false' );

    $test->todo_end();
}

$test->reset_outputs();


# Test diagnostic formatting
{
    my $output;
    $test->failure_output(\$output);

    $test->diag("# foo");
    is( $output, "# # foo\n", "diag() adds # even if there's one already" );

    $output = '';
    $test->diag("foo\n\nbar");
    is( $output, <<'DIAG', "  blank lines get escaped" );
# foo
# 
# bar
DIAG

    $output = '';
    $test->diag("foo\n\nbar\n\n");
    is( $output, <<'DIAG', "  even at the end" );
# foo
# 
# bar
# 
DIAG
}


# [rt.cpan.org 8392] diag(@list) emulates print
{
    my $output = '';
    $test->failure_output(\$output);
    $test->diag(qw(one two));

    is( $output, <<'DIAG' );
# onetwo
DIAG
}
