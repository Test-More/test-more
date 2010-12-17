package Test::Builder2::Event::EndStream;

use Test::Builder2::Mouse;
with 'Test::Builder2::Event';


=head1 NAME

Test::Builder2::Event::EndStream - End of a test stream event

=head1 DESCRIPTION

This is an Event representing the end of a test stream.

=head1 METHODS

=head3 event_type

The event type is C<end stream>.

=cut

sub event_type { "end stream" }

sub as_hash {
    return {
        event_type => "end stream",
    };
}

1;
