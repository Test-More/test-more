package Test::Builder2::Event::StreamEnd;

use Test::Builder2::Mouse;
with 'Test::Builder2::Event';


=head1 NAME

Test::Builder2::Event::StreamEnd - End of a test stream event

=head1 DESCRIPTION

This is an Event representing the end of a test stream.

=head1 METHODS

=head3 event_type

The event type is C<stream end>.

=cut

sub event_type { "stream end" }

sub as_hash {
    return {
        event_type => "stream end",
    };
}

1;
