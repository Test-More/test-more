package Test::Builder2::Streamer::Print;
use Mouse;
with 'Test::Builder2::Streamer';

sub write {
    my ($self, $dest, @hunks) = @_;
    print @hunks;
}

no Mouse::Role;
1;
