#!/usr/bin/perl -w

use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::Builder;
use TB2::History;

my $Test = Test::Builder->new;
my $history = TB2::History->new( store_events => 1 );
$Test->test_state->ec->history($history);

$Test->plan( tests => 15 );
$Test->level(0);

my @Expected_Details;

$Test->is_num( scalar $Test->summary(), 0,   'no tests yet, no summary' );
push @Expected_Details, { 'ok'      => 1,
                          actual_ok => 1,
                          name      => 'no tests yet, no summary',
                          type      => '',
                          reason    => ''
                        };

# Inline TODO tests will confuse pre 1.20 Test::Harness, so we
# should just avoid the problem and not print it out.
my $start_test = $Test->current_test + 1;

my $output = '';
$Test->output(\$output);
$Test->todo_output(\$output);

SKIP: {
    $Test->skip( 'just testing skip' );
}
push @Expected_Details, { 'ok'      => 1,
                          actual_ok => 1,
                          name      => '',
                          type      => 'skip',
                          reason    => 'just testing skip',
                        };

TODO: {
    local $TODO = 'i need a todo';
    $Test->ok( 0, 'a test to todo!' );

    push @Expected_Details, { 'ok'       => 1,
                              actual_ok  => 0,
                              name       => 'a test to todo!',
                              type       => 'todo',
                              reason     => 'i need a todo',
                            };

    $Test->todo_skip( 'i need both' );
}
push @Expected_Details, { 'ok'      => 1,
                          actual_ok => 0,
                          name      => '',
                          type      => 'todo_skip',
                          reason    => 'i need both'
                        };

for ($start_test..$Test->current_test) {
    print "ok $_\n";
}
$Test->reset_outputs;

$Test->is_num( scalar $Test->summary(), 4,   'summary' );
push @Expected_Details, { 'ok'      => 1,
                          actual_ok => 1,
                          name      => 'summary',
                          type      => '',
                          reason    => '',
                        };

$Test->current_test(6);
print "ok 6 - current_test incremented\n";
push @Expected_Details, { 'ok'      => 1,
                          actual_ok => undef,
                          name      => '',
                          type      => 'unknown',
                          reason    => 'incrementing test number',
                        };

my @details = $Test->details();
$Test->is_num( scalar @details, 6,
    'details() should return a list of all test details');

$Test->level(1);
is_deeply( \@details, \@Expected_Details );


# This test has to come last because it thrashes the test details.
TODO_SKIP: {
    local $TODO = "current_test() going backwards is broken and may be removed";

    my $curr_test = $Test->current_test;
    $Test->current_test(4);
    my @details = $Test->details();

    $Test->current_test($curr_test);
    $Test->is_num( scalar @details, 4 );
}


note "details() error message when storage is off"; {
    my $tb = Test::Builder->create;
    $tb->level(0);

    ok !eval { $tb->details };
    like $@, qr/^Results are not stored by default /;
    like $@, qr/at $0 line @{[ __LINE__ - 2 ]}\.$/;

    ok !eval { $tb->summary };
    like $@, qr/^Results are not stored by default /;
    like $@, qr/at \Q$0\E line @{[ __LINE__ - 2 ]}\.$/;
}
