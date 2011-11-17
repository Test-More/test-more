package Test::Builder2::Streamer::Print;
use Test::Builder2::Mouse;
with 'Test::Builder2::Streamer', 'Test::Builder2::CanDupFilehandles';


=head1 NAME

Test::Builder2::Streamer::Print - A simple streamer that prints

=head1 DESCRIPTION

This is a L<Test::Builder2::Streamer> which prints to a filehandle.

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

has output_fh =>
  is            => 'rw',
  # "FileHandle" does not appear to include glob filehandles.
  #  isa           => 'FileHandle',
  lazy          => 1,
  default       => sub {
      return $_[0]->stdout;
  }
;

=head3 stdout

Stores a duplicated copy of C<STDOUT>.  Handy for resetting the
output_fh().

=cut

has stdout =>
  is            => 'rw',
  default       => sub {
      my $self = shift;

      my $fh = $self->dup_filehandle(\*STDOUT);

      $self->autoflush($fh);
      $self->autoflush(*STDOUT);

      return $fh;
  }
;


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

no Test::Builder2::Mouse;
1;
