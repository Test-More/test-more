package TB2::Streamer::TAP;

use TB2::Mouse;
extends 'TB2::Streamer::Print';

our $VERSION = '1.005000_001';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::Streamer::TAP - A streamer for TAP output

=head1 DESCRIPTION

This is a streamer specific to the needs of the TAP formatter.  It is
a subclass of L<TB2::Streamer::Print>.

Basically, it adds a destination for errors.

=head2 Destinations

=head3 out

Where TAP output goes.  This connects to C<< $streamer->output_fh >>.

=head3 err

Where ad-hoc user visible comments go.  The unstructured "diagnostics".

=head2 Attributes

=head3 error_fh

The filehandle for the err destination.

Defaults to a copy of STDERR.

=cut

has error_fh  =>
  is            => 'rw',
#  isa           => 'FileHandle',
  lazy          => 1,
  default       => sub {
      return $_[0]->stderr;
  }
;

=head3 stderr

Stores a duplicated copy of C<STDERR>.  Handy for resetting the
error_fh().

=cut

has stderr =>
  is            => 'rw',
  default       => sub {
      my $self = shift;

      my $fh = $self->dup_filehandle(\*STDERR);

      $self->autoflush($fh);
      $self->autoflush(*STDERR);

      return $fh;
  }
;


my %Dest_Dest = (
    out => 'output_fh',
    err => 'error_fh',
);

sub write {
    my $self = shift;
    my $dest = shift;

    confess "unknown TAP stream destination" if ! exists $Dest_Dest{ $dest };

    my $fh_method = $Dest_Dest{ $dest };
    my $fh = $self->$fh_method;

    # This keeps "use Test::More tests => 2" from printing stuff when
    # compiling with -c.
    return if $^C;

    $self->safe_print($fh, @_);
}

no TB2::Mouse;
1;
