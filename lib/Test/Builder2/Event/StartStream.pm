package Test::Builder2::Event::StartStream;

use Test::Builder2::Mouse;
with 'Test::Builder2::Event';


=head1 NAME

Test::Builder2::Event::StartStream - Start of a test stream event

=head1 DESCRIPTION

This is an Event representing the start of a test stream.

A test stream is a set of results that belong together.
This description is terrible.

=head1 METHODS

=head3 event_type

The event type is C<start stream>.

=cut

sub event_type { "start stream" }

sub as_hash {
    return {
        event_type => "start stream",
    };
}

1;
