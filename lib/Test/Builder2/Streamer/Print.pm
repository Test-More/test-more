package Test::Builder2::Streamer::Print;
use Mouse;
with 'Test::Builder2::Streamer';

has output_fh =>
  is            => 'rw',
  # "FileHandle" does not appear to include glob filehandles.
  #  isa           => 'FileHandle',
  default       => *STDOUT,
;

sub safe_print {
    my $self = shift;
    my($fh, @hunks) = @_;

    local( $\, $, ) = ( undef, '' );
    print $fh @hunks;
}

sub write {
    my ($self, $dest, @hunks) = @_;

    $self->safe_print($self->output_fh, @hunks);
}

no Mouse;
1;
