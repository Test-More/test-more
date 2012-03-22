package MyEventCoordinator;

use TB2::Mouse;
extends 'TB2::EventCoordinator';

=head1 NAME

MyEventCoordinator - An EventCoordinator for testing

=head1 SYNOPSIS

    use lib 't/lib';
    use MyEventCoordinator;

    my $ec = MyEventCoordinator->new;

=head1 DESCRIPTION

A subclass of L<TB2::EventCoordinator> for testing events
and event handlers.

It makes the following changes:

  * It has no default formatter

=cut

sub default_formatters { [] }

no TB2::Mouse;

1;
