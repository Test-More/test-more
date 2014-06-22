package Test::Builder::Stream;
use strict;
use warnings;

use Carp qw/confess croak/;
use Scalar::Util qw/reftype blessed/;
use Test::Builder::ExitMagic;
use Test::Builder::Threads;
use Test::Builder::Util qw/accessors accessor deltas/;

accessors qw/plan/;
deltas qw/tests_run tests_failed/;

accessor no_ending    => sub { 0 };
accessor is_passing   => sub { 1 };
accessor _listeners   => sub {{ }};
accessor _mungers     => sub {{ }};
accessor _munge_order => sub {[ ]};
accessor _follow_up   => sub {{ }};

sub pid { shift->{pid} }

{
    my ($root, @shared);

    sub root { $root };

    sub shared {
        $root ||= __PACKAGE__->new;
        push @shared => $root unless @shared;
        return $shared[-1];
    };

    sub clear { $root = undef; @shared = () }

    sub intercept {
        my $class = shift;
        my ($code) = @_;

        confess "argument to intercept must be a coderef, got: $code"
            unless reftype $code eq 'CODE';

        my $orig = $class->intercept_start();
        local $@;
        my $ok = eval { $code->($shared[-1]); 1 };
        my $error = $@;
        $class->intercept_stop($orig);
        die $error unless $ok;
        return $ok;
    }

    sub intercept_start {
        my $class = shift;
        my $new = $_[0] || $class->new(no_follow => 1) || die "Internal error!";
        push @shared => $new;
        return $new;
    }

    sub intercept_stop {
        my $class = shift;
        my ($orig) = @_;
        confess "intercept nesting inconsistancy!"
            unless $shared[-1] == $orig;
        return pop @shared;
    }
}

sub new {
    my $class = shift;
    my %params = @_;
    my $self = bless { pid => $$ }, $class;

    share($self->{tests_run});
    share($self->{tests_failed});

    $self->use_tap         if $params{use_tap};
    $self->use_lresults    if $params{use_lresults};
    $self->legacy_followup unless $params{no_follow};

    return $self;
}

sub follow_up {
    my $self = shift;
    my ($type, @action) = @_;
    croak "'$type' is not a result type"
        unless $type && $type->isa('Test::Builder::Result');

    if (@action) {
        my ($sub) = @action;
        croak "The second argument to follow_up() must be a coderef, got: $sub"
            if $sub && !(ref $sub && reftype $sub eq 'CODE');

        $self->_follow_up->{$type} = $sub;
    }

    return $self->_follow_up->{$type};
}

sub legacy_followup {
    my $self = shift;
    $self->_follow_up({
        'Test::Builder::Result::Bail' => sub { exit 255 },
        'Test::Builder::Result::Plan' => sub {
            my ($plan) = @_;
            return unless $plan->directive;
            return unless $plan->directive eq 'SKIP';
            exit 0;
        },
    });
}

sub exception_followup {
    my $self = shift;

    $self->_follow_up({
        'Test::Builder::Result::Bail' => sub {die $_[0]},
        'Test::Builder::Result::Plan' => sub {
            my $plan = shift;
            return unless $plan->directive;
            return unless $plan->directive eq 'SKIP';
            die $plan;
        },
    });
}

sub expected_tests {
    my $self = shift;
    my $plan = $self->plan;
    return undef unless $plan;
    return $plan->max;
}

sub listener {
    my $self = shift;
    my ($id) = @_;
    confess("You must provide an ID for your listener") unless $id;

    confess("Listener ID's may not start with 'LEGACY_', those are reserved")
        if $id =~ m/^LEGACY_/ && caller ne __PACKAGE__;

    return $self->_listeners->{$id};
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

    my $listeners = $self->_listeners;

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

    my $listeners = $self->_listeners;

    confess("There is no listener with ID: $id")
        unless $listeners->{$id};

    delete $listeners->{$id};
}

sub munger {
    my $self = shift;
    my ($id) = @_;
    confess("You must provide an ID for your munger") unless $id;
    return $self->_mungers->{$id};
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

    my $mungers = $self->_mungers;

    confess("There is already a munger with ID: $id")
        if $mungers->{$id};

    push @{$self->_munge_order} => $id;
    $mungers->{$id} = $munger;

    return sub { $self->unmunge($id) };
}

sub unmunge {
    my $self = shift;
    my ($id) = @_;
    my $mungers = $self->_mungers;

    confess("You must provide an ID for your munger") unless $id;

    confess("There is no munger with ID: $id")
        unless $mungers->{$id};

    $self->_munge_order([ grep { $_ ne $id } @{$self->_munge_order} ]);
    delete $mungers->{$id};
}

sub send {
    my $self = shift;
    my ($item) = @_;

    # The redirect will return true if it intends to redirect, we should then return.
    # If it returns false that means we do not need to redirect and should act normally.
    if (my $redirect = $self->{fork}) {
        return if $redirect->(@_);
    }

    my $items = [$item];
    for my $munger_id (@{$self->_munge_order}) {
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
        for my $listener (values %{$self->_listeners}) {
            if (reftype $listener eq 'CODE') {
                $listener->($item)
            }
            else {
                $listener->handle($item);
            }
        }
    }

    for my $item (@$items) {
        my $type = blessed $item;
#        if ($type eq 'Test::Builder::Result::Ok') {
#            use Data::Dumper;
#            print $self . ": " . Dumper($item);
#        }
        my $follow = $self->follow_up($type) || next;
        $follow->($item);
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

sub use_fork {
    my $self = shift;

    return if $self->{fork};

    require Test::Builder::Fork;
    $self->{fork} = Test::Builder::Fork->new->handler;
}

sub no_fork {
    my $self = shift;

    return unless $self->{fork};

    delete $self->{fork}; # Turn it off.
}

sub spawn {
    my $self = shift;
    my (%params) = @_;

    my $new = blessed($self)->new();

    $new->{fork} = $self->{fork};

    my $refs = {
        listeners => $self->_listeners,
        mungers   => $self->_mungers,
    };

    $new->_munge_order([@{$self->_munge_order}]);

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

