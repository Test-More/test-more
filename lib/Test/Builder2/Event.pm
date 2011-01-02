package Test::Builder2::Event;

use Test::Builder2::Mouse::Role;

requires qw(event_type as_hash);


=head1 NAME

Test::Builder2::Event - A test event role

=head1 SYNOPSIS

    package My::Event;

    use Test::Builder2::Mouse;
    with 'Test::Builder2::Event';

    sub as_hash    { ... }
    sub event_type { return "thingy" }


=head1 DESCRIPTION

Test::Builder2 is a federated system where multiple builders can
define their own way to do asserts.  They communicate and coordinate
with each other by way of events.  These events can include:

    start of a test stream
    end of a test stream
    the result of an assert

The basic Event doesn't do a whole lot.  It contains data and that's
about it.  Subclasses are expected to extend the interface quite a
bit, but they will all be able to dump out their relevant data.

=head1 METHODS

=head2 Required Methods

You must implement these methods.

=head3 event_type

    my $type = $event->event_type;

Returns the type of event this is.

For example, "result".

=head3 as_hash

    my $data = $event->as_hash;

Returns all the data associated with this C<$event> as a hash of
attributes and values.

The intent is to provide a way to dump all the information in an Event
without having to call methods which may or may not exist.


=head2 Provided Methods

=head3 event_id

    my $id = $event->event_id;

Returns an identifier for this event unique to this process.

Useful if an EventWatcher posts its own events and doesn't want to
process them twice.

=cut

my $Counter = int rand(1_000_000);
has event_id =>
  is            => 'ro',
  isa           => 'Str',
  lazy          => 1,
  default       => sub {
      my $self = shift;

      # Include the class in case somebody else decides to use
      # just an integer.
      return ref($self) . '-' . $Counter++;
  }
;


=head1 SEE ALSO

L<Test::Builder2::Result>

=cut

no Test::Builder2::Mouse::Role;

1;
