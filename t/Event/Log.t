#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require "t/test.pl" }

my $CLASS = "Test::Builder2::Event::Log";
use_ok $CLASS or die;

note "Bad args"; {
    ok !eval { $CLASS->new; };
    like $@, qr{^\QAttribute (message) is required};

    ok !eval { $CLASS->new( message => "foo", level => 42 ) };
    like $@, qr{^\QAttribute (level) does not pass the type constraint};
}


note "defaults"; {
    my $message = "The dolphins are in the jacuzzi.";
    my $event = $CLASS->new( message => $message );

    is $event->event_type, "log";
    is $event->level, 7;
    is $event->message, $message;
    is_deeply $event->as_hash, {
        event_type      => 'log',
        message         => $message,
        level           => 7
    };
    is $event->level_name, "debug";
}


note "levels"; {
    is_deeply [$CLASS->levels], [qw( emergency alert critical error warning notice info debug )];
}

done_testing;
