package Test::Builder2::Streamer::Debug;
use Test::Builder2::Mouse;
with 'Test::Builder2::Streamer';

has written_hunks => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [] },
);

has read_position_for => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { {} },
);

has read_all_position => (
    is       => 'rw',
    default  => 0,
);

sub write {
    my ($self, $dest, @hunks) = @_;
    push @{ $self->written_hunks }, [ $dest => join '', @hunks ];
}

sub hunks_for {
    my ($self, $name) = @_;

    my @hunks =
        map  { $_->[1] }
        grep { $_->[0] eq $name }
        @{ $self->written_hunks };

    return @hunks;
}

sub read_all {
    my ($self) = @_;

    return '' unless my @hunks = map { $_->[1] } @{ $self->written_hunks };

    my $old_pos = $self->read_all_position;
    my $new_pos = @hunks;

    return '' if $old_pos == $new_pos;

    @hunks = @hunks[ $old_pos .. $#hunks ];

    my $str = join '', @hunks;
    $self->read_all_position($new_pos);

    return $str;
}

sub read {
    my ($self, $name) = @_;

    return $self->read_all unless defined $name;

    return '' unless my @hunks = $self->hunks_for($name);

    my $old_pos = ($self->read_position_for->{ $name } ||= 0);
    my $new_pos = @hunks;

    return '' if $old_pos == $new_pos;

    @hunks = @hunks[ $old_pos .. $#hunks ];

    my $str = join '', @hunks;
    $self->read_position_for->{ $name } = $new_pos;

    return $str;
}

sub output_for {
    my ($self, $name) = @_;

    my $str = join '', $self->hunks_for($name);

    return $str;
}

sub all_output {
    my ($self) = @_;
    join '', map { $_->[1] } @{ $self->written_hunks };
}

no Test::Builder2::Mouse::Role;
1;
