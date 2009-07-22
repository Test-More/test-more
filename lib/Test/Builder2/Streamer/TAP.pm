package Test::Builder2::Streamer::TAP;
use Mouse;
with 'Test::Builder2::Streamer';

sub output_fh { return *STDOUT }
sub error_fh  { return *STDERR }

my %Dest_Dest = (
    out => 'output_fh',
    err => 'error_fh',
);

sub write {
    my ($self, $dest, @hunks) = @_;

    confess "unknown TAP stream destination" if ! exists $Dest_Dest{ $dest };

    my $fh_method = $Dest_Dest{ $dest };
    my $fh = $self->$fh_method;

    print $fh @hunks;
}

no Mouse::Role;
1;
