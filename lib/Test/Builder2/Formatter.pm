package Test::Builder2::Formatter;

use Carp;
use Test::Builder2::Mouse;


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


=head3 new

  my $formatter = Test::Builder2::Formatter->new(%args);

Sets up a new formatter object to feed results.

=head3 begin

  $formatter->begin;
  $formatter->begin(%plan);

Indicates that testing is going to begin.  Gives $formatter the
opportunity to formatter a plan, do setup or formatter opening tags and
headers.

A %plan can be given, but there are currently no common attributes.

C<begin()> will only happen once per formatter instance.  Subsequent
calls will be ignored.  This helps coordinating multiple clients all
using the same formatter, they can all call C<begin()>.

Do not override C<begin()>.  Override C<INNER_begin()>.

=head3 has_begun

  my $has_begun = $formatter->has_begun;

Returns whether begin() has been called.

=cut

has has_begun =>
  is            => 'rw',
  isa           => 'Bool',
  default       => 0
;

sub begin {
    my $self = shift;

    return if $self->has_begun;

    $self->INNER_begin(@_);
    $self->has_begun(1);

    return;
}


=head3 result

  $formatter->result($result);

Formats a $result (an instance of L<Test::Builder2::Result>).

It is an error to call result() after end().

Do not override C<result()>.  Override C<INNER_result()>.

=cut

sub result {
    my $self = shift;

    croak "result() called after end()" if $self->has_ended;

    $self->INNER_result(@_);

    return;
}


=head3 end

  $formatter->end;
  $formatter->end(%plan);

Indicates that testing is done.  Gives $formatter the opportunity to
clean up, output closing tags, save the results or whatever.

No further results should be formatted after end().

Do not override C<end()>.  Override C<INNER_end()>.

=head3 has_ended

  my $has_ended = $formatter->has_ended;

Returns whether end() has been called.

=cut

has has_ended =>
  is            => 'rw',
  isa           => 'Bool',
  default       => 0
;

sub end {
    my $self = shift;

    return if $self->has_ended;

    $self->INNER_end(@_);
    $self->has_ended(1);

    return;
}


=head3 write

  $output->write($destination, @text);

Outputs C<@text> to the named $destination.

C<@text> is treated like C<print>, so it is simply concatenated.

In reality, this is a hand off to C<< $formatter->streamer->write >>.


=head2 Virtual Methods

These methods must be defined by the subclasser.

Do not override begin, result and end.  Override these instead.

=head3 INNER_begin

=head3 INNER_result

=head3 INNER_end

These implement the guts of begin, result and end.

=cut

1;
