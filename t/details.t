#!/usr/bin/perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}

use Test::More;
use Test::Builder;
my $Test = Test::Builder->new;

$Test->plan( tests => 8 );
$Test->level(0);

my @Expected_Details;

$Test->is_num( scalar $Test->summary(), 0,   'no tests yet, no summary' );
push @Expected_Details, { ok        => 1,
                          actual_ok => 1,
                          name      => 'no tests yet, no summary',
                          type      => '',
                          reason    => ''
                        };

SKIP: {
    $Test->skip( 'just testing skip' );
}
push @Expected_Details, { ok        => 1,
                          actual_ok => 1,
                          name      => '',
                          type      => 'skip',
                          reason    => 'just testing skip',
                        };

TODO: {
    local $TODO = 'i need a todo';
    $Test->ok( 0, 'a test to todo!' );

    push @Expected_Details, { ok         => 1,
                              actual_ok  => 0,
                              name       => 'a test to todo!',
                              type       => 'todo',
                              reason     => 'i need a todo',
                            };

    $Test->todo_skip( 'i need both' );
}
push @Expected_Details, { ok        => 1,
                          actual_ok => 0,
                          name      => '',
                          type      => 'todo_skip',
                          reason    => 'i need both'
                        };

$Test->is_num( scalar $Test->summary(), 4,   'summary' );
push @Expected_Details, { ok        => 1,
                          actual_ok => 1,
                          name      => 'summary',
                          type      => '',
                          reason    => '',
                        };

$Test->current_test(6);
print "ok 6 - current_test incremented\n";
push @Expected_Details, { ok        => 1,
                          actual_ok => undef,
                          name      => undef,
                          type      => 'unknown',
                          reason    => 'incrementing test number',
                        };

my @details = $Test->details();
$Test->is_num( scalar @details, 6,
    'details() should return a list of all test details');

is_deeply( \@details, \@Expected_Details );
