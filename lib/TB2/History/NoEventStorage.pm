package TB2::History::NoEventStorage;

use Carp;
use TB2::Mouse;
extends 'TB2::History::EventStorage';

our @CARP_NOT = qw(TB2::History);


=head1 NAME

TB2::History::NoEventStorage - Throw out all events

=head1 SYNOPSIS

    my $storage = TB2::History::NoEventStorage->new;

    # Immediately discarded.
    $storage->event_push($event);

    # Trying to look at the events causes an exception.
    my $events  = $storage->events;
    my $results = $storage->results;

=head1 DESCRIPTION

This object throws out all its input events and stores nothing.

This implements the L<TB2::History::EventStorage> interface.  It
exists so that L<TB2::History> can be configured to not store events
and thus not grow in memory as the tests run.

=head2 Methods

The interface is the same as L<TB2::History::EventStorage> with the
following exceptions.

=head3 events

=head3 results

If called, they will both throw an exception.

=cut

sub events {
    croak "Events are not stored";
}

sub results {
    croak "Results are not stored";
}


=head3 events_push

Calls to this method will be ignored.

=cut

sub events_push {}


=head1 SEE ALSO

L<TB2::History::EventStorage> is like NoEventStorage but it actually
stores events.

=cut


1;
