package Test::Stream::Hub;
use strict;
use warnings;

use Carp qw/carp croak/;
use Test::Stream::State();
use Test::Stream::Util qw/get_tid/;

use Scalar::Util qw/weaken/;

use Test::Stream::HashBase(
    accessors => [qw{
        pid tid hid ipc
        state
        no_ending
        _todo _meta parent_todo
        _mungers
        _filters
        _listeners
        _follow_ups
        _formatter
        _context_init
        _context_release
    }],
);

my $ID_POSTFIX = 1;
sub init {
    my $self = shift;

    $self->{+PID} = $$;
    $self->{+TID} = get_tid();
    $self->{+HID} = join '-', $self->{+PID}, $self->{+TID}, $ID_POSTFIX++;

    $self->{+_TODO} = [];
    $self->{+_META} = {};

    $self->{+STATE} ||= Test::Stream::State->new;

    if (my $formatter = delete $self->{formatter}) {
        $self->format($formatter);
    }

    if (my $ipc = $self->{+IPC}) {
        $ipc->add_hub($self->{+HID});
    }
}

sub inherit {
    my $self = shift;
    my ($from, %params) = @_;

    $self->{+_FORMATTER} = $from->{+_FORMATTER}
        unless $self->{+_FORMATTER} || exists($params{formatter});

    if ($from->{+IPC} && !$self->{+IPC} && !exists($params{ipc})) {
        my $ipc = $from->{+IPC};
        $self->{+IPC} = $ipc;
        $ipc->add_hub($self->{+HID});
    }

    if (my $ls = $from->{+_LISTENERS}) {
        push @{$self->{+_LISTENERS}} => grep { $_->{inherit} } @$ls;
    }

    if (my $ms = $from->{+_MUNGERS}) {
        push @{$self->{+_MUNGERS}} => grep { $_->{inherit} } @$ms;
    }

    if (my $fs = $from->{+_FILTERS}) {
        push @{$self->{+_FILTERS}} => grep { $_->{inherit} } @$fs;
    }
}

sub debug_todo {
    carp "The Hub->debug_todo method is deprecated";
    $_[0]->_debug_todo;
}

sub _debug_todo {
    my ($self) = @_;
    my $array = $self->{+_TODO};
    pop @$array while @$array && !defined $array->[-1];
    return (
        parent_todo => $self->{+PARENT_TODO},
        todo        => @$array ? ${$array->[-1]} : undef,
    )
}

sub _fast_todo {
    my ($self) = @_;
    my $array = $self->{+_TODO};
    pop @$array while @$array && !defined $array->[-1];
    my $todo = @$array ? ${$array->[-1]} : undef;
    return (
        diag_todo => $todo || $self->{+PARENT_TODO},
        todo      => $todo,
    )
}

sub meta {
    my $self = shift;
    my ($key, $default) = @_;

    croak "Invalid key '" . (defined($key) ? $key : '(UNDEF)') . "'"
        unless $key;

    my $exists = $self->{+_META}->{$key};
    return undef unless $default || $exists;

    $self->{+_META}->{$key} = $default unless $exists;

    return $self->{+_META}->{$key};
}

sub delete_meta {
    my $self = shift;
    my ($key) = @_;

    croak "Invalid key '" . (defined($key) ? $key : '(UNDEF)') . "'"
        unless $key;

    delete $self->{+_META}->{$key};
}

sub set_todo {
    my $self = shift;
    my ($reason) = @_;

    unless (defined wantarray) {
        carp "set_todo(...) called in void context, todo not set!";
        return;
    }

    unless(defined $reason) {
        carp "set_todo() called with undefined argument, todo not set!";
        return;
    }

    my $ref = \$reason;
    push @{$self->{+_TODO}} => $ref;
    weaken($self->{+_TODO}->[-1]);
    return $ref;
}

