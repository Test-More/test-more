#!/usr/bin/perl -w

# Test Test::Builder->reset;

BEGIN {
    if( $ENV{PERL_CORE} ) {
        @INC = ('../lib', 'lib');
    }
    else {
        unshift @INC, '../lib', 'lib'
    }
}
chdir 't';


use Test::Builder;
use TB2::History;
my $Test = Test::Builder->new;
my $tb = Test::Builder->create;

# We'll need this later to know the outputs were reset
my %Original_Output;
$Original_Output{$_} = $tb->$_ for qw(output failure_output todo_output);

# Alter the state of Test::Builder as much as possible.
my $output = '';
$tb->output(\$output);
$tb->failure_output(\$output);
$tb->todo_output(\$output);

$tb->plan(tests => 14);
$tb->level(0);

$tb->ok(1, "Running a test to alter TB's state");

# This won't print since we just sent output off to oblivion.
$tb->ok(0, "And a failure for fun");

$Test::Builder::Level = 3;

$tb->exported_to('Foofer');

$tb->use_numbers(0);
$tb->no_header(1);
$tb->no_ending(1);

$tb->done_testing;  # make sure done_testing gets reset

# Now reset it.
$tb->reset;


# Test the state of the reset builder
$Test->ok( !defined $tb->exported_to, 'exported_to' );
$Test->ok( !$tb->expected_tests      , 'expected_tests' );
$Test->is_num( $tb->level,          1, 'level' );
$Test->ok( $tb->use_numbers,         , 'use_numbers' );
$Test->ok( !$tb->no_header,          , 'no_header' );
$Test->ok( !$tb->no_ending,          , 'no_ending' );
$Test->is_num( $tb->current_test,   0, 'current_test' );
$Test->is_num( $tb->history->event_count,  0 );
$Test->is_num( $tb->history->result_count, 0 );
$Test->is_eq( fileno $tb->output,
              fileno $Original_Output{output},         'output' );
$Test->is_eq( fileno $tb->failure_output,
              fileno $Original_Output{failure_output}, 'failure_output' );
$Test->is_eq( fileno $tb->todo_output,
              fileno $Original_Output{todo_output},    'todo_output' );

# The reset Test::Builder will take over from here.
$Test->no_ending(1);
$tb->no_header(1);

$tb->current_test($Test->current_test);
$tb->level(0);
$tb->ok(1, 'final test to make sure output was reset');

$tb->done_testing;
