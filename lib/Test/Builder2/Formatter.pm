package Test::Builder2::Formatter;

use strict;
use Mouse;


=head1 NAME

Test::Builder2::Formatter - Base class for formating test results

=head1 SYNOPSIS

  package Test::Builder2::Formatter::SomeFormat;

  use Mouse;
  extends "Test::Builder2::Formatter;

=head1 DESCRIPTION

Test::Builder2 delegates the actual formatter of test results to a
Test::Builder2::Formatter object.  This can then decide if it's going to
formatter TAP or XML or send email or whatever.

=head1 METHODS

=head3 new

  my $formatter = Test::Builder2::Formatter::TAP::v13->new(%args);

Sets up a new formatter object to feed results.

=head3 begin

  $formatter->begin;
  $formatter->begin(%plan);

Indicates that testing is going to begin.  Gives $formatter the
opportunity to formatter a plan, do setup or formatter opening tags and
headers.

A %plan can be given, but there are currently no common attributes.

=cut

sub begin {
    my $self = shift;

    $self->INNER_begin(@_);

    return;
}


=head3 result

  $formatter->result($result);

Formats a $result.

If begin() has not yet been called it will be.

=cut

sub result {
    my $self = shift;

    $self->INNER_result(@_);

    return;
}


=head3 end

  $formatter->end;
  $formatter->end(%plan);

Indicates that testing is done.  Gives $formatter the opportunity to
clean up, output closing tags, save the results or whatever.

No further results should be formatted after end().

=cut

sub end {
    my $self = shift;

    $self->INNER_end(@_);

    return;
}


=head3 write

  $output->write($destination, @text);

Outputs C<@text> to the named destination.

C<@text> is treated like C<print>, so it is simply concatenated.

=cut

sub default_streamer_class { 'Test::Builder2::Streamer::Print' }

has streamer_class => (
    is      => 'ro',
    builder => 'default_streamer_class',
);

has streamer => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
      my $class = $_[0]->streamer_class;
      eval "require $class; 1" or die;
      $class->new;
    },
    handles => [ qw(write) ],
);

=head2 Virtual Methods

These methods must be defined by the subclasser.

Do not override begin, result and end.  Override these instead.

=head3 INNER_begin

=head3 INNER_result

=head3 INNER_end

These implement the guts of begin, result and end.

=cut

1;
