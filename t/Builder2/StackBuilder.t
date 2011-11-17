#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use_ok( 'TB2::StackBuilder' );

BEGIN {
   package My::One;
   use TB2::Mouse;
   use TB2::StackBuilder;
}

{
   can_ok 'My::One', qw{buildstack};
}

BEGIN {
   package My::Two;
   use TB2::Mouse;
   use TB2::StackBuilder;
   buildstack 'items';
}

{
   can_ok 'My::Two', qw{ buildstack
                         items
                         items_push
                         items_pop
                         items_count
                       };
   my $two = My::Two->new;
   is_deeply $two->items, [];
   ok $two->items_push(1..3);
   is $two->items_count, 3;
   is_deeply $two->items, [1..3];
   ok $two->items_push('end');
   is $two->items_pop, 'end';
}

BEGIN {
   package My::Three;
   use TB2::Mouse;
   use TB2::StackBuilder;
   sub nums_count {'buildin'};
   buildstack nums => 'Int';
}

{
   my $three = My::Three->new;
   is $three->nums_count, 'buildin', q{buildstack does not squash existing methods};

   TODO: {
       our $TODO;
       local $TODO = "This would be nice, but the implementation was very inefficient and messed with threads";

       eval { $three->nums_push('this is a string') };
       like $@, qr{^Attribute \(nums\) does not pass the type constraint because}, q{type enforced};
   }
}

done_testing;
