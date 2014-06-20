package Test::Builder::Result::Child;
use strict;
use warnings;

use parent 'Test::Builder::Result';

use Carp qw/confess/;

use Test::Builder::Util qw/accessors/;
accessors qw/name/;

sub action {
    my $self = shift;
    if (@_) {
        my ($action) = @_;
        confess "action must be one of 'push' or 'pop'"
            unless $action =~ m/^(push|pop)$/;

        $self->{action} = $action;
    }

    confess "action was never set!"
        unless $self->{action};

    return $self->{action};
}

sub to_tap { }

1;
