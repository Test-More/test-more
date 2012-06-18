package TB2::History::EventStorage;

use TB2::Mouse;

=head1 NAME

TB2::History::EventStorage - Store all events

=head1 SYNOPSIS

    my $storage = TB2::History::EventStorage->new;

    $storage->event_push($event);

    my $events  = $storage->events;
    my $results = $storage->results;

=head1 DESCRIPTION

This object stores L<TB2::Event>s.

=head2 Constructors

=head3 new

    my $storage = TB2::History::EventStorage->new;

Create a new storage object.

=head2 Methods

=head3 events

    my $events = $storage->events;

Returns all L<TB2::Event>s pushed in so far.

Do I<NOT> alter this array directly.  Use L<events_push>.

=head3 results

    my $results = $storage->results;

Returns just the L<TB2::Result>s pushed in so far.

Do I<NOT> alter this array directly.  Use L<events_push>.

=cut

has events =>
  is            => 'ro',
  isa           => 'ArrayRef[TB2::Event]',
  default       => sub { [] }
;

has results =>
  is            => 'ro',
  isa           => 'ArrayRef[TB2::Result]',
  default       => sub { [] }
;


=head3 events_push

    $storage->events_push(@events);

Add any number of @events to C<< $storage->events >>.

=cut

sub events_push {
    my $self = shift;

    push @{$self->events}, @_;
    push @{$self->results}, grep $_->isa("TB2::Result::Base"), @_;

    return;
}


=head1 SEE ALSO

L<TB2::History::NoEventStorage> is like EventStorage but it silently
throws away all events.  Saves space.

=cut


1;
