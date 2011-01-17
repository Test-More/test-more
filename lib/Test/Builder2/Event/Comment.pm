package Test::Builder2::Event::Comment;

use Test::Builder2::Mouse;
with 'Test::Builder2::Event';


=head1 NAME

Test::Builder2::Event::Comment - an event representing a comment

=head1 DESCRIPTION

An event representing a comment to be added to the formatted output.
This only makes sense in those formats which support comments like TAP
or XML.

This is different from a logging event in that it should never be shown
to the user unless they're looking at the raw formatter output.

=head2 Methods

=head3 event_type

The event type is C<comment>.

=cut

sub event_type { return "comment"; }

sub as_hash {
    my $self = shift;

    return {
        event_type      => $self->event_type,
        comment         => $self->comment,
    };
}


=head2 Attributes

=head3 comment

The text of the comment.

=cut

has comment =>
  is            => 'rw',
  isa           => 'Str',
  required      => 1
;

no Test::Builder2::Mouse;

1;
