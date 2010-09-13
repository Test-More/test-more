#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More 'no_plan';

use Test::Builder2::Result;

require_ok 'Test::Builder2::HistoryStack';
require_ok 'Test::Builder2::HistoryStack::Role::NoHistory';
      
# helpers
sub new_history { Test::Builder2::HistoryStack->create }
sub Pass { Test::Builder2::Result->new_result( pass => 1 ) }
sub Fail { Test::Builder2::Result->new_result( pass => 0 ) }


{ 
    ok my $history = new_history, q{new history} ;
    ok $history->add_result( Pass() ), q{add pass};
    is $history->test_count, 1, q{has test};
    is $history->result_count, 1, q{has test};

    Test::Builder2::HistoryStack::Role::NoHistory->meta->apply($history);

    ok $history->add_result( Pass() ), q{add pass};
    is $history->test_count, 2, q{test_count is correct};
    is $history->result_count, 1, q{results_count is also correct};
    

}





