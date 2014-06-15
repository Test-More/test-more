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
    my ($item) = @_;

    # The redirect will return true if it intends to redirect, we should then return.
    # If it returns false that means we do not need to redirect and should act normally.
    if (my $redirect = $self->redirect) {
        return if $redirect->(@_);
    }

    my $items = [$item];
    for my $munger_id (sort {$a <=> $b} keys %{$self->{mungers}}) {
        my $new_items;

        push @$new_items => $self->{mungers}->{$munger_id}->($_) for @$items;

        $items = $new_items;
    }

    for my $item (@$items) {
        $self->{counter} += 1 if $item->isa('Test::Builder::Result::Ok');
        for my $listener (values %{$self->{listeners}}) {
            $listener->($item);
        }
        $self->tap->handle($item) if $self->tap;
    }

}

sub tap { shift->{tap} }

sub use_tap {
    my $self = shift;
    require Test::Builder::Formatter::TAP;
    $self->{tap} ||= Test::Builder::Formatter::TAP->new();
}

sub no_tap {
    my $self = shift;
    delete $self->{tap};
    return;
}

sub clone {
    my $self = shift;
    my $new = blessed($self)->new();

    $new->{listeners} = $self->{listeners};
    $new->{mungers}   = $self->{mungers};
    $new->use_tap if $self->tap;

    return $new;
}

1;
