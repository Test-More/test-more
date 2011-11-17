package Test::Builder2::Formatter;

use Carp;
use Test::Builder2::Mouse;
use Test::Builder2::Types;

with 'Test::Builder2::EventHandler';


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

A Formatter is just a special L<Test::Builder2::EventHandler> which can
produce output.

=head1 METHODS

You must implement C<accept> methods as any C<EventHandler>.

In addition...

=head2 Attributes

=head3 streamer_class

Contains the class to use to make a Streamer.

Defaults to C<< $formatter->default_streamer_class >>

=head3 streamer

Contains the Streamer object to L<write> to.  One will be created for
you using C<< $formatter->streamer_class >>.

By default, the subtest handler inherits its parent's streamer.

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

sub subtest_handler {
    my $self = shift;
    return $self->new( streamer => $self->streamer );
}

=head3 new

  my $formatter = Test::Builder2::Formatter->new(%args);

Creates a new formatter object to feed results to.

You want to call this on a subclass.


=head3 write

  $output->write($destination, @text);

Outputs C<@text> to the named $destination.

C<@text> is treated like C<print>, so it is simply concatenated.

In reality, this is a hand off to C<< $formatter->streamer->write >>.

=cut

1;
