package Test::Builder2::Streamer::TAP;

use Test::Builder2::Mouse;
extends 'Test::Builder2::Streamer::Print';


=head1 NAME

Test::Builder2::Streamer::TAP - A streamer for TAP output

=head1 DESCRIPTION

This is a streamer specific to the needs of the TAP formatter.  It is
a subclass of L<Test::Builder2::Streamer::Print>.

Basically, it adds a destination for errors.

=head2 Destinations

=head3 out

Where TAP output goes.  This connects to C<< $streamer->output_fh >>.

=head3 err

Where ad-hoc user visible comments go.  The unstructured "diagnostics".

=head2 Attributes

=head3 error_fh

The filehandle for the err destination.

=cut

has error_fh  =>
  is            => 'rw',
#  isa           => 'FileHandle',
  default       => *STDERR,
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

    $self->safe_print($fh, @_);
}

no Test::Builder2::Mouse;
1;
