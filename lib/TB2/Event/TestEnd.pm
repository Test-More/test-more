package TB2::Event::TestEnd;

use TB2::Mouse;
with 'TB2::Event';

our $VERSION = '1.005000_004';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::Event::TestEnd - End of a test event

=head1 DESCRIPTION

This is an Event representing the end of a test.

=head1 METHODS

=head3 build_event_type

The event type is C<test_end>.

=cut

sub build_event_type { "test_end" }

1;
