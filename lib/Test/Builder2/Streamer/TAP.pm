package Test::Builder2::Streamer::TAP;

use Test::Builder2::Mouse;
extends 'Test::Builder2::Streamer::Print';

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
    my ($self, $dest, @hunks) = @_;

    confess "unknown TAP stream destination" if ! exists $Dest_Dest{ $dest };

    my $fh_method = $Dest_Dest{ $dest };
    my $fh = $self->$fh_method;

    $self->safe_print($fh, @hunks);
}

no Test::Builder2::Mouse;
1;
