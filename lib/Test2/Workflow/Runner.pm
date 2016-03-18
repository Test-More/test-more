package Test2::Workflow::Runner;
use strict;
use warnings;

use Test2::API();
use Test2::Todo();
use Test2::AsyncSubtest();

use Test2::Util qw/get_tid CAN_REALLY_FORK/;

use Scalar::Util qw/blessed/;
use Time::HiRes qw/sleep/;
use List::Util qw/shuffle/;
use Carp qw/confess/;

use Test2::Util::HashBase qw{
    stack no_fork no_threads max slots pid tid rand subtests
};

use overload(
    'fallback' => 1,
    '&{}' => sub {
        my $self = shift;

        sub {
            @_ = ($self);
            goto &run;
        }
    },
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

sub is_local {
    my $self = shift;
    return 0 unless $self->{+PID} == $$;
    return 0 unless $self->{+TID} == get_tid();
    return 1;
}

sub run {
    my $self = shift;

    my $stack = $self->stack;

    my $c = 0;
    while (@$stack) {
        $self->cull;

        my $state = $stack->[-1];
        my $task  = $state->{task};

        unless($state->{started}++) {
            if (my $skip = $task->skip) {
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
                $state->{subtest} = $st;

                my $slot = $self->isolate($state);

                # if we forked/threaded then this state has ended here.
                if (defined($slot)) {
                    push @{$self->{+SUBTESTS}} => [$st, $task] unless $st->finished;
                    $state->{subtest} = undef;
                    $state->{ended} = 1;
                }
            }
        }

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

        if($state->{subtest} && !$state->{subtest_started}++) {
            push @{$self->{+SUBTESTS}} => [$state->{subtest}, $task];
            $state->{subtest}->start();
        }

        if ($task->isa('Test2::Workflow::Task::Action')) {
            my $ok = eval { $task->code->(); 1 };
            $task->exception($@) unless $ok;
            $state->{ended} = 1;
            next;
        }

        if (!$state->{stage} || $state->{stage} eq 'BEFORE') {
            $state->{before} //= 0;
            if (my $add = $task->before->[$state->{before}++]) {
                if ($add->around) {
                    my $ok = eval { $add->code->($self); 1 };
                    my $err = $@;
                    my $complete = $state->{stage} && $state->{stage} eq 'AFTER';

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
                $state->{stage} = 'VARIANT';
            }
        }
        elsif ($state->{stage} eq 'VARIANT') {
            if (my $v = $task->variant) {
                $self->push_task($v);
            }
            $state->{stage} = 'PRIMARY';
        }
        elsif ($state->{stage} eq 'PRIMARY') {
            unless (defined $state->{order}) {
                my $rand = defined($task->rand) ? $task->rand : $self->rand;
                $state->{order} = [0 .. scalar(@{$task->primary}) - 1];
                @{$state->{order}} = shuffle(@{$state->{order}})
                    if $rand;
            }
            my $num = shift @{$state->{order}};
            if (defined $num) {
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
    confess "WTF?" unless $task;

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

    # Wait for a slot, if max is set to 0 then we will not find a slot, instead
    # we use '0'.  We need to return a defined value to let the stack know that
    # the task has ended.
    my $slot = 0;
    while($self->{+MAX} && $self->is_local) {
        $self->cull;
        for my $s (1 .. $self->{+MAX}) {
            my $st = $self->{+SLOTS}->[$s];
            next if $st && !$st->finished;
            $self->{+SLOTS}->[$s] = undef;
            $slot = $s;
            last;
        }
        last if $slot;
        sleep(0.02);
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
    elsif (!$self->no_threads) {
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
    my @new;

    for my $set (reverse @$subtests) {
        my ($st, $task) = @$set;
        next if $st->finished;
        if (!$st->active && $st->ready) {
            $st->finish(todo => $task->todo);
            next;
        }

        unshift @new => $set;
    }

    $self->{+SUBTESTS} = \@new;

    return;
}

sub finish {
    my $self = shift;
    while(@{$self->{+SUBTESTS}}) {
        $self->cull;
        sleep(0.02) if @{$self->{+SUBTESTS}};
    }
}

1;

__END__



