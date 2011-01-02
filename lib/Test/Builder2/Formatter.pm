package Test::Builder2::Formatter;

use Carp;
use Test::Builder2::Mouse;
use Test::Builder2::Types;

with 'Test::Builder2::Singleton',
     'Test::Builder2::EventWatcher';


=head1 NAME

Test::Builder2::Formatter - Base class for formating test results

=head1 SYNOPSIS

  package Test::Builder2::Formatter::SomeFormat;

  use Test::Builder2::Mouse;
  extends "Test::Builder2::Formatter;

=head1 DESCRIPTION

Test::Builder2 delegates the actual formating of test results to a
Test::Builder2::Formatter object.  This can then decide if it's going to
formatter TAP or XML or send email or whatever.

=head1 METHODS

=head2 Attributes

=head3 streamer_class

Contains the class to use to make a Streamer.

Defaults to C<< $formatter->default_streamer_class >>

=head3 streamer

Contains the Streamer object to L<write> to.  One will be created for
you using C<< $formatter->streamer_class >>.

=cut

sub default_streamer_class {
    return 'Test::Builder2::Streamer::Print';
}

has streamer_class => (
    is      => 'rw',
    isa     => 'Test::Builder2::LoadableClass',
    coerce  => 1,
    builder => 'default_streamer_class',
);

has streamer => (
    is      => 'rw',
    does    => 'Test::Builder2::Streamer',
    lazy    => 1,
    builder => '_build_streamer',
    handles => [ qw(write) ],
);

sub _build_streamer {
    return $_[0]->streamer_class->new;
}


=head3 singleton

  my $default_formatter = Test::Builder2::Formatter->singleton;

Returns the default shared formatter object.

The default Formatter is a Test::Builder2::Formatter::TAP object.

=cut

sub make_singleton {
    require Test::Builder2::Formatter::TAP;
    return Test::Builder2::Formatter::TAP->make_singleton;
}


=head3 create

  my $formatter = Test::Builder2::Formatter->new(%args);

Creates a new formatter object to feed results to.

You want to call this on a subclass.


=head3 stream_depth

  my $stream_depth = $formatter->stream_depth;

Returns how many C<stream start> events without C<stream end> events
have been seen.

For example...

    stream start

Would indicate a level of 1.

    stream start
      stream start
      stream end
      stream start

Would indicate a level of 2.

A value of 0 indiciates the Formatter is not in a stream.

A negative value will throw an exception.

=cut

has stream_depth =>
  is            => 'rw',
  isa           => 'Test::Builder2::Positive_Int',
  default       => 0
;


=head3 stream_depth_inc

=head3 stream_depth_dec

Increment and decrement the C<stream_depth>.

=cut

sub stream_depth_inc {
    my $self = shift;

    $self->stream_depth( $self->stream_depth + 1 );
}

sub stream_depth_dec {
    my $self = shift;

    $self->stream_depth( $self->stream_depth - 1 );
}


=head3 accept_event

  $formatter->accept_event($event);

Accept Events as they happen.

It will increment and decrement C<stream_depth> as C<stream start> and
C<stream end> events are seen.

Do not override C<accept_event()>.  Override C<INNER_accept_event()>.

=cut

sub accept_event {
    my $self  = shift;
    my $event = shift;
    my $ec    = shift;

    my $type = $event->event_type;
    if( $type eq 'stream start' ) {
        $self->stream_depth_inc;
    }
    elsif( $type eq 'stream end' ) {
        $self->stream_depth_dec;
    }

    $self->INNER_accept_event($event, $ec);

    return;
}

=head3 accept_result

  $formatter->accept_result($result);

Formats a $result (an instance of L<Test::Builder2::Result>).

It is an error to call accept_result() outside a stream.

Do not override C<accept_result()>.  Override C<INNER_accept_result()>.

=cut

sub accept_result {
    my $self = shift;

    croak "accept_result() called outside a stream" if !$self->stream_depth;

    $self->INNER_accept_result(@_);

    return;
}


=head3 write

  $output->write($destination, @text);

Outputs C<@text> to the named $destination.

C<@text> is treated like C<print>, so it is simply concatenated.

In reality, this is a hand off to C<< $formatter->streamer->write >>.

=cut

1;
