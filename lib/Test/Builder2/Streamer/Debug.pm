package Test::Builder2::Streamer::Debug;
use Mouse;
with 'Test::Builder2::Streamer';

has written_hunks => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [] },
);

sub write {
    my ($self, $dest, $hunk) = @_;
    push @{ $self->written_hunks }, [ $dest => $hunk ];
}

sub output_for {
    my ($self, $name) = @_;

    my $str = join '', grep { $_->[0] eq $name } @{ $self->written_hunks };
    return $str;
}

no Mouse::Role;
1;
