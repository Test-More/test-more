package Test::Builder2::Streamer::Debug;
use Mouse;
with 'Test::Builder2::Streamer';

has written_hunks => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [] },
);

has read_position => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { {} },
);

sub write {
    my ($self, $dest, $hunk) = @_;
    push @{ $self->written_hunks }, [ $dest => $hunk ];
}

sub hunks_for {
    my ($self, $name) = @_;

    my @hunks =
        map  { $_->[1] }
        grep { $_->[0] eq $name }
        @{ $self->written_hunks };

    return @hunks;
}

sub read {
    my ($self, $name) = @_;

    my @hunks = $self->hunks_for($name);
    return '' unless @hunks;

    # Start with the ${old_pos}-th element and return everything through the
    # end, then set $new_pos to $#hunks + 1 -- rjbs, 2009-07-21
    my $old_pos = ($self->read_position->{ $name } ||= 0);
    my $new_pos = @hunks;

    return '' if $old_pos == $new_pos;

    @hunks = @hunks[ $old_pos .. $#hunks ];

    my $str = join '', @hunks;
    $self->read_position->{ $name } = $new_pos;

    return $str;
}

sub output_for {
    my ($self, $name) = @_;

    my $str = join '', $self->hunks_for($name);

    return $str;
}

no Mouse::Role;
1;
