package Test::Stream::Compare::Custom;
use strict;
use warnings;

use Test::Stream::Compare;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/code name operator/],
);

use Carp qw/croak/;

sub init {
    my $self = shift;

    croak "'code' is required" unless $self->{+CODE};

    $self->{+OPERATOR} ||= 'CODE(...)';
    $self->{+NAME}     ||= '<Custom Code>';
}

sub verify {
    my $self = shift;
    my ($got) = @_;

    my $code = $self->{+CODE};

    my ($ok) = $code->($got);

    return $ok;
}

sub diag {
    my $self = shift;
    my ($got) = @_;

    my $code = $self->{+CODE};

    my ($ok, @diag) = $code->($got);

    return @diag;
}

1;
