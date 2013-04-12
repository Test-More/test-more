package TB2::Formatter;

use Carp;
use TB2::Mouse;
use TB2::Types;

use TB2::threads::shared;

with 'TB2::EventHandler';

our $VERSION = '1.005000_006';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::Formatter - Base class for formatting test results

=head1 SYNOPSIS

  package TB2::Formatter::SomeFormat;

  use TB2::Mouse;
  extends "TB2::Formatter;

=head1 DESCRIPTION

Test::Builder2 delegates the actual formating of test results to a
TB2::Formatter object.  This can then decide if it's going to
formatter TAP or XML or send email or whatever.

A Formatter is just a special L<TB2::EventHandler> which can
produce output.

=head1 METHODS

You must implement C<handle> methods as any C<EventHandler>.

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
    return 'TB2::Streamer::Print';
}

has streamer_class => (
    is      => 'rw',
    isa     => 'TB2::LoadableClass',
    coerce  => 1,
    builder => 'default_streamer_class',
);

has streamer => (
    is      => 'rw',
    does    => 'TB2::Streamer',
    lazy    => 1,
    builder => '_build_streamer',
    handles => [ qw(write) ],
);

sub _build_streamer {
    return shared_clone( $_[0]->streamer_class->new );
}

sub subtest_handler {
    my $self = shift;
    return $self->new( streamer => $self->streamer );
}

=head2 Methods

=head3 new

  my $formatter = TB2::Formatter->new(%args);

Creates a new formatter object to feed results to.

You want to call this on a subclass.


=head3 write

  $formatter->write($destination, @text);

Outputs C<@text> to the named $destination.

C<@text> is treated like C<print>, so it is simply concatenated.

In reality, this is a hand off to C<< $formatter->streamer->write >>.

=head3 reset_streamer

  $formatter->reset_streamer;

Changes C<< $formatter->streamer >> back to the default.

=cut

sub reset_streamer {
    $_[0]->streamer( $_[0]->_build_streamer );
}

=head3 object_id

    my $id = $thing->object_id;

Returns an identifier for this object unique to the running process.
The identifier is fairly simple and easily predictable.

See L<TB2::HasObjectID>

=cut


1;
