#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require "t/test.pl" }

my $CLASS = "TB2::Event::Log";
use_ok $CLASS or die;

note "Bad args"; {
    ok !eval { $CLASS->new; };
    like $@, qr{^\QAttribute (message) is required};

    ok !eval { $CLASS->new( message => "foo", level => 42 ) };
    like $@, qr{^\QAttribute (level) does not pass the type constraint};

    ok !eval { $CLASS->new( message => "foo", level => "highest" ) };
    like $@, qr{^\QAttribute (level) does not pass the type constraint},
      "highest is not a level";
}


note "defaults"; {
    my $message = "The dolphins are in the jacuzzi.";
    my $event = $CLASS->new( message => $message );

    is $event->event_type,      "log";
    is $event->level,           'debug';
    is $event->message,         $message;
    is_deeply $event->as_hash, {
        event_id        => $event->event_id,
        event_type      => 'log',
        message         => $message,
        level           => 'debug'
    };
}


note "levels"; {
    is_deeply [$CLASS->levels], [qw( debug info notice warning error alert )];
}


note "between_levels"; {
    my $log = $CLASS->new(
        message => "whatever",
        level   => "error"
    );

    ok $log->between_levels("error", "alert");
    ok !$log->between_levels("alert", "highest");
    ok !$log->between_levels("error", "error");
    ok !$log->between_levels("lowest", "error");
    ok $log->between_levels("lowest", "alert");
}

done_testing;
