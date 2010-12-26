package Test::Builder2::Event::StreamStart;

use Test::Builder2::Mouse;
with 'Test::Builder2::Event';


=head1 NAME

Test::Builder2::Event::StreamStart - Start of a test stream event

=head1 DESCRIPTION

This is an Event representing the start of a test stream.

A test stream is a set of results that belong together.
This description is terrible.

=head1 METHODS

=head3 event_type

The event type is C<stream start>.

=cut

sub event_type { "stream start" }

sub as_hash {
    return {
        event_type => "stream start",
    };
}

1;
