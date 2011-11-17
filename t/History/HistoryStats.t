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
    is_deeply $history->results, [], q{blank results set};

    $ec->post_event( Pass() );
    $ec->post_event( Fail() );
    $ec->post_event($_) for Pass(), Fail();
    ok $history->has_results, q{we have results};
    
    is $history->result_count, 4, q{count looks good};
    is $history->test_count,   4, q{test_count};
    is $history->pass_count,   2, q{pass_count};
    is $history->fail_count,   2, q{fail_count};
    is $history->todo_count,   0, q{todo_count};
    is $history->skip_count,   0, q{skip_count};

}


note "merge history stacks"; {
   my $H1 = new_history;
   my $ec1 = MyEventCoordinator->new(
       history => $H1
   );

   $ec1->post_event($_) for Pass(), Pass(), Pass();
   is $H1->result_count, 3, q{H1 count};

   my $H2 = new_history;
   my $ec2 = MyEventCoordinator->new(
       history => $H2
   );

   $ec2->post_event($_) for Fail(), Fail(), Fail();
   is $H2->result_count, 3, q{H2 count};

   ok $H1->consume($H2);
   is $H1->result_count, 6, q{H1 consumed H2};
   is $H1->fail_count, 3 , q{H1 picked up the tests from H2 correctly};

   my @histories = map {
       my $h = new_history;
       my $ec = MyEventCoordinator->new( history => $h );
       $ec->post_event($_) for Pass(), Fail();
       $h;
   } 1..10;
   ok $H1->consume( @histories ), q{consume can also take lists of objects};

   is $H1->result_count, 26, q{H1 consumed all the items in that list};
   
}


note "multiple results with same test number"; {
   my $h = new_history;
   my $ec = MyEventCoordinator->new( history => $h );
   $ec->post_event($_) for Pass(test_number=>1), Pass(test_number=>1);
   is $h->result_count,2;
}


done_testing;