sub get_todo {
    my $self = shift;
    my $array = $self->{+_TODO};
    pop @$array while @$array && !defined($array->[-1]);
    return undef unless @$array;
    return ${$array->[-1]};
}

sub format {
    my $self = shift;

    my $old = $self->{+_FORMATTER};
    ($self->{+_FORMATTER}) = @_ if @_;

    return $old;
}

sub is_local {
    my $self = shift;
    return $$ == $self->{+PID}
        && get_tid() == $self->{+TID};
}

sub listen {
    my $self = shift;
    my ($sub, %params) = @_;

    carp "Useless addition of a listener in a child process or thread!"
        if $$ != $self->{+PID} || get_tid() != $self->{+TID};

    croak "listen only takes coderefs for arguments, got '$sub'"
        unless ref $sub && ref $sub eq 'CODE';

    push @{$self->{+_LISTENERS}} => { %params, code => $sub };

    $sub; # Intentional return.
}

sub unlisten {
    my $self = shift;

    carp "Useless removal of a listener in a child process or thread!"
        if $$ != $self->{+PID} || get_tid() != $self->{+TID};

    my %subs = map {$_ => $_} @_;

    @{$self->{+_LISTENERS}} = grep { !$subs{$_->{code}} } @{$self->{+_LISTENERS}};
}

sub munge {
    my $self = shift;
    my ($sub, %params) = @_;

    carp "use of mungers is deprecated, look at filters instead. mungers will be removed in the near future.";

    carp "Useless addition of a munger in a child process or thread!"
        if $$ != $self->{+PID} || get_tid() != $self->{+TID};

    croak "munge only takes coderefs for arguments, got '$sub'"
        unless ref $sub && ref $sub eq 'CODE';

    push @{$self->{+_MUNGERS}} => { %params, code => $sub };

    $sub; # Intentional Return
}

sub unmunge {
    my $self = shift;
    carp "Useless removal of a munger in a child process or thread!"
        if $$ != $self->{+PID} || get_tid() != $self->{+TID};
    my %subs = map {$_ => $_} @_;
    @{$self->{+_MUNGERS}} = grep { !$subs{$_->{code}} } @{$self->{+_MUNGERS}};
}

sub filter {
    my $self = shift;
    my ($sub, %params) = @_;

    carp "Useless addition of a filter in a child process or thread!"
        if $$ != $self->{+PID} || get_tid() != $self->{+TID};

    croak "filter only takes coderefs for arguments, got '$sub'"
        unless ref $sub && ref $sub eq 'CODE';

    push @{$self->{+_FILTERS}} => { %params, code => $sub };

    $sub; # Intentional Return
}

sub unfilter {
    my $self = shift;
    carp "Useless removal of a filter in a child process or thread!"
        if $$ != $self->{+PID} || get_tid() != $self->{+TID};
    my %subs = map {$_ => $_} @_;
    @{$self->{+_FILTERS}} = grep { !$subs{$_->{code}} } @{$self->{+_FILTERS}};
}

sub follow_up {
    my $self = shift;
    my ($sub) = @_;

    carp "Useless addition of a follow-up in a child process or thread!"
        if $$ != $self->{+PID} || get_tid() != $self->{+TID};

    croak "follow_up only takes coderefs for arguments, got '$sub'"
        unless ref $sub && ref $sub eq 'CODE';

    push @{$self->{+_FOLLOW_UPS}} => $sub;
}

sub add_context_init {
    my $self = shift;
    my ($sub) = @_;

    croak "add_context_init only takes coderefs for arguments, got '$sub'"
        unless ref $sub && ref $sub eq 'CODE';

    push @{$self->{+_CONTEXT_INIT}} => $sub;

    $sub; # Intentional return.
}

sub remove_context_init {
    my $self = shift;
    my %subs = map {$_ => $_} @_;
    @{$self->{+_CONTEXT_INIT}} = grep { !$subs{$_} == $_ } @{$self->{+_CONTEXT_INIT}};
}

