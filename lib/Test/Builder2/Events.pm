package Test::Builder2::Events;

use strict;
use warnings;

use Test::Builder2::Event::StreamStart;
use Test::Builder2::Event::StreamEnd;
use Test::Builder2::Event::SetPlan;
use Test::Builder2::Event::StreamMetadata;
use Test::Builder2::Event::Log;
use Test::Builder2::Event::Comment;
use Test::Builder2::Result;


=head1 NAME

Test::Builder2::Events - Convenience module to load all core TB2 events

=head1 SYNOPSIS

    use Test::Builder2::Events;

    my $event = Test::Builder2::Event::SetPlan->create( ... );

=head1 DESCRIPTION

This loads all the built-in Test::Builder2 events in one go.  It is
intended as a convenience for authors of builders.

=head2 Events Loaded

=head3 Test::Builder2::Event::StreamStart

=head3 Test::Builder2::Event::StreamEnd

=head3 Test::Builder2::Event::SetPlan

=head3 Test::Builder2::Event::StreamMetadata

=head3 Test::Builder2::Event::Result

=cut

1;
