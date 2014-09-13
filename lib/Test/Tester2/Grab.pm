package Test::Tester2::Grab;
use strict;
use warnings;

sub new {
    my $class = shift;

    my $self = bless {
        events  => [],
        streams => [ Test::Stream->intercept_start ],
    }, $class;

    $self->{streams}->[0]->listen(
        sub {
            shift;    # Stream
            push @{$self->{events}} => @_;
        }
    );

    return $self;
}

sub flush {
    my $self = shift;
    my $out = delete $self->{events};
    $self->{events} = [];
    return $out;
}

sub events {
    my $self = shift;
    # Copy
    return [@{$self->{events}}];
}

sub finish {
    my ($self) = @_; # Do not shift;
    $_[0] = undef;

    $self->{finished} = 1;
    my ($remove) = $self->{streams}->[0];
    Test::Stream->intercept_stop($remove);

    return $self->flush;
}

sub DESTROY {
    my $self = shift;
    return if $self->{finished};
    my ($remove) = $self->{streams}->[0];
    Test::Stream->intercept_stop($remove);
}

1;
