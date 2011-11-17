#!/usr/bin/perl

# Test that events are posted in the right order

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use TB2::Events;

{
    package My::Event::Incrementer;

    use TB2::Mouse;
    with "TB2::EventHandler";

    our @Stack;

    has name =>
      is                => 'ro',
      isa               => 'Str',
      required          => 1
    ;

    sub handle_event {
        my($self, $event, $ec) = @_;

        push @Stack, $self->name;
    }

    sub read_stack {
        my @copy = @Stack;
        @Stack = ();

        return @copy;
    }
}


note "post order"; {
    require TB2::EventCoordinator;
    my $ec = TB2::EventCoordinator->new(
        early_handlers  => [ My::Event::Incrementer->new( name => "early" ) ],
        late_handlers   => [ My::Event::Incrementer->new( name => "late" ) ],
        formatters      => [ My::Event::Incrementer->new( name => "formatter" ) ],
        history         => My::Event::Incrementer->new( name => "history" )
    );

    $ec->post_event(
        TB2::Event::TestStart->new
    );

    is_deeply [My::Event::Incrementer->read_stack], [qw(early history formatter late)];
}

done_testing;
