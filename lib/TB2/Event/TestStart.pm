package TB2::Event::TestStart;

use TB2::Mouse;
with 'TB2::Event';

our $VERSION = '1.005000_006';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::Event::TestStart - Start of a test event

=head1 DESCRIPTION

This is an Event representing the start of a test.

A test is a set of related results and events.  There can be only one
test per L<TB2::TestState>.

=head1 METHODS

=head3 build_event_type

The event type is C<test_start>.

=cut

sub build_event_type { "test_start" }

1;
