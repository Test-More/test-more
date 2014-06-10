package Test::Builder::Result::Subtest;
use strict;
use warnings;

use parent 'Test::Builder::Result';

use Carp qw/confess/;

Test::Builder::Result::_accessors(qw/name plan/);

sub state {
    my $self = shift;
    if (@_) {
        my ($state) = @_;
        confess "state must be one of 'begin' or 'end'"
            unless $state =~ m/^(begin|end)$/;

        $self->{state} = $state;
    }

    confess "state was never set!"
        unless $self->{state};

    return $self->{state};
}

1;
