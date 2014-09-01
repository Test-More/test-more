package Test::Stream::Context;
use strict;
use warnings;

use Carp qw/confess/;

sub register_event {
    my $class = shift;
    my ($pkg) = @_;
    my $name = lc($pkg);
    $name =~ s/^.*:://g;

    confess "Method '$name' is already defined, event '$pkg' cannot get a context method!"
        if $class->can($name);

    no strict 'refs';
    *$name = sub {
        use strict 'refs';
        my $self = shift;
        my @call = caller(0);
        my $e = $pkg->new($self->stash, [@call[0 .. 4]], @_);
        $self->stream->send($e);
        return $e;
    };
}

sub alert {
    my $self = shift;
    my ($msg) = @_;

    my @call = $self->call;

    warn "$msg at $call[1] line $call[2]\n";
}

sub throw {
    my $self = shift;
    my ($msg) = @_;

    my @call = $self->call;

    die "$msg at $call[1] line $call[2]\n";
}

sub package { $_[0]->frame->[0] }
sub file    { $_[0]->frame->[1] }
sub line    { $_[0]->frame->[2] }
sub subname { $_[0]->frame->[3] }

sub call { $_[0]->frame->[0,4] }

sub send {
    my $self = shift;
    $self->stream->send(@_);
}

for my $stub (qw/frame stream encoding in_todo todo depth pid skip stage nest new stash/) {
    no strict 'refs';
    *$stub = sub {
        use strict 'refs';
        confess "Cannot call '$stub' directly on " . __PACKAGE__ . "\n"
            if __PACKAGE__ eq (ref $_[0] || $_[0]);

        confess "Context subclass did not override '$stub'! ($_[0])"
    };
}

1;
