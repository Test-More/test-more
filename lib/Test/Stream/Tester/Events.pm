package Test::Stream::Tester::Events;
use strict;
use warnings;

use Scalar::Util qw/blessed/;

use Test::Stream::Tester::Events::Event;

sub new {
    my $class = shift;
    my $self = bless [map { Test::Stream::Tester::Events::Event->new($_->summary) } @_], $class;
    return $self;
}

sub next { shift @{$_[0]} };

sub seek {
    my $self = shift;
    my ($type) = @_;

    while (my $e = shift @$self) {
        return $e if $e->{type} eq $type;
    }

    return undef;
}

sub clone {
    my $self = shift;
    my $class = blessed($self);
    return bless [@$self], $class;
}

1;
