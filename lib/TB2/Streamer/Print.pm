package TB2::Streamer::Print;

use TB2::Mouse;
with 'TB2::Streamer', 'TB2::CanDupFilehandles';

our $VERSION = '1.005000_006';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::Streamer::Print - A simple streamer that prints

=head1 SYNOPSIS

    use TB2::Streamer::Print;

    my $streamer = TB2::Streamer::Print;

    $streamer->write( out => "something something" );
    $streamer->write( err => "something's wrong!" );

    # Redirect out to a new filehandle.
    $streamer->output_fh($fh);

=head1 DESCRIPTION

This is a L<TB2::Streamer> which prints to a filehandle.

You are encouraged to subclass this Streamer if you're writing one
which prints.

=head2 Destinations

These are the destinations understood by C<< $streamer->write >>.

=head3 out

Where normal output goes.  This connects to C<< $streamer->output_fh >>.

=head3 err

Where ad-hoc user visible comments go.  This connects to
C<< $streamer->error_fh >>.

=head2 Attributes

=head3 output_fh

This is the filehandle for normal output.  For example, TAP or XML or
HTML or whatever records the test state.

Defaults to a copy of C<STDOUT>.  This allows tests to muck around
with STDOUT without it affecting test results.

=head3 error_fh

This is the filehandle for error output.  This is normally human
readable information about the test as its running.  It is not part of
the TAP or XML or HTML or whatever.

Defaults to a copy of C<STDERR>.  This allows tests to muck around
with STDERR without it affecting test results.

=cut

use TB2::ThreadSafeFilehandleAccessor fh_accessors => [qw(output_fh error_fh)];

sub BUILD {
    my $self = shift;
    $self->output_fh( $self->stdout ) unless $self->output_fh;
    $self->error_fh ( $self->stderr ) unless $self->error_fh;
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


my %Dest_Dest = (
    out => 'output_fh',
    err => 'error_fh',
);

sub write {
    my $self = shift;
    my $dest = shift;

    confess "Unknown stream destination '$dest'" if !exists $Dest_Dest{$dest};

    my $fh_method = $Dest_Dest{ $dest };
    my $fh = $self->$fh_method;

    # This keeps "use Test::More tests => 2" from printing stuff when
    # compiling with -c.
    return if $^C;

    $self->safe_print($fh, @_);
}

no TB2::Mouse;
1;
