package Test::Stream::Tester::Events;
use strict;
use warnings;

use Test::Stream::Carp qw/confess/;
use Scalar::Util qw/blessed/;

sub new {
    my $class = shift;
    confess "XXX" if grep { !$_->isa('Test::Stream::Event') } @_;
    my $self = bless [map {$_->summary} @_], $class;
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
