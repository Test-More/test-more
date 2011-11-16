package Test::Builder2::Event::StreamMetadata;

use Test::Builder2::Mouse;
with 'Test::Builder2::Event';


=head1 NAME

Test::Builder2::Event::StreamMetadata - Metadata for the current stream

=head1 DESCRIPTION

This is an Event for metadata about the current stream of tests.

It B<must> come between a C<test_start> and an C<test_end> Event.

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

=head3 build_event_type

The event type is C<stream_metadata>.

=cut

sub build_event_type { "stream_metadata" }

=head1 SEE ALSO

L<Test::Builder2::Event>

=cut

1;
