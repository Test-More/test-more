package Test2::Workflow::Task::Group;
use strict;
use warnings;

use Carp qw/croak/;

use Test2::Workflow::Task::Action;

use base 'Test2::Workflow::Task';
use Test2::Util::HashBase qw/before after primary rand variant/;

sub init {
    my $self = shift;

    $self->{+CODE}  ||= sub { 1 };
    $self->{+FRAME} ||= ['NONE', 'NONE', 1];

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
