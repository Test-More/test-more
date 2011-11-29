package TB2::EventHandler;

use TB2::Mouse ();
use TB2::Mouse::Role;

our $VERSION = '1.005000_002';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

no TB2::Mouse::Role;


=head1 NAME

TB2::EventHandler - A role which handles events and results

=head1 SYNOPSIS

  package My::EventHandler;

  use TB2::Mouse;
  with "TB2::EventHandler";

  # handle_result() handles result events
  sub handle_result {
      my $self = shift;
      my($result, $ec) = @_;

      ...
  }

  # handle_comment() handles comment events... and so on
  sub handle_comment {
      my $self = shift;
      my($comment, $ec) = @_;

      ...
  }


  # handle_event() handles anything not handled by some other method
  sub handle_event  {
      my $self = shift;
      my($event, $ec) = @_;

      ....
  }

  no TB2::Mouse;


=head1 DESCRIPTION

An EventHandler is made known to an EventCoordinator which gives it
Events and Results to do whatever it wants with.  EventHandlers can be
used to record events for future use (such as
L<TB2::History>), to take an action like producing output
(such as L<TB2::Formatter>) or even modifying the event
itself.

=head1 METHODS

=head3 accept_event

    $handler->accept_event($event, $event_coordinator);

Pass an $event and the $event_coordinator managing it to the $handler.
The $handler will then pass them along to the appropriate handler
method based on the C<< $event->event_type >>.  If the appropriate
handler method does not exist, it will pass it to C<<handle_event>>.

This is the main interface to pass events to an EventHandler.  You
should I<not> pass events directly to handler methods as they may not
exist.

=cut

our %type2method;
sub accept_event {
    my($self, $event, $ec) = @_;

    my $type = $event->event_type;
    my $method = $type2method{$type} ||= $self->_event_type2handle_method($type);

    $self->can($method)
          ? $self->$method($event, $ec) 
          : $self->handle_event($event, $ec);

    return;
}


sub _event_type2handle_method {
    my $self = shift;
    my $type = shift;

    my $method = "handle_".$type;
    $method =~ s{\s}{_}g;

    return $method;
}


=head3 subtest_handler

    my $subtest_handler = $handler->subtest_handler($subtest_start_event);

When a subtest starts, the TestState will call C<subtest_handler> on
each EventHandler to get a handler for the subtest.  It will be passed
in the $subtest_start_event (see L<TB2::Event::SubtestStart>).

The provided method simply returns a new instance of the $handler's
class which should be sufficient for most handlers.

You may override this to, for example, configure the new instance.  Or
to return the same instance if you want a single instance to handle
all subtests.

=cut

sub subtest_handler {
    my $self = shift;
    my $class = ref $self;

    return $class->new;
}


=head2 Event handlers

EventHandlers process events via event handler methods.  They are all
of the form C<< "handle_".$event->event_type >>.  So a "comment" event
is handled by C<< handle_comment >>.

Event handlers are all called like this:

    $handler->handle_thing($event, $event_coordinator);

$event is the event being handled.

$event_coordinator is the coordinator which is managing the $event.
This allows a handler to issue their own Events or access history via
C<< $ec->history >>.

A handler is allowed to alter the $event.  Those changes will be
visible to other EventHandlers down the line.

Event handler methods should B<not> be called directly.  Instead use
L<accept_event>.


=head3 handle_event

    $event_handler->handle_event($event, $event_coordinator);

This handles any event not handled by a more specific event handler
(such as handle_result).

By default it does nothing.

=cut

sub handle_event {}


=head1 EXAMPLE

Here is an example of an EventHandler which formats the results as a
stream of pluses and minuses.

    package My::Formatter::PlusMinus;

    use TB2::Mouse;

    # This provides write(), otherwise it's a normal EventHandler
    extends 'TB2::Formatter';

    # Output a newline when we're done testing.
    sub handle_test_end {
        my $self  = shift;
        my $event = shift;

        $self->write(output => "\n");
        return;
    }

    # Print a plus for passes, minus for failures.
    sub handle_result {
        my $self   = shift;
        my $result = shift;

        my $out = $result->is_fail ? "-" : "+";
        $self->write(output => $out);

        return;
    }

    1;

=cut

1;
