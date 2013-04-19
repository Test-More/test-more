package TB2::Event::Abort;

use TB2::Mouse;
with "TB2::Event";

our $VERSION = '1.005000_006';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::Event::Abort - Abort testing

=head1 SYNOPSIS

    use TB2::Event::Abort;

    my $abort = TB2::Event::Abort->new(
        reason => "Warp core breech imminent"
    );

=head1 DESCRIPTION

This event indicates that something has gone so wrong that testing has
been aborted.

Whomever issues it usually exits the process.

This is what TAP calls "bail out".

=head1 METHODS

This implements all the methods and attributes of
L<TB2::Event> with the following additions and
modifications.

=head3 build_event_type

The event type is C<abort>.

=cut

sub build_event_type { "abort" }

=head2 Attributes

=head3 reason

The reason for aborting.

=cut

has reason =>
  is            => 'rw',
  isa           => 'Str',
  default       => '';



no TB2::Mouse;
1;
