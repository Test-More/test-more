package Test::Builder2::Event::SubtestStart;

use Test::Builder2::Mouse;
use Test::Builder2::Types;
with 'Test::Builder2::Event';


=head1 NAME

Test::Builder2::SubtestStart - Start of a subtest event

=head1 DESCRIPTION

This is a L<Test::Builder2::Event> representing the start of a subtest.

A subtest is a set of code and events which has a state separate from
the main test.  The intent is to provide a clean slate to perform
tests in small chunks.  This could be a block of tests in a larger
file, or the tests of a single method.

A subtest has its own history, plan and set of results.

Receiving this event indicates that a subtest is about to start, all
events from here to L<Test::Builder2::SubtestEnd> belong to the
subtest.  Most event watchers will not have to be concerned about
this, the TestState will call C<subtest_handler> on each event watcher
to get a new one to handle the subtest.

Information about the subtest can be communicated back to the parent
watcher via information contained in the
L<Test::Builder2::SubtestEnd>.

=head1 METHODS

It has all the methods and attributes of L<Test::Builder2::Event> with
the following differences and additions.

=head2 Attributes

=head3 depth

How deeply nested this subtest is.  The first subtest will have a
depth of 1.  A subtest inside that subtest will have a depth of 2 and
so on.

It has no default.  The depth is typically set by
L<Test::Builder2::TestState/post_event> and need not be set by the
creator of the event.  Only set it if you wish to override the normal
depth.

=cut

has depth =>
  is            => 'rw',
  isa           => 'Test::Builder2::Positive_NonZero_Int';


=head3 name

The name of this subtest.

=cut

has name =>
  is            => 'rw',
  isa           => 'Str',
  default       => '';


=head3 event_type

The event type is C<subtest start>.

=cut

sub event_type { return "subtest start" }

=head1 SEE ALSO

L<Test::Builder2::Event>  This does the Event role.

L<Test::Builder2::SubtestEnd>  The cooresponding event which ends the subtest.

L<Test::Builder2::EventWatcher/subtest_handler>  The method called on each Watcher when a subtest starts.

=cut

no Test::Builder2::Mouse;

1;
