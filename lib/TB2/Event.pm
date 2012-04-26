package TB2::Event;

use TB2::Mouse ();
use TB2::Mouse::Role;
use TB2::Types;
with 'TB2::HasObjectID';

requires qw( build_event_type );

our $VERSION = '1.005000_005';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::Event - A test event role

=head1 SYNOPSIS

    package My::Event;

    use TB2::Mouse;
    with 'TB2::Event';

    sub as_hash    { ... }
    sub build_event_type { "my_thingy" }


=head1 DESCRIPTION

Test::Builder2 is a federated system where multiple builders can
define their own way to do asserts.  They communicate and coordinate
with each other by way of events.  These events can include:

    start of a test
    end of a test
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
  isa   => 'TB2::Positive_Int'
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

Returns the type of event this is.  For example, "result" or "test_start".

Use this to identify events rather than C<< $event->isa($class) >>.

See L<build_event_type> for how to set the C<event_type> if you're
writing a new event.

=cut

has event_type =>
  is    => 'ro',
  isa   => 'TB2::LC_AlphaNumUS_Str',
  builder => 'build_event_type',
;

=head2 Required Methods

You must implement these methods.

=head3 build_event_type

    my $type = $event->build_event_type;

Returns the type of event this is.

For example, "result".

$type must be lowercase and only contain alphanumeric characters and
underscores.

Used to build C<event_type>

=head2 Provided Methods

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

By default it uses the object's non-private attributes.  That should
be sufficient for most events.

=cut

my %Attributes;
sub keys_for_as_hash {
    my $self = shift;
    my $class = ref $self;
    return $Attributes{$class} ||= [
        grep !/^_/, map { $_->name } $class->meta->get_all_attributes
    ];
}

=head3 object_id

    my $id = $thing->object_id;

Returns an identifier for this object unique to the running process.
The identifier is fairly simple and easily predictable.

See L<TB2::HasObjectID>

=head1 SEE ALSO

L<TB2::Result>

=cut

no TB2::Mouse::Role;

1;
