package Test::Builder2::EventWatcher;

use Test::Builder2::Mouse ();
use Test::Builder2::Mouse::Role;

requires qw(accept_event);

no Test::Builder2::Mouse::Role;


=head1 NAME

Test::Builder2::EventWatcher - A role which watches events and results

=head1 SYNOPSIS

  package My::EventWatcher;

  use Test::Builder2::Mouse;
  with "Test::Builder2::EventWatcher";

  sub accept_event  { ... }

  no Test::Builder2::Mouse;


=head1 DESCRIPTION

An EventWatcher is made known to an EventCoordinator which gives it
Events and Results to do whatever it wants with.  EventWatchers can be
used to record events for future use (such as
L<Test::Builder2::History>), to take an action like producing output
(such as L<Test::Builder2::Formatter>) or even modifying the event
itself.

=head1 METHODS

=head2 Required Methods

When writing an EventWatcher you must supply these methods.

=head3 accept_event

    $event_watcher->accept_event($event, $event_coordinator);

An EventWatcher will be handed Event objects to do whatever it wants
to with via this method.

C<accept_event> is allowed to alter the $event.  Be aware those
changes B<will> be visible to other EventWatchers.

It must also be given the $event_coordinator which is managing the
$event.  This allows a watcher to issue their own Events or access
history via C<< $ec->history >>.

You must implement this method.

=cut

1;
