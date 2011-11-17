package TB2::Event::TestMetadata;

use TB2::Mouse;
with 'TB2::Event';

our $VERSION = '1.005000_001';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::Event::TestMetadata - Metadata for the current test

=head1 DESCRIPTION

This is an Event for metadata about the current test.  It can include
things such as the time and date of the test, its name, etc...

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

The event type is C<test_metadata>.

=cut

sub build_event_type { "test_metadata" }

=head1 SEE ALSO

L<TB2::Event>

=cut

1;
