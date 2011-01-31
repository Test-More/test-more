package Test::Builder2::Event::Log;

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

The severity level of this log.  These are based on syslog levels.

Here are the levels from highest to lowest.

     emergency
     alert
     critical
     error
     warning
     notice
     info
     debug

Defaults to C<debug>.

=cut

enum 'Test::Builder2::LogLevel'
  => \@Levels;
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
