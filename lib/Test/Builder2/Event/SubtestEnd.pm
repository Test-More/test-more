package Test::Builder2::Event::SubtestEnd;

use Test::Builder2::Mouse;
use Test::Builder2::Types;
with 'Test::Builder2::Event';


=head1 NAME

Test::Builder2::SubtestEnd - End of a subtest event

=head1 DESCRIPTION

This is a L<Test::Builder2::Event> representing the end of a subtest.

Receiving this event indicates to the parent that the subtest has
ended.  All events from here out belong to the current test level.
Most event watchers will not have to be concerned about this.

Information about the subtest will be communicated back to the parent
watcher via C<<$subtest_end->history>>

=head1 METHODS

It has all the methods and attributes of L<Test::Builder2::Event> with
the following differences and additions.

=head2 Attributes

=head3 history

The L<Test::Builder2::History> object from the subtest.

This can be used by event watchers to get information from the subtest.

Normally this will be filled in by L<Test::Builder2::TestState> during
posting.  A builder may put in an alternative history object.

=cut

has history =>
  is            => 'rw',
  isa           => 'Test::Builder2::History',
;

=head3 event_type

The event type is C<subtest end>.

=cut

sub event_type { return "subtest end" }

=head1 SEE ALSO

L<Test::Builder2::Event>  This does the Event role.

L<Test::Builder2::SubtestStart>  The cooresponding event which starts the subtest.

=cut

no Test::Builder2::Mouse;

1;
