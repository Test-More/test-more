package Test::Builder::Stream;
use strict;
use warnings;

use Carp qw/confess/;
use Scalar::Util qw/reftype blessed/;

sub new {
    my $class = shift;
    return bless { listeners => {}, mungers => {}, counter => 0 }, $class;
}

sub redirect {
    my $self = shift;

    if (@_) {
        confess "redirect already set by [" . join(', ', @{$self->{redirect_caller}}) . "]" if $self->{redirect};

        my ($code) = @_;

        if ($code) {
            confess("Redirect must be a code ref")
                unless reftype $code and reftype $code eq 'CODE';

            $self->{redirect} = $code;
            $self->{redirect_caller} = [caller];
        }
        else { # Turning it off
            delete $self->{redirect};
            delete $self->{redirect_caller};
        }
    }

    return $self->{redirect};
}

my $listen_id = 1;
sub listen {
    my $self = shift;
    my ($listener) = @_;

    confess("Listeners must be code refs")
        unless $listener && reftype $listener and reftype $listener eq 'CODE';

    my $id = $listen_id++;
    my $listeners = $self->{listeners};
    $listeners->{$id} = $listener;
    return sub { delete $listeners->{$id} };
}

my $munge_id = 1;
sub munge {
    my $self = shift;
    my ($munger) = @_;

    confess("Mungers must be code refs")
        unless $munger && reftype $munger and reftype $munger eq 'CODE';

    my $id = $munge_id++;
    my $mungers = $self->{mungers};
    $mungers->{$id} = $munger;
    return sub { delete $mungers->{$id} };
}

sub push {
    my $self = shift;
    my ($tb, $item) = @_;

    confess("Did not get a Test::Builder! ($tb)")
        unless $tb && blessed($tb) && $tb->isa('Test::Builder');

    # The redirect will return true if it intends to redirect, we should then return.
    # If it returns false that means we do not need to redirect and should act normally.
    if (my $redirect = $self->redirect) {
        return if $redirect->(@_);
    }

    my $items = [$item];
    for my $munger_id (sort {$a <=> $b} keys %{$self->{mungers}}) {
        my $new_items;

        push @$new_items => $self->{mungers}->{$munger_id}->($tb, $_) for @$items;

        $items = $new_items;
    }

    for my $item (@$items) {
        $self->{counter} += 1 if $item->isa('Test::Builder::Result::Ok');
        for my $listener (values %{$self->{listeners}}) {
            $listener->($tb, $item);
        }
    }
}

1;
