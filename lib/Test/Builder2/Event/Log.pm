package Test::Builder2::Event::Log;

use Carp;

use Test::Builder2::Types;
use Test::Builder2::Mouse;
use Test::Builder2::Mouse::Util::TypeConstraints qw(enum coerce via from);
with 'Test::Builder2::Event';


=head1 NAME

Test::Builder2::Event::Log - a logging event

=head1 DESCRIPTION

This is an Event representing a message not directly associated with a
result.  For example, informing the user which database the test is
using.

=head2 Levels

Each event has a level associated with it to indicate how important it
is referred to as "priority".  This is modeled on syslog.  Here is
descriptions of each log level from highest to lowest priority.

=head3 highest

This will always be the highest prioirty level and is only used for
sorting and comparison purposes.  An event B<cannot> have this level.

=head3 alert

User intervention is required to proceed.

=head3 error

Used for messages indicating an unexpected error in the test.

Example: Uncaught exception, couldn't open a file, etc...

=head3 warning

Typically used for messages about a failed test.

Example: a failing test or a passing todo test

=head3 notice

Typically used for messages about an abnormal situtation which does
not cause the test to fail.

Example: a skipped or failing todo test

=head3 info

Information about the test useful for debugging a failure or rerunning
the test in the same way but of no value if the test passed normally.

Example: temp file names, random number seeds, SQL queries

=head3 debug

Information about the internal workings of the assert functions.

=head3 lowest

This will always be the lowest prioirty level and is only used for
sorting and comparison purposes.  An event B<cannot> have this level.


=head2 Using Levels

New levels may be introduced.  So when determining if a level should
be displayed, care should be taken to always work in ranges of levels
else a newly introduced level might be missed.  The primary mechanism
is to call L<between_levels>.

    # alert or higher
    if( $event->between_levels("alert", "highest") ) {
        alert($event->message);
    }
    # warning up to, but not including, alert
    elsif( $event->between_levels("warning", "alert") ) {
        print STDERR $event->message;
    }
    # everything up to, but not including, warning
    else {
        log($event->message);
    }


=head2 Methods

=head3 event_type

The event type is C<log>

=cut

sub event_type {
    return "log";
}


=head3 levels

    my @levels = $event->levels;

Returns the names of logging levels, as strings, in order from lowest
to highest.

This does not include the notational levels.

=cut


my @Real_Levels = qw( debug info notice warning error alert );
my @All_Levels  = ("lowest", @Real_Levels, "highest");

my %Level_Nums = do {
    my $i = 1;
    map { $_ => $i++ } @All_Levels
};

sub levels {
    return @Real_Levels;
}

sub as_hash {
    my $self = shift;

    return {
        event_type      => $self->event_type,
        message         => $self->message,
        level           => $self->level,
    };
}


=head3 between_levels

    $is_between = $event->between_levels($low_level, $high_level);

Returns true if C<< $event->level >> is greater than or equal to
$low_level and less than $high_level, false otherwise.

In set theory that's C<< [$low_level, $high_level) >>.

=cut

sub _level_num {
    my($self, $level) = @_;

    my $priority = $Level_Nums{$level};
    croak "'$level' is not a known log level" unless $priority;

    return $priority;
}

sub between_levels {
    my($self, $low, $high) = @_;

    my $priority = $self->_level_num($self->level);

    return $self->_level_num($low) <= $priority && $priority < $self->_level_num($high);
}


=head2 Attributes

=head3 message

The text associated with this log.

=cut

has message =>
  is            => 'rw',
  isa           => 'Str',
  required      => 1,
;

=head3 level

The severity level of this log message.  See L<Levels> for the
possible values and what they mean.

Defaults to C<debug>.

=cut

enum 'Test::Builder2::LogLevel'
  => \@Real_Levels;
coerce 'Test::Builder2::LogLevel' => from 'Str' => via { lc $_ };


has level =>
  is            => 'rw',
  isa           => 'Test::Builder2::LogLevel',
  default       => 'debug'
;


=head2 Types

=head3 Test::Builder2::LogLevel

A valid level for a L<Test::Builder2::Event::Log>

=cut


no Test::Builder2::Mouse;

1;
