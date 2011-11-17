#!/usr/bin/perl -w

use strict;
use warnings;

use lib 't/lib';

BEGIN { require 't/test.pl' }
use MyEventCoordinator;
use TB2::Result;

require_ok 'TB2::NoHistory';
can_ok( 'TB2::NoHistory', 
        qw{ new            
            results
            has_results
            handle_result
            result_count
          },
);
      
# helpers
sub new_history { TB2::NoHistory->new }
sub Pass { TB2::Result->new_result( pass => 1 ) }
sub Fail { TB2::Result->new_result( pass => 0 ) }


{ 
    ok my $history = new_history, q{new history} ;
    my $ec = MyEventCoordinator->new( history => $history );

    ok!$history->has_results, q{we no not yet have results};
    is_deeply $history->results, [], q{blank results set};

    $ec->post_event( Pass() );
    $ec->post_event( Fail() );
    $ec->post_event($_) for Pass(), Fail();

    ok!$history->has_results, q{we have no results};
    
    is $history->result_count, 0, q{result count is 0 as we don't store them};
    is $history->test_count,   4, q{test_count how ever does work};

    is $history->pass_count, 2, q{pass_count};
    is $history->fail_count, 2, q{fail_count};
    is $history->todo_count, 0, q{todo_count};
    is $history->skip_count, 0, q{skip_count};

    is_deeply $history->results, [], q{no results stored};

}

done_testing;
