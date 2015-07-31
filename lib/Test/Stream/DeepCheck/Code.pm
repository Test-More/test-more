package Test::Stream::DeepCheck::Code;
use strict;
use warnings;

use Test::Stream::DeepCheck::Result;
use Test::Stream::DeepCheck::Check;
use Test::Stream::HashBase(
    base      => 'Test::Stream::DeepCheck::Check',
    accessors => [qw/code name/],
);

use Test::Stream::DeepCheck qw/stringify deeptype/;
use Carp qw/croak/;

sub as_string {
    my $self = shift;
    my $name = $self->{+NAME} || return '<Custom Code Check>';
    return "<$name>";
}

sub init {
    my $self = shift;
    croak "'code' is a required attribute"
        unless $self->{+CODE};

    croak "'code' must be a coderef"
        unless deeptype($self->{+CODE}) eq 'CODE';
}

sub run {
    my $self = shift;
    my ($got, $path, $state) = @_;
    my $code = $self->{+CODE};

    my @summary = (stringify($got), $self->as_string);

    my ($ok, @diag) = $code->($got);

    unshift @diag => "\$got$path: $summary[0]"
        unless $ok;

    my $res = Test::Stream::DeepCheck::Result->new(
        checks  => [$self],
        diag    => \@diag,
        summary => \@summary
    );

    return $res->pass if $ok;
    return $res->fail;
}

1;
