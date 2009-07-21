package Test::Builder2::Output;

use strict;
use Mouse;


=head1 NAME

Test::Builder2::Output - Base class for outputting test results

=head1 SYNOPSIS

  package Test::Builder2::Output::SomeFormat;

  use Mouse;
  extends "Test::Builder2::Output;

=head1 DESCRIPTION

Test::Builder2 delegates the actual output of test results to a
Test::Builder2::Output object.  This can then decide if it's going to
output TAP or XML or send email or whatever.

=head1 METHODS

=head3 new

  my $output = Test::Builder2::Output::TAP::v13->new(%args);

Sets up a new output object to feed results.

=head3 begin

  $output->begin;
  $output->begin(%plan);

Indicates that testing is going to begin.  Gives $output the
opportunity to output a plan, do setup or output opening tags and
headers.

A %plan can be given, but there are currently no common attributes.

=cut

sub begin {
    my $self = shift;

    $self->INNER_begin(@_);

    return;
}


=head3 result

  $output->result($result);

Outputs a $result.

If begin() has not yet been called it will be.

=cut

sub result {
    my $self = shift;

    $self->INNER_result(@_);

    return;
}


=head3 end

  $output->end;
  $output->end(%plan);

Indicates that testing is done.  Gives $output the opportunity to
clean up, output closing tags, save the results or whatever.

No further results should be output after end().

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

None of the global variables which effect print ($\, $" and so on)
will effect C<out()>.

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
