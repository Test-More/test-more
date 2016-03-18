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

    $self->{+RAND} = 1 unless defined $self->{+RAND};
}

1;
