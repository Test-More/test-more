package TB2::Event::SubtestEnd;

use TB2::Mouse;
use TB2::Types;
with 'TB2::Event';

our $VERSION = '1.005000_001';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::SubtestEnd - End of a subtest event

=head1 DESCRIPTION

This is a L<TB2::Event> representing the end of a subtest.

Receiving this event indicates to the parent that the subtest has
ended.  All events from here out belong to the current test level.
Most event handlers will not have to be concerned about this.

Information about the subtest will be communicated back to the parent
handler via C<<$subtest_end->history>>

=head1 METHODS

It has all the methods and attributes of L<TB2::Event> with
the following differences and additions.

=head2 Attributes

=head3 history

The L<TB2::History> object from the subtest.

This can be used by event handlers to get information from the subtest.

Normally this will be filled in by L<TB2::TestState> during
posting.  A builder may put in an alternative history object.

=cut

has history =>
  is            => 'rw',
  isa           => 'TB2::History',
;

=head3 build_event_type

The event type is C<subtest_end>.

=cut

sub build_event_type { "subtest_end" }

=head1 SEE ALSO

L<TB2::Event>  This does the Event role.

L<TB2::SubtestStart>  The cooresponding event which starts the subtest.

=cut

no TB2::Mouse;

1;
