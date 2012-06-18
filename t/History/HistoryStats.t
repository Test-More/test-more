#!/usr/bin/perl -w

use strict;
use warnings;

use lib 't/lib';

BEGIN { require 't/test.pl' }
use MyEventCoordinator;
use TB2::Events;

require_ok 'TB2::History';
can_ok( 'TB2::History', 
        qw{ new            
            results
            has_results
            handle_result
            result_count
          },
);
      
# helpers
sub new_history { TB2::History->new }
sub Pass { TB2::Result->new_result( pass => 1, @_ ) }
sub Fail { TB2::Result->new_result( pass => 0, @_ ) }


note "basic history stats"; { 
    ok my $history = new_history, q{new history} ;
    my $ec = MyEventCoordinator->new(
        history => $history
    );

    ok!$history->has_results, q{we no not yet have results};

    $ec->post_event( Pass() );
    $ec->post_event( Fail() );
    $ec->post_event($_) for Pass(), Fail();
    ok $history->has_results, q{we have results};
    
    is $history->result_count, 4, q{count looks good};
    is $history->pass_count,   2, q{pass_count};
    is $history->fail_count,   2, q{fail_count};
    is $history->todo_count,   0, q{todo_count};
    is $history->skip_count,   0, q{skip_count};

}


note "multiple results with same test number"; {
   my $h = new_history;
   my $ec = MyEventCoordinator->new( history => $h );
   $ec->post_event($_) for Pass(test_number=>1), Pass(test_number=>1);
   is $h->result_count,2;
}


done_testing;


