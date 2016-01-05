package Test::Builder::Formatter;
use strict;
use warnings;

use base 'Test2::Formatter::TAP';

use Test2::Util::HashBase qw/no_header no_diag/;

BEGIN {
    *OUT_STD = Test2::Formatter::TAP->can('OUT_STD');
    *OUT_ERR = Test2::Formatter::TAP->can('OUT_ERR');

    my $todo = OUT_ERR() + 1;
    *OUT_TODO = sub() { $todo };
}

__PACKAGE__->register_event('Test::Builder::TodoDiag', 'event_todo_diag');

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    $self->{+HANDLES}->[OUT_TODO] = $self->{+HANDLES}->[OUT_STD];
}

sub event_todo_diag {
    my $self = shift;
    my @out = $self->event_diag(@_);
    $out[0]->[0] = OUT_TODO();
    return @out;
}

sub event_diag {
    my $self = shift;
    return if $self->{+NO_DIAG};
    return $self->SUPER::event_diag(@_);
}

sub event_plan {
    my $self = shift;
    return if $self->{+NO_HEADER};
    return $self->SUPER::event_plan(@_);
}

1;
