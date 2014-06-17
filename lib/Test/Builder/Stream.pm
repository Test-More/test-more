package Test::Builder::Stream;
use strict;
use warnings;

use Carp qw/confess/;
use Scalar::Util qw/reftype blessed/;

sub new {
    my $class = shift;
    return bless { listeners => {}, mungers => {} }, $class;
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

sub listener {
    my $self = shift;
    my ($id) = @_;
    confess("You must provide an ID for your listener") unless $id;
    return $self->{listeners}->{$id};
}

sub listen {
    my $self = shift;
    my ($id, $listener) = @_;

    confess("You must provide an ID for your listener") unless $id;

    confess("Listeners must be code refs, or objects that implement handle(), got: $listener")
        unless $listener && (
            (reftype $listener && reftype $listener eq 'CODE')
            ||
            (blessed $listener && $listener->can('handle'))
        );

    my $listeners = $self->{listeners};

    confess("There is already a listener with ID: $id")
        if $listeners->{$id};

    $listeners->{$id} = $listener;
    return sub { $self->unlisten($id) };
}

sub unlisten {
    my $self = shift;
    my ($id) = @_;

    confess("You must provide an ID for your listener") unless $id;

    my $listeners = $self->{listeners};

    confess("There is no listener with ID: $id")
        unless $listeners->{$id};

    delete $listeners->{$id};
}

sub munger {
    my $self = shift;
    my ($id) = @_;
    confess("You must provide an ID for your munger") unless $id;
    return $self->{mungers}->{$id};
}

sub munge {
    my $self = shift;
    my ($id, $munger) = @_;

    confess("You must provide an ID for your munger") unless $id;

    confess("Mungers must be code refs, or objects that implement handle(), got: $munger")
        unless $munger && (
            (reftype $munger && reftype $munger eq 'CODE')
            ||
            (blessed $munger && $munger->can('handle'))
        );

    my $mungers = $self->{mungers};

    confess("There is already a munger with ID: $id")
        if $mungers->{$id};

    push @{$self->{munge_order}} => $id;
    $mungers->{$id} = $munger;

    return sub { $self->unmunge($id) };
}

sub unmunge {
    my $self = shift;
    my ($id) = @_;
    my $mungers = $self->{mungers};

    confess("You must provide an ID for your munger") unless $id;

    confess("There is no munger with ID: $id")
        unless $mungers->{$id};

    $self->{munge_order} = [ grep { $_ ne $id } @{$self->{munge_order}} ];
    delete $mungers->{$id};
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
    for my $munger_id (@{$self->{munge_order}}) {
        my $new_items = [];
        my $munger = $self->munger($munger_id) || next;
        
        for my $item (@$items) {
            push @$new_items => reftype $munger eq 'CODE' ? $munger->($item) : $munger->handle($item);
        }

        $items = $new_items;
    }

    for my $item (@$items) {
        for my $listener (values %{$self->{listeners}}) {
            if (reftype $listener eq 'CODE') {
                $listener->($item)
            }
            else {
                $listener->handle($item);
            }
        }
    }

}

sub tap { shift->listener('LEGACY_TAP') }

sub use_tap {
    my $self = shift;
    return if $self->tap;
    require Test::Builder::Formatter::TAP;
    $self->listen(LEGACY_TAP => Test::Builder::Formatter::TAP->new());
}

sub no_tap {
    my $self = shift;
    $self->unlisten('LEGACY_TAP');
    return;
}

sub lresults { shift->listener('LEGACY_RESULTS') }

sub use_lresults {
    my $self = shift;
    return if $self->lresults;
    require Test::Builder::Formatter::LegacyResults;
    $self->listen(LEGACY_RESULTS => Test::Builder::Formatter::LegacyResults->new());
}

sub no_lresults {
    my $self = shift;
    $self->unlisten('LEGACY_RESULTS');
    return;
}

sub clone {
    my $self = shift;
    my $new = blessed($self)->new();

    $new->{redirect} = $self->redirect;

    my $refs = {
        listeners => $self->{listeners},
        mungers   => $self->{mungers},
    };

    for my $type (keys %$refs) {
        for my $key (keys %{$refs->{$type}}) {
            next if $key eq 'LEGACY_TAP';
            next if $key eq 'LEGACY_RESULTS';
            $self->{$type}->{$key} = sub {
                my $item = $refs->{$type}->{$key} || return;
                return $item->(@_) if reftype $item eq 'CODE';
                $item->handle(@_);
            };
        }
    }

    if ($self->tap) {
        $new->use_tap;
        for my $field (qw/output failure_output todo_output/) {
            $new->tap->$field($self->tap->$field);
        }
    }

    $new->use_lresults if $self->lresults;

    return $new;
}

1;
