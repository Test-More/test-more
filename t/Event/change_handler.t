#!/usr/bin/perl -w

# Make sure an early handler can change later handlers, but they still
# see the event being processed.

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use TB2::EventCoordinator;
use TB2::Events;

note "Set up an early handler"; {
    package My::HistoryChanger;

    use TB2::Mouse;
    with "TB2::EventHandler";

    has history =>
      is        => 'rw',
      isa       => 'TB2::History',
      default   => sub {
          require TB2::History;
          return TB2::History->new;
      };

    sub handle_event {
        my($self, $event, $ec) = @_;

        $ec->history( $self->history );

        return;
    }
}

note "Change later handlers with an earlier one"; {
    my $history_changer = My::HistoryChanger->new;
    my $ec = TB2::EventCoordinator->new(
        early_handlers  => [$history_changer],
        formatters      => [],
    );
    my $original_history = $ec->history;

    my $start = TB2::Event::TestStart->new;
    $ec->post_event( $start );

    isnt $ec->history->object_id, $original_history->object_id;
    is $ec->history->object_id, $history_changer->history->object_id;

    is $ec->history->events->[0]->object_id, $start->object_id;
}


done_testing;