sub add_context_release {
    my $self = shift;
    my ($sub) = @_;

    croak "add_context_release only takes coderefs for arguments, got '$sub'"
        unless ref $sub && ref $sub eq 'CODE';

    push @{$self->{+_CONTEXT_RELEASE}} => $sub;

    $sub; # Intentional return.
}

sub remove_context_release {
    my $self = shift;
    my %subs = map {$_ => $_} @_;
    @{$self->{+_CONTEXT_RELEASE}} = grep { !$subs{$_} == $_ } @{$self->{+_CONTEXT_RELEASE}};
}

sub send {
    my $self = shift;
    my ($e) = @_;

    my $ipc = $self->{+IPC} || return $self->process($e);

    if($e->global) {
        $ipc->send('GLOBAL', $e);
        return $self->process($e);
    }

    return $ipc->send($self->{+HID}, $e)
        if $$ != $self->{+PID} || get_tid() != $self->{+TID};

    $self->process($e);
}

sub process {
    my $self = shift;
    my ($e) = @_;

    if ($self->{+_MUNGERS}) {
        for (@{$self->{+_MUNGERS}}) {
            $_->{code}->($self, $e);
            return unless $e;
        }
    }

    if ($self->{+_FILTERS}) {
        for (@{$self->{+_FILTERS}}) {
            $e = $_->{code}->($self, $e);
            return unless $e;
        }
    }

    my $state = $self->{+STATE};
    $e->update_state($state);
    my $count = $state->count;

    $self->{+_FORMATTER}->write($e, $count) if $self->{+_FORMATTER};

    if ($self->{+_LISTENERS}) {
        $_->{code}->($self, $e, $count) for @{$self->{+_LISTENERS}};
    }

    my $code = $e->terminate;
    $self->terminate($code, $e) if defined $code;

    return $e;
}

sub terminate {
    my $self = shift;
    my ($code) = @_;
    exit($code);
}

sub cull {
    my $self = shift;

    my $ipc = $self->{+IPC} || return;
    return if $self->{+PID} != $$ || $self->{+TID} != get_tid();

    # No need to do IPC checks on culled events
    $self->process($_) for $ipc->cull($self->{+HID});
}

sub finalize {
    my $self = shift;
    my ($dbg, $do_plan) = @_;

    $self->cull();
    my $state = $self->{+STATE};

    my $plan   = $state->plan;
    my $count  = $state->count;
    my $failed = $state->failed;

    # return if NOTHING was done.
    return unless $do_plan || defined($plan) || $count || $failed;

    unless ($state->ended) {
        if ($self->{+_FOLLOW_UPS}) {
            $_->($dbg, $self) for reverse @{$self->{+_FOLLOW_UPS}};
        }

        # These need to be refreshed now
        $plan   = $state->plan;
        $count  = $state->count;
        $failed = $state->failed;

        if (($plan && $plan eq 'NO PLAN') || ($do_plan && !$plan)) {
            $self->send(
                Test::Stream::Event::Plan->new(
                    debug => $dbg,
                    max => $count,
                )
            );
            $plan = $state->plan;
        }
    }

    $state->finish($dbg->frame);
}

