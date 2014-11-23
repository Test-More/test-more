package Test::Stream::ForceExit;
use strict;
use warnings;

sub new {
    my $class = shift;

    my $done = 0;
    my $self = \$done;

    return bless $self, $class;
}

sub done {
    my $self = shift;
    ($$self) = @_ if @_;
    return $$self;
}

sub DESTROY {
    my $self = shift;
    return if $self->done;

    warn "Something prevented child process $$ from exiting when it should have, Forcing exit now!\n";
    $self->done(1); # Prevent duplicate message during global destruction
    exit 255;
}

1;
