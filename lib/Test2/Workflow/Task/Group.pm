package Test2::Workflow::Task::Group;
use strict;
use warnings;

use Carp qw/croak/;

use Test2::Workflow::Task::Action;

use base 'Test2::Workflow::Task';
use Test2::Util::HashBase qw/before after primary rand variant/;

sub init {
    my $self = shift;

    if (my $take = delete $self->{take}) {
        $self->{$_} = delete $take->{$_} for ISO, ASYNC, TODO, SKIP;
        $self->{$_} = $take->{$_} for FLAT, SCAFFOLD, NAME, CODE, FRAME;
        $take->{+FLAT}     = 1;
        $take->{+SCAFFOLD} = 1;
    }

    {
        local $Carp::CarpLevel = $Carp::CarpLevel + 1;
        $self->SUPER::init();
    }

    $self->{+BEFORE}  ||= [];
    $self->{+AFTER}   ||= [];
    $self->{+PRIMARY} ||= [];
}

sub filter {
    my $self = shift;
    my ($filter) = @_;

    return unless $filter;
    return if $self->{+IS_ROOT};
    return if $self->{+SCAFFOLD};

    my $result = $self->SUPER::filter($filter);

    # If this is not a variant then we do nothing special.
    return $result unless $self->{+VARIANT};

    # The variant matches the filter, no more filtering below
    return {satisfied => 1} unless $result;

    for my $c (@{$self->{+PRIMARY}}) {
        # A child matches the filter, so we should not be filtered, but also
        # should not satisfy the filter.
        my $res = $c->filter($filter) or return;

        # A child satisfies the filter
        return if $res->{satisfied};
    }

    return $result;
}

1;
