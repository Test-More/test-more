package Test::Builder2::Event;

use Test::Builder2::Mouse ();
use Test::Builder2::Mouse::Role;
use Test::Builder2::Types;

requires qw( build_event_type );


=head1 NAME

Test::Builder2::Event - A test event role

=head1 SYNOPSIS

    package My::Event;

    use Test::Builder2::Mouse;
    with 'Test::Builder2::Event';

    sub as_hash    { ... }
    sub build_event_type { "my_thingy" }


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

=head2 Attributes

=head3 line

The line on which this event occurred.

The event issuer should fill this in.  It should be from the user's
perspective, not literally where the event was created inside the builder.

=cut

has line =>
  is    => 'rw',
  isa   => 'Test::Builder2::Positive_Int'
;

=head3 file

The file on which this event occurred.

The event issuer should fill this in.  It should be from the user's
perspective, not literally where the event was created inside the builder.

=cut

has file =>
  is    => 'rw',
  isa   => 'Str',
;

=head3 event_type

    my $type = $event->event_type;

Returns the type of event this is.

For example, "result".

=cut

has event_type =>
  is    => 'ro',
  isa   => 'Test::Builder2::LC_AlphaNumUS_Str',
  lazy => 1,
  builder => 'build_event_type',
;

=head2 Required Methods

You must implement these methods.

=head3 build_event_type

    my $type = $event->build_event_type;

Returns the type of event this is.

For example, "result".

The returned string must be lowercase and only contain alphanumeric characters
and underscores.

Used to build C<event_type>

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


=head3 as_hash

    my $data = $event->as_hash;

Returns all the attributes and data associated with this C<$event> as
a hash of attributes and values.

The intent is to provide a way to dump all the information in an Event
without having to call methods which may or may not exist.

=cut

sub as_hash {
    my $self = shift;
    return {
        map {
            my $val = $self->$_();
            defined $val ? ( $_ => $val ) : ()
        } @{$self->keys_for_as_hash}
    };
}


=head3 keys_for_hash

    my $keys = $event->keys_for_hash;

Returns an array ref of keys for C<as_hash> to use as keys and methods
to call on the object for the key's value.

By default it uses the object's non-private attributes, plus C<event_type>.
That should be sufficient for most events.

=cut

my %Attributes;
sub keys_for_as_hash {
    my $self = shift;
    my $class = ref $self;
    return $Attributes{$class} ||= [
        "event_type",
        grep !/^_/, map { $_->name } $class->meta->get_all_attributes
    ];
}


=head1 SEE ALSO

L<Test::Builder2::Result>

=cut

no Test::Builder2::Mouse::Role;

1;
