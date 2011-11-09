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

=head3 receive_event

    $watcher->receive_event($event, $event_coordinator);

Pass an $event and the $event_coordinator managing it to the $watcher.
The watcher will then pass them along to the appropriate handler
method based on the C<< $event->event_type >>.  If the appropriate
handler method does not exist, it will pass it to C<<accept_event>>.

This is the main interface to pass events to an EventWatcher.  You
should I<not> pass events directly to handler methods as they may not
exist.

=cut

our %type2method;
sub receive_event {
    my($self, $event, $ec) = @_;

    my $type = $event->event_type;
    my $method = $type2method{$type} ||= $self->_event_type2accept_method($type);

    $self->can($method)
          ? $self->$method($event, $ec) 
          : $self->accept_event($event, $ec);

    return;
}


sub _event_type2accept_method {
    my $self = shift;
    my $type = shift;

    my $method = "accept_".$type;
    $method =~ s{\s}{_}g;

    return $method;
}


=head3 subtest_handler

    my $subtest_handler = $watcher->subtest_handler($subtest_start_event);

When a subtest starts, the TestState will call C<subtest_handler> on
each EventWatcher to get a watcher for the subtest.  It will be passed
in the $subtest_start_event (see L<Test::Builder2::Event::SubtestStart>).

The provided method simply returns a new instance of the $watcher's
class which should be sufficient for most watchers.

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

Event handler methods should B<not> be called directly.  Instead use
L<receive_event>.


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
    sub accept_test_end {
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
