package TB2::Streamer::Print;

use TB2::Mouse;
with 'TB2::Streamer', 'TB2::CanDupFilehandles';

our $VERSION = '1.005000_001';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::Streamer::Print - A simple streamer that prints

=head1 DESCRIPTION

This is a L<TB2::Streamer> which prints to a filehandle.

You are encouraged to subclass this Streamer if you're writing one
which prints.

=head2 Destinations

It ignores your destination.  Everything goes to the L<output_fh>.

=head2 Attributes

=head3 output_fh

The filehandle to which it should write.

Defaults to a copy of C<STDOUT>.  This allows tests to muck around
with STDOUT without it affecting test results.

=cut

use TB2::ThreadSafeFilehandleAccessor fh_accessors => [qw(output_fh)];

sub BUILD {
    my $self = shift;
    $self->output_fh( $self->stdout ) unless $self->output_fh;
    return $self;
}

=head3 stdout

Contains a duplicated copy of C<STDOUT>.  Handy for resetting the
output_fh().

It is read only.

=cut

my $stdout;
sub stdout {
    my $self = shift;

    return $stdout if $stdout;

    $stdout = $self->dup_filehandle(\*STDOUT);

    $self->autoflush($stdout);
    $self->autoflush(\*STDOUT);

    return $stdout;
}


=head3 stderr

Contains a duplicated copy of C<STDERR>.  Handy for resetting the
error_fh().

It is read only.

=cut

my $stderr;
sub stderr {
    my $self = shift;

    return $stderr if $stderr;

    $stderr = $self->dup_filehandle(\*STDERR);

    $self->autoflush($stderr);
    $self->autoflush(\*STDERR);

    return $stderr;
}


=head2 Methods

=head3 safe_print

    $streamer->safe_print($fh, @hunks);

Works like C<print> but is not effected by the global variables which
change print's behavior such as C<$\> and C<$,>.  This allows a test
to play with these variables without affecting test output.

Subclasses are encouraged to take advantage of this method rather than
calling print themselves.

=cut

sub safe_print {
    my $self = shift;
    my $fh   = shift;

    local( $\, $, ) = ( undef, '' );
    print $fh @_;
}

sub write {
    my $self = shift;
    my $dest = shift;

    # This keeps "use Test::More tests => 2" from printing stuff when
    # compiling with -c.
    return if $^C;

    $self->safe_print($self->output_fh, @_);
}

no TB2::Mouse;
1;
