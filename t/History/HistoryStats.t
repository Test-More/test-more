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

    $ec->post_event( TB2::Event::TestStart->new );

    is $history->last_event->object_id,  $history->test_start->object_id;

    ok!$history->has_results, q{we no not yet have results};

    $ec->post_event( Pass() );
    $ec->post_event( Fail() );
    $ec->post_event($_) for Pass(), Fail();

    my $todo_fail = TB2::Result->new_result(
        pass            => 0,
        directives      => ['todo'],
    );
    $ec->post_event( $todo_fail );

    is $history->last_result->object_id, $todo_fail->object_id;
    is $history->last_event->object_id,  $todo_fail->object_id;

    $ec->post_event( TB2::Result->new_result(
        pass            => 1,
        directives      => ['todo'],
    ));
    $ec->post_event( TB2::Result->new_result(
        pass            => 1,
        directives      => ['skip'],
    ));
    ok $history->has_results, q{we have results};

    is $history->event_count,           8, q{event_count};    
    is $history->result_count,          7, q{result_count};
    is $history->pass_count,            5, q{pass_count};
    is $history->fail_count,            2, q{fail_count};
    is $history->todo_count,            2, q{todo_count};
    is $history->skip_count,            1, q{skip_count};
    is $history->literal_pass_count,    4, q{literal_pass_count};
    is $history->literal_fail_count,    3, q{literal_pass_count};
}


note "multiple results with same test number"; {
   my $h = new_history;
   my $ec = MyEventCoordinator->new( history => $h );
   $ec->post_event($_) for Pass(test_number=>1), Pass(test_number=>1);
   is $h->result_count,2;
}


done_testing;


