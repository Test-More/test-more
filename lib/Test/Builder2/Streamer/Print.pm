package Test::Builder2::Streamer::Print;
use Mouse;
with 'Test::Builder2::Streamer';

sub write {
    my ($self, $dest, $hunk) = @_;
    print "=== $dest ===\n$hunk\n";
}

no Mouse::Role;
1;
