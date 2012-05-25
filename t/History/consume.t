#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN { require 't/test.pl' }

my $CLASS = "TB2::History";
use_ok $CLASS;
use TB2::Events;

note "merge history stacks"; {
   my $h1 = $CLASS->new;

   my $pass = TB2::Result->new_result( pass => 1 );
   my $fail = TB2::Result->new_result( pass => 0 );

   $h1->accept_event($_) for $pass, $pass, $pass;
   is $h1->result_count, 3, q{H1 count};

   my $h2 = $CLASS->new;

   $h2->accept_event($_) for $fail, $fail, $fail;
   is $h2->result_count, 3, q{H2 count};

   $h1->consume($h2);
   is $h1->result_count, 6, q{H1 consumed H2};
   is $h1->fail_count, 3 , q{H1 picked up the tests from H2 correctly};

   my $h3 = $CLASS->new;
   $h3->accept_event($_) for $pass, $fail;

   $h1->consume( $h3 ) for 1..10;

   is $h1->result_count, 26, q{consume appends history};
}
