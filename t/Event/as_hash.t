#!/usr/bin/env perl

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use TB2::Events;
use TB2::Event::Generic;
use TB2::History;

my %Special_Constructors = (
    'TB2::Event::SubtestEnd' => sub {
        my $class = shift;
        return $class->new(
            history => TB2::History->new,
            @_,
        );
    },
    'TB2::Result'       => sub {
        my $class = shift;
        return TB2::Result->new_result(@_)
    },
    'TB2::Event::Log'   => sub {
        my $class = shift;
        return $class->new(
            message => "This is a message",
            @_
        );
    },
    'TB2::Event::Comment'   => sub {
        my $class = shift;
        return $class->new(
            comment => "This is a comment",
            @_
        );
    }
);

note "as_hash / new round trip"; {
    for my $class (TB2::Events->event_classes) {
        my $constructor = $Special_Constructors{$class} || 'new';

        note "Trying $class";
        my $obj = $class->$constructor;

        my $duplicate = TB2::Event::Generic->new( %{$obj->as_hash} );
        is_deeply $obj->as_hash, $duplicate->as_hash, "$class round trip";
    }
}

done_testing;
