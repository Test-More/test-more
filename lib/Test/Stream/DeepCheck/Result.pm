package Test::Stream::DeepCheck::Result;
use strict;
use warnings;

use Carp qw/confess/;

use Test::Stream::HashBase(
    accessors => [qw/bool diag summary id deep checks/],
);

sub push_check {
    my $self = shift;
    $self->{+CHECKS} ||= [];
    push @{$self->{+CHECKS}} => @_;
}

sub init {
    my $self = shift;
    $self->{+DIAG} ||= [];
}

sub ok {
    my $self = shift;
    return ($self->{+BOOL}, @{$self->{+DIAG}});
}

sub fail {
    my $self = shift;
    $self->{+BOOL} = 0;
    return $self;
}

sub pass {
    my $self = shift;
    $self->{+BOOL} = 1;
    $self->{+DIAG} = [];
    return $self;
}

sub test {
    my $self = shift;
    my ($pass) = @_;
    $self->{+BOOL} = $pass ? 1 : 0;
    $self->{+DIAG} = [] if $pass;
    return $self;
}

1;
