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
        my $e = $pkg->new($self, [@call[0 .. 4]], @_);
        $self->stream->send($e);
        return $e;
    };
}

sub call { $_[0]->frame->[0,4] }

sub send {
    my $self = shift;
    $self->stream->send(@_);
}

for my $stub (qw/frame stream encoding in_todo todo depth pid skip stage nest new/) {
    no strict 'refs';
    *$stub = sub {
        use strict 'refs';
        confess "Cannot call '$stub' directly on " . __PACKAGE__ . "\n"
            if __PACKAGE__ eq (ref $_[0] || $_[0]);

        confess "Context subclass did not override '$stub'! ($_[0])"
    };
}

1;