sub DESTROY {
    my $self = shift;
    my $ipc = $self->{+IPC} || return;
    return unless $$ == $self->{+PID};
    return unless get_tid() == $self->{+TID};

    local $?;
    $ipc->drop_hub($self->{+HID});
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Hub - The conduit through which all events flow.

=head1 SYNOPSIS

    use Test::Stream::Hub;

    my $hub = Test::Stream::Hub->new();
    $hub->send(...);

=head1 DESCRIPTION

The hub is the place where all events get processed and handed off to the
formatter. The hub also tracks test state, and provides everal hooks into the
event pipeline.

=head1 COMMON TASKS

=head2 SENDING EVENTS

    $hub->send($event)

The C<send()> method is used to issue an event to the hub. This method will
handle thread/fork sync, mungers, listeners, TAP output, etc.

=head2 ALTERING OR REMOVING EVENTS

    $hub->filter(sub {
        my ($hub, $event) = @_;

        my $action = get_action($event);

        # No action should be taken
        return $event if $action eq 'none';

        # You want your filter to remove the event
        return undef if $action eq 'delete';

        if ($action eq 'do_it') {
            my $new_event = copy_event($event);
            ... Change your copy of the event ...
            return $new_event;
        }

        die "Should not happen";
    });

By default filters are not inherited by child hubs, that means if you start a
subtest, the subtest will not inherit the filter. You can change this behavior
with the C<inherit> parameter:

    $hub->filter(sub { ... }, inherit => 1);

=head2 LISTENING FOR EVENTS

    $hub->listen(sub {
        my ($hub, $event, $number) = @_;

        ... do whatever you want with the event ...

        # return is ignored
    });

By default listeners are not inherited by child hubs, that means if you start a
subtest, the subtest will not inherit the listener. You can change this behavior
with the C<inherit> parameter:

    $hub->listen(sub { ... }, inherit => 1);


=head2 POST-TEST BEHAVIORS

    $hub->follow_up(sub {
        my ($dbg, $hub) = @_;

        ... do whatever you need to ...

        # Return is ignored
    });

follow_up subs are called only once, ether when done_testing is called, or in
an END block.

=head2 SETTING THE FORMATTER

By default an instance of L<Test::Stream::Formatter::TAP> is created and used.

    my $old = $hub->format(My::Formatter->new);

Setting the formatter will REPLACE any existing formatter. You may set the
formatter to undef to prevent output. The old formatter will be returned if one
was already set. Only 1 formatter is allowed at a time.

=head1 METHODS

=over 4

=item $hub->send($event)

This is where all events enter the hub for processing.

=item $hub->process($event)

This is called by send after it does any IPC handling. You can use this to
bypass the IPC process, but in general you should avoid using this.

=item $val = $hub->meta($key)

=item $val = $hub->meta($key, $default)

This method is made available to allow third party plugins to associate
meta-data with a hub. It is recommended that all third party plugins use their
module namespace as their meta-data key.

This method always returns the value for the key. If there is no value it will
be initialized to C<$default>, in which case C<$default> is also returned.

Recommended usage:

    my $meta = $hub->meta(__PACKAGE__, {});
    unless ($meta->{foo}) {
        $meta->{foo} = 1;
        $meta->{bar} = 2;
    }

=item $val = $hub->delete_meta($key)

This will delete all data in the specified metadata key.

=item $val = $hub->get_meta($key)

This method will retrieve the value of any meta-data key specified.

=item $string = $hub->get_todo()

Get the current TODO reason. This will be undef if there is no active todo.
Please note that 0 and C<''> (empty string) count as active todo.

=item $ref = $hub->set_todo($reason)

This will set the todo message. The todo will remain in effect until you let go
of the reference returned by this method.

    {
        my $todo = $hub->set_todo("Broken");

        # These ok events will be TODO
        ok($foo->doit, "do it!");
        ok($foo->doit, "do it again!");

        # The todo setting goes away at the end of this scope.
    }

    # This result will not be TODO.
    ok(1, "pass");

You can also do it without the indentation:

    my $todo = $hub->set_todo("Broken");

    # These ok events will be TODO
    ok($foo->doit, "do it!");
    ok($foo->doit, "do it again!");

    # Unset the todo
    $todo = undef;

    # This result will not be TODO.
    ok(1, "pass");

This method can be called while TODO is already in effect and it will work in a
sane way:

    {
        my $first_todo = $hub->set_todo("Will fix soon");

        ok(0, "Not fixed"); # TODO: Will fix soon

        {
            my $second_todo = $hub->set_todo("Will fix eventually");
            ok(0, "Not fixed"); # TODO: Will fix eventually
        }

        ok(0, "Not fixed"); # TODO: Will fix soon
    }

This also works if you free todo's out of order. The most recently set todo
that is still active will always be used as the todo.

=item $old = $hub->format($formatter)

Replace the existing formatter instance with a new one. Formatters must be
objects that implement a C<< $formatter->write($event) >> method.

=item $sub = $hub->munge(sub { ... })

=item $sub = $hub->munge(sub { ... }, inherit => 1)

B<*** DEPRECATED ***> This will be removed in the near future.

This adds your codeblock as a callback. Every event that hits this hub will be
given to your munger BEFORE it is sent to the formatter. You can make any
modifications you want to the event object.

    $hub->munge(sub {
        my ($hub, $event) = @_;

        ... Modify the event object ...

        # return is ignored.
    });

You can also completely remove the event from the stream:

    $hub->munge(sub {
        my ($hub, $event) = @_;
        return unless ...;

        $_[1] = undef;
    });

Normally mungers are not inherited by child hubs such as subtests. You can add
the C<< inherit => 1 >> parameter to allow a munger to be inherited.

=item $hub->unmunge($sub)

B<*** DEPRECATED ***> This will be removed in the near future.

You can use this to remove a munge callback. You must pass in the coderef
returned by the C<munge()> method.

=item $sub = $hub->listen(sub { ... })

You can use this to record all events AFTER they have been sent to the
formatter. No changes made here will be meaningful, except possibly to other
listeners.

    $hub->listen(sub {
        my ($hub, $event, $number) = @_;

        ... do whatever you want with the event ...

        # return is ignored
    });

Normally listeners are not inherited by child hubs such as subtests. You can
add the C<< inherit => 1 >> parameter to allow a listener to be inherited.

=item $hub->unlisten($sub)

You can use this to remove a listen callback. You must pass in the coderef
returned by the C<listen()> method.

=item $hub->follow_op(sub { ... })

Use this to add behaviors that are called just before the
L<Test::Stream::State> for the hub is finalized. The only argument to your
codeblock will be a L<Test::Stream::DebugInfo> instance.

    $hub->follow_up(sub {
        my ($dbg, $hub) = @_;

        ... do whatever you need to ...

        # Return is ignored
    });

follow_up subs are called only once, ether when done_testing is called, or in
an END block.

=item $sub = $hub->add_context_init(sub { ... });

This allows you to add callbacks that will trigger every time a new context is
created for the hub. The only argument to the sub will be the
L<Test::Stream::Context> instance that was created.

B<Note> Using this hook could have a huge performance impact.

The coderef you provide is returned and can be used to remove the hook later.

=item $hub->remove_context_init($sub);

This can be used to remove a context init hook.

=item $sub = $hub->add_context_release(sub { ... });

This allows you to add callbacks that will trigger every time a context for
this hub is released. The only argument to the sub will be the
L<Test::Stream::Context> instance that was released. These will run in reverse
order.

B<Note> Using this hook could have a huge performance impact.

The coderef you provide is returned and can be used to remove the hook later.

=item $hub->remove_context_release($sub);

This can be used to remove a context release hook.

=item $hub->cull()

Cull any IPC events (and process them).

=item $pid = $hub->pid()

Get the process id under which the hub was created.

=item $tid = $hub->tid()

Get the thread id under which the hub was created.

=item $hud = $hub->hid()

Get the identifier string of the hub.

=item $ipc = $hub->ipc()

Get the IPC object used by the hub.

=item $hub->set_no_ending($bool)

=item $bool = $hub->no_ending

This can be used to disable auto-ending behavior for a hub. The auto-ending
behavior is triggered by an end block and is used to cull IPC events, and
output the final plan if the plan was 'no_plan'.

=item $bool = $hub->parent_todo

This will be true if this hub is a child hub who's parent had todo set.

=back

=head1 SOURCE

The source code repository for Test::Stream can be found at
F<http://github.com/Test-More/Test-Stream/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
