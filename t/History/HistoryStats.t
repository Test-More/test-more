#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use Test::Builder2::Result;

require_ok 'Test::Builder2::History';
can_ok( 'Test::Builder2::History', 
        qw{ singleton
            create
            
            results
            has_results
            accept_result
            result_count

          },
);
      
# helpers
sub new_history { Test::Builder2::History->create }
sub Pass { Test::Builder2::Result->new_result( pass => 1, @_ ) }
sub Fail { Test::Builder2::Result->new_result( pass => 0, @_ ) }


{ 
    ok my $history = new_history, q{new history} ;
    ok!$history->has_results, q{we no not yet have results};
    is_deeply $history->results, [], q{blank results set};
    $history->accept_result( Pass() );
    $history->accept_result( Fail() );
    $history->accept_results( Pass(), Fail() );
    ok $history->has_results, q{we have results};
    
    is $history->result_count, 4, q{count looks good};
    is $history->test_count, 4, q{test_count};

    is $history->pass_count, 2, q{pass_count};
    is $history->fail_count, 2, q{fail_count};
    is $history->todo_count, 0, q{todo_count};
    is $history->skip_count, 0, q{skip_count};

}

# merge history stacks
{
   my $H1 = new_history;
   $H1->accept_results(Pass(), Pass(), Pass());
   is $H1->result_count, 3, q{H1 count};
   my $H2 = new_history;
   $H2->accept_results(Fail(), Fail(), Fail());
   is $H2->result_count, 3, q{H2 count};

   ok $H1->consume($H2);
   is $H1->result_count, 6, q{H1 consumed H2};
   is $H1->fail_count, 3 , q{H1 picked up the tests from H2 correctly};

   my @histories = map{
       my $h = new_history;
       $h->accept_results(Pass(), Fail());
       $h;
   } 1..10;
   ok $H1->consume( @histories ), q{consume can also take lists of objects};

   is $H1->result_count, 26, q{H1 consumed all the items in that list};
   
}

# multiple results with same test number
{
   my $h = new_history;
   $h->accept_results(Pass(test_number=>1), Pass(test_number=>1));
   is $h->result_count,2;
}

{
   my $h = new_history;
   $h->accept_event('BEGIN 1');
   $h->accept_result(Pass());
   TODO: {
      our $TODO;
      local $TODO = 'accept_event should not accept Results';
      ok !eval { $h->accept_event(Fail()); 1; };
   };
   is $h->results_count, 1;
   is $h->events_count, 3;
}

done_testing;


