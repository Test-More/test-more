package Test::Builder2::Event::TestStart;

use Test::Builder2::Mouse;
with 'Test::Builder2::Event';


=head1 NAME

Test::Builder2::Event::TestStart - Start of a test stream event

=head1 DESCRIPTION

This is an Event representing the start of a test stream.

A test stream is a set of results that belong together.
This description is terrible.

=head1 METHODS

=head3 build_event_type

The event type is C<test_start>.

=cut

sub build_event_type { "test_start" }

1;
