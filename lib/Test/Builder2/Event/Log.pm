package Test::Builder2::Event::Log;

use Test::Builder2::Types;
use Test::Builder2::Mouse;
with 'Test::Builder2::Event';


=head1 NAME

Test::Builder2::Event::Log - a logging event

=head1 DESCRIPTION

This is an Event representing a message not directly associated with a
result.  For example, informing the user which database the test is
using.

This is modeled after syslog.

=head2 Methods

=head3 event_type

The event type is C<log>

=cut

sub event_type {
    return "log";
}


=head3 levels

    my @levels = $event->levels;

Returns the names of logging levels, as strings, in order from highest
to lowest.

=cut

my @Levels = qw( emergency alert critical error warning notice info debug );
sub levels {
    return @Levels;
}


=head3 level_name

    my $name = $event->level_name;

Returns the name for the $event's level.

=cut

sub level_name {
    my $self = shift;
    return $Levels[$self->level];
}

sub as_hash {
    my $self = shift;

    return {
        event_type      => $self->event_type,
        message         => $self->message,
        level           => $self->level,
    };
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

The severity level of this log, with 0 being the highest severity and
7 the lowest.

These are based on syslog levels.

     Emergency     (level 0)
     Alert         (level 1)
     Critical      (level 2)
     Error         (level 3)
     Warning       (level 4)
     Notice        (level 5)
     Info          (level 6)
     Debug         (level 7)

Defaults to 7, debug.

=cut

has level =>
  is            => 'rw',
  isa           => 'Test::Builder2::LogLevel',
  default       => 7
;

no Test::Builder2::Mouse;

1;
