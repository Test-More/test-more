package Test::Builder2::EventWatcher;

use Test::Builder2::Mouse ();
use Test::Builder2::Mouse::Role;

no Test::Builder2::Mouse::Role;


=head1 NAME

Test::Builder2::EventWatcher - A role which watches events and results

=head1 SYNOPSIS

  package My::EventWatcher;

  use Test::Builder2::Mouse;
  with "Test::Builder2::EventWatcher";

  # accept_result() handles result events
  sub accept_result {
      my $self = shift;
      my($result, $ec) = @_;

      ...
  }

  # accept_comment() handles comment events... and so on
  sub accept_result {
      my $self = shift;
      my($comment, $ec) = @_;

      ...
  }


  # accept_event() handles anything not handled by some other method
  sub accept_event  {
      my $self = shift;
      my($event, $ec) = @_;

      ....
  }

  no Test::Builder2::Mouse;


=head1 DESCRIPTION

An EventWatcher is made known to an EventCoordinator which gives it
Events and Results to do whatever it wants with.  EventWatchers can be
used to record events for future use (such as
L<Test::Builder2::History>), to take an action like producing output
(such as L<Test::Builder2::Formatter>) or even modifying the event
itself.

=head1 METHODS

=head2 Event handlers

EventWatchers accept events via event handler methods.  They are all
of the form C<< "accept_".$event->event_type >>.  So a "comment" event
is handled by C<< accept_comment >>.

Event handlers are all called like this:

    $event_watcher->accept_thing($event, $event_coordinator);

$event is the event being accepted.

$event_coordinator is the coordinator which is managing the $event.
This allows a watcher to issue their own Events or access history via
C<< $ec->history >>.

A handler is allowed to alter the $event.  Those changes will be
visible to other EventWatchers down the line.


=head3 accept_event

    $event_watcher->accept_event($event, $event_coordinator);

This event handler accepts any event not handled by a more specific
event handler (such as accept_result).

By default it does nothing.

=cut

sub accept_event {}


=head1 EXAMPLE

Here is an example of an EventWatcher which formats the results as a
stream of pluses and minuses.

    package My::Formatter::PlusMinus;

    use Test::Builder2::Mouse;

    # This provides write(), otherwise it's a normal EventWatcher
    extends 'Test::Builder2::Formatter';

    # Output a newline when we're done testing.
    sub accept_stream_end {
        my $self  = shift;
        my $event = shift;

        $self->write(output => "\n");
        return;
    }

    # Print a plus for passes, minus for failures.
    sub accept_result {
        my $self   = shift;
        my $result = shift;

        my $out = $result->is_fail ? "-" : "+";
        $self->write(output => $out);

        return;
    }

    1;

=cut

1;
