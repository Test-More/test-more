package TB2::Event::Comment;

use TB2::Mouse;
with 'TB2::Event';

our $VERSION = '1.005000_001';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::Event::Comment - an event representing a comment

=head1 DESCRIPTION

An event representing a comment to be added to the formatted output.
This only makes sense in those formats which support comments like TAP
or XML.

This is different from a logging event in that it should never be shown
to the user unless they're looking at the raw formatter output.

=head2 Methods

=head3 build_event_type

The event type is C<comment>.

=cut

sub build_event_type { "comment" }

=head2 Attributes

=head3 comment

The text of the comment.

=cut

has comment =>
  is            => 'rw',
  isa           => 'Str',
  required      => 1
;

no TB2::Mouse;

1;
