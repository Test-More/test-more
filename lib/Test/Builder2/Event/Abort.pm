package Test::Builder2::Event::Abort;

use strict;
use warnings;

use Test::Builder2::Mouse;
with "Test::Builder2::Event";


=head1 NAME

Test::Builder2::Event::Abort - Abort testing

=head1 SYNOPSIS

    use Test::Builder2::Event::Abort;

    my $abort = Test::Builder2::Event::Abort->new(
        reason => "Warp core breech imminent"
    );

=head1 DESCRIPTION

This event indicates that something has gone so wrong that testing has
been aborted.

Whomever issues it usually exits the process.

This is what TAP calls "bail out".

=head1 METHODS

This implements all the methods and attributes of
L<Test::Builder2::Event> with the following additions and
modifications.

=head3 event_type

The event type is C<abort>.

=cut

sub event_type { "abort" }

=head2 Attributes

=head3 reason

The reason for aborting.

=cut

has reason =>
  is            => 'rw',
  isa           => 'Str',
  default       => '';



no Test::Builder2::Mouse;
1;
