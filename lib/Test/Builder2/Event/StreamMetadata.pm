package Test::Builder2::Event::StreamMetadata;

use Test::Builder2::Mouse;
with 'Test::Builder2::Event';


=head1 NAME

Test::Builder2::Event::StreamMetadata - Metadata for the current stream

=head1 DESCRIPTION

This is an Event for metadata about the current stream of tests.

It B<must> come between a C<stream start> and an C<stream end> Event.

=head1 METHODS

=head2 Attributes

=head3 metadata

    my $metadata = $event->metadata;
    $event->metadata(\%metadata);

A hash ref containing the metadata this event represents.

=cut

has metadata =>
  is            => 'rw',
  isa           => 'HashRef',
  lazy          => 1,
  default       => sub { {} }
;

=head3 event_type

The event type is C<stream metadata>.

=cut

sub event_type { "stream metadata" }

sub as_hash {
    my $self = shift;

    return {
        metadata        => $self->metadata,
        event_type      => "stream metadata",
    };
}


=head1 SEE ALSO

L<Test::Builder2::Event>

=cut

1;
