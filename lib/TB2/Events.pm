package TB2::Events;

use strict;
use warnings;

our $VERSION = '1.005000_006';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

sub event_classes {
    return qw(
        TB2::Event::TestStart
        TB2::Event::TestEnd
        TB2::Event::SubtestStart
        TB2::Event::SubtestEnd
        TB2::Event::SetPlan
        TB2::Event::TestMetadata
        TB2::Event::Log
        TB2::Event::Comment
        TB2::Event::Abort
        TB2::Result
     );
}

BEGIN {
    for my $class (__PACKAGE__->event_classes) {
        eval "require $class" or die $@;
    }
}


=head1 NAME

TB2::Events - Convenience module to load all core TB2 events

=head1 SYNOPSIS

    use TB2::Events;

    my $event = TB2::Event::SetPlan->new( ... );

=head1 DESCRIPTION

This loads all the built-in Test::Builder2 events in one go.  It is
intended as a convenience for authors of builders.

=head2 Events Loaded

=head3 TB2::Event::TestStart

=head3 TB2::Event::TestEnd

=head3 TB2::Event::SubtestStart

=head3 TB2::Event::SubtestEnd

=head3 TB2::Event::SetPlan

=head3 TB2::Event::TestMetadata

=head3 TB2::Event::Log

=head3 TB2::Event::Comment

=head3 TB2::Event::Abort

=head3 TB2::Result


=cut

1;
