#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

{
    package Some::Thing;

    use TB2::Mouse;
    with "TB2::HasObjectID";
}


note "object_id"; {
    my $e1 = Some::Thing->new;
    my $e2 = Some::Thing->new;

    ok $e1->object_id;
    ok $e2->object_id;

    isnt $e1->object_id, $e2->object_id, "object_ids are unique";
}


done_testing;
