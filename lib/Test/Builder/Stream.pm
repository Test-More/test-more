package Test::Builder::Stream;
use strict;
use warnings;

use Carp qw/confess/;
use Scalar::Util qw/reftype blessed/;
use Test::Builder::ExitMagic;
use Test::Builder::Threads;

{
    my ($root, $shared);

    sub root { $root };

    sub shared {
        $root   ||= __PACKAGE__->new;
        $shared ||= $root;
        return $shared;
    };

    sub clear { $root = undef; $shared = undef }

    sub intercept {
        my $class = shift;
        my ($code) = @_;

        confess "argument to intercept must be a coderef, got: $code"
            unless reftype $code eq 'CODE';

        my $orig = $shared;
        $shared = $class->new || die "Internal error!";
        local $@;
        my $ok = eval { $code->($shared); 1 };
        my $error = $@;
        $shared = $orig;
        die $error unless $ok;
        return $ok;
    }
}

sub new {
    my $class = shift;
    my %params = @_;
    my $self = bless {
        listeners    => {},
        mungers      => {},
        tests_run    => 0,
        tests_failed => 0,
        pid          => $$,
        plan         => undef,
        is_passing   => 1,
    }, $class;

    share($self->{tests_run});
    share($self->{tests_failed});

    $self->use_tap      if $params{use_tap};
    $self->use_lresults if $params{use_lresults};

    return $self;
}

sub pid { shift->{pid} }

sub plan {
    my $self = shift;
    ($self->{plan}) = @_ if @_;
    return $self->{plan};
}

sub expected_tests {
    my $self = shift;
    my $plan = $self->plan;
    return undef unless $plan;
    return $plan->max;
}

sub is_passing {
    my $self = shift;
    ($self->{is_passing}) = @_ if @_;
    return $self->{is_passing};
}

sub no_ending {
    my $self = shift;
    ($self->{no_ending}) = @_ if @_;
    return $self->{no_ending} || 0;
}

sub tests_run {
    my $self = shift;
    if (@_) {
        my ($delta) = @_;
        lock $self->{tests_run};
        $self->{tests_run} += $delta;
    }
    return $self->{tests_run};
}

sub tests_failed {
    my $self = shift;
    if (@_) {
        my ($delta) = @_;
        lock $self->{tests_failed};
        $self->{tests_failed} += $delta;
    }
    return $self->{tests_failed};
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

    confess("Listener ID's may not start with 'LEGACY_', those are reserved")
        if $id =~ m/^LEGACY_/ && caller ne __PACKAGE__;

    return $self->{listeners}->{$id};
}

sub listen {
    my $self = shift;
    my ($id, $listener) = @_;

    confess("You must provide an ID for your listener") unless $id;

    confess("Listener ID's may not start with 'LEGACY_', those are reserved")
        if $id =~ m/^LEGACY_/ && caller ne __PACKAGE__;

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

    confess("Listener ID's may not start with 'LEGACY_', those are reserved")
        if $id =~ m/^LEGACY_/ && caller ne __PACKAGE__;

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

sub send {
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
        if ($item->isa('Test::Builder::Result::Plan')) {
            $self->plan($item);
        }
        if ($item->isa('Test::Builder::Result::Ok')) {
            $self->tests_run(1);
            $self->tests_failed(1) unless $item->bool;
        }
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

sub spawn {
    my $self = shift;
    my (%params) = @_;

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

    if ($self->tap && !$params{no_tap}) {
        $new->use_tap;
        for my $field (qw/output failure_output todo_output/) {
            $new->tap->$field($self->tap->$field);
        }
    }

    $new->use_lresults if $self->lresults && !$params{no_lresults};

    return $new;
}

1;

