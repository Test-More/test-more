#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require "t/test.pl" }

my $CLASS = "TB2::Event::Comment";
use_ok $CLASS or die;

note "Bad args"; {
    ok !eval { $CLASS->new; };
    like $@, qr{^\QAttribute (comment) is required};
}


note "defaults"; {
    my $message = "The dolphins are in the jacuzzi.";
    my $event = $CLASS->new( comment => $message );

    is $event->event_type, "comment";
    is $event->comment, $message;
    is_deeply $event->as_hash, {
        event_type      => 'comment',
        event_id        => $event->event_id,
        comment         => $message,
    };
}

done_testing;
