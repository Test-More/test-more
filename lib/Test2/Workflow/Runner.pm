package Test2::Workflow::Runner;
use strict;
use warnings;

use Test2::API();
use Test2::Todo();

use List::Util qw/shuffle/;
use Carp qw/confess/;

use Test2::Util::HashBase qw{
    stack no_fork no_threads max slots pid tid rand subtests
};

use overload(
    'fallback' => 1,
    '&{}' => \&run
);

sub init {
    my $self = shift;

    $self->{+STACK}    = [];
    $self->{+SUBTESTS} = [];

    $self->{+PID} = $$;
    $self->{+TID} = get_tid();

    $self->{+NO_FORK}    ||= $ENV{T2_WORKFLOW_NO_FORK}    || !CAN_REALLY_FORK();
    $self->{+NO_THREADS} ||= $ENV{T2_WORKFLOW_NO_THREADS} || !Test2::AsyncSubtest->CAN_REALLY_THREAD();

    my @max = grep {defined $_} $self->{+MAX}, $ENV{T2_WORKFLOW_ASYNC};
    my $max = @max ? min(@max) : 3;
    $self->{+MAX} = $max;
    $self->{+SLOTS} = [] if $max;

    if (my $task = delete $self->{task}) {
        $self->push_task($task);
    }
}

sub run {
    my $self = shift;

    my $stack = $self->stack;

    while (@$stack) {
        $self->cull;

        my ($state) = @$stack;
        my $task = $state->{task};

        # TODO: $self->start()?
        unless($state->{started}++) {
            if (my $skip = $task->{skip}) {
                $state->{ended}++;
                Test2::API::test2_stack->top->send(
                    Test2::Event::Skip->new(
                        trace  => $task->trace,
                        reason => $skip,
                        name   => $task->name,
                    )
                );
                pop @$stack;
                next;
            }

            $state->{todo} = Test2::Todo->new(reason => $task->todo)
                if $task->todo;

            unless ($task->flat) {
                my $st = Test2::AsyncSubtest->new(name => $task->name);
                push @{$self->{+SUBTESTS}} => $st;
                $state->{subtest} = $st;

                my $slot = $self->isolate($state);

                # if we forked/threaded then this state has ended here.
                if (defined($slot)) {
                    $state->{ended} = 1;
                    pop @$stack;
                    next;
                }

                $state->{subtest}->start();
            }
        }

        # TODO $self->end()?
        if ($state->{ended}) {
            $state->{subtest}->stop() if $state->{subtest};
            $state->{todo}->end() if $state->{todo};

            return if $state->{in_thread};
            if(my $guard = delete $state->{in_fork}) {
                $state->{subtest}->detach;
                $guard->dismiss;
                exit 0;
            }

            pop @$stack;
            next;
        }

        if ($task->isa('Test2::Workflow::Task::Action')) {
            # TODO: $task->run?
            my $ok = eval { $task->code->(); 1 };
            $task->exception($@) unless $ok;
            $state->{ended} = 1;
            next;
        }

        # TODO: self->iterate?
        if (!$state->{stage} || $state->{stage} eq 'BEFORE') {
            $state->{before} //= 0;
            if (my $add = $task->before->[$state->{before}++]) {
                if ($add->around) {
                    my $ok = eval { $add->code->($self); 1 };
                    my $err = $@;
                    my $complete = $state->{stage} eq 'AFTER';

                    unless($ok && $complete) {
                        $state->{ended} = 1;
                        $state->{stage} = 'AFTER';
                        $task->exception($ok ? "'around' task failed to continue into the workflow chain.\n" : $err);
                    }
                }
                else {
                    $self->push_task($add);
                }
            }
            else {
                $state->{stage} = 'PRIMARY';
            }
        }
        elsif ($state->{stage} eq 'PRIMARY') {
            unless (defined $state->{order}) {
                my $rand = defined($task->rand) ? $task->rand : $self->rand;
                $state->{order} = [0 .. scalar @{$task->primary}];
                @{$state->{order}} = shuffle(@{$state->{order}})
                    if $rand;
            }
            if (my $num = shift @{$state->{order}}) {
                $self->push_task($task->primary->[$num]);
            }
            else {
                $state->{stage} = 'AFTER';
            }
        }
        elsif ($state->{stage} eq 'AFTER') {
            $state->{after} //= 0;
            if (my $add = $task->after->[$state->{after}++]) {
                return if $add->around;
                $self->push_task($add);
            }
            else {
                $state->{ended} = 1;
            }
        }
    }

    $self->finish;
}

sub push_task {
    my $self = shift;
    my ($task) = @_;

    push @{$self->{+STACK}} => {
        task => $task,
    };
}

sub isolate {
    my $self = shift;
    my ($state) = @_;

    return if $state->{task}->skip;

    my $iso   = $state->{task}->iso;
    my $async = $state->{task}->async;

    # No need to isolate
    return undef unless $iso || $async;

    # Cannot isolate
    unless($self->{+MAX}) {
        # async does not NEED to be isolated
        return undef unless $iso;
    }

    # TODO: $self->wait
    # Wait for a slot, if max is set to 0 then we will not find a slot, instead
    # we use '0'.  We need to return a defined value to let the stack know that
    # the task has ended.
    my $slot = 0;
    while($self->{+MAX}) {
        $self->cull;
        for my $s (1 .. $self->{+MAX}) {
            my $st = $self->{+SLOTS}->[$s];
            next if $st && !$st->finished;
            $self->{+SLOTS}->[$s] = undef;
            $slot = $s;
            last;
        }
    }

    my $st = $state->{subtest}
        or confess "Cannot isolate a task without a subtest";

    if (!$self->no_fork) {
        my $out = $st->fork;
        if (blessed($out)) {
            $state->{in_fork} = $out;

            # drop back out to complete the task.
            return undef;
        }
        else {
            $state->{pid} = $out;
        }
    }
    elsif (!$self->no_thread) {
        $state->{in_thread} = 1;
        $state->{thread} = $st->run_thread(\&run, $self);
        delete $state->{in_thread};
    }
    else {
        $st->finish(skip => "No isolation method available");
        return 0;
    }

    if($slot) {
        $self->{+SLOTS}->[$slot] = $st;
    }
    else {
        $st->finish;
    }

    return $slot;
}

sub cull {
    my $self = shift;

    my $subtests = delete $self->{+SUBTESTS} || return;
    $self->{+SUBTESTS} = [grep { !($_->ready && ($_->finish || 1)) } @$subtests];

    return;
}

sub finish {
    my $self = shift;
    $self->cull while @{$self->{+SUBTESTS}};
}

1;

__END__



