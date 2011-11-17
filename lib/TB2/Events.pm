package TB2::Events;

use strict;
use warnings;

our $VERSION = '1.005000_001';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


use TB2::Event::TestStart;
use TB2::Event::TestEnd;
use TB2::Event::SubtestStart;
use TB2::Event::SubtestEnd;
use TB2::Event::SetPlan;
use TB2::Event::TestMetadata;
use TB2::Event::Log;
use TB2::Event::Comment;
use TB2::Event::Abort;
use TB2::Result;


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

=head3 TB2::Event::SetPlan

=head3 TB2::Event::StreamMetadata

=head3 TB2::Event::Result

=cut

1;
