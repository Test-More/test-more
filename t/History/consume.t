#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN { require 't/test.pl' }

my $FILE = __FILE__;
my $QFILE = quotemeta($FILE);

my $CLASS = "TB2::History";
use_ok $CLASS;
use TB2::Events;

note "merge history stacks"; {
   my $h1 = $CLASS->new( store_events => 1 );

   my $pass = TB2::Result->new_result( pass => 1 );
   my $fail = TB2::Result->new_result( pass => 0 );

   $h1->accept_event($_) for $pass, $pass, $pass;
   is $h1->result_count, 3, q{H1 count};

   my $h2 = $CLASS->new( store_events => 1 );

   $h2->accept_event($_) for $fail, $fail, $fail;
   is $h2->result_count, 3, q{H2 count};

   $h1->consume($h2);
   is $h1->result_count, 6, q{H1 consumed H2};
   is $h1->fail_count, 3 , q{H1 picked up the tests from H2 correctly};

   my $h3 = $CLASS->new( store_events => 1 );
   $h3->accept_event($_) for $pass, $fail;

   $h1->consume( $h3 ) for 1..10;

   is $h1->result_count, 26, q{consume appends history};
}


note "Try to consume with storage off"; {
    my $h1 = $CLASS->new;
    my $h2 = $CLASS->new;

    ok !eval { $h2->consume( $h1 ); 1 };
    my $line = __LINE__ - 1;
    like $@, qr{^Cannot consume\(\) a History object which has store_events\(\) off at $QFILE line $line\.?\n};
}

done_testing;
