package Test2::Workflow::Runner::Isolate;
use strict;
use warnings;

use Test2::IPC;

use parent 'Test2::Workflow::Runner';

use Carp         qw/croak/;
use List::Util   qw/min shuffle/;
use Time::HiRes  qw/sleep time/;
use Test2::Util  qw/CAN_REALLY_FORK CAN_THREAD try get_tid/;
use Scalar::Util qw/reftype/;

use Test2::API qw{
    test2_stack
    test2_add_callback_post_load
};

use Test2::Workflow::Task::Isolate;
use Test2::Event::Stamp;

use Test2::Util::HashBase qw{
    max tid pid running monitor no_fork no_threads
};

sub choose_subclass {
    my $class = shift;
    my %args = @_;

    my $use_class;
    if(CAN_REALLY_FORK && !$ENV{T2_WORKFLOW_NO_FORK} && !$args{no_fork}) {
        require Test2::Workflow::Runner::Isolate::Fork;
        return 'Test2::Workflow::Runner::Isolate::Fork';
    }

    if(CAN_THREAD && !$ENV{T2_WORKFLOW_NO_THREADS} && !$args{no_threads} && eval { require threads; threads->VERSION('1.34'); 1 }) {
        require Test2::Workflow::Runner::Isolate::Threads;
        return 'Test2::Workflow::Runner::Isolate::Threads';
    }

    require Test2::Workflow::Runner::Isolate::NoIso;
    return 'Test2::Workflow::Runner::Isolate::NoIso';
}

sub instance {
    my $class = shift;
    my %args = @_;

    my $self = $class->choose_subclass(%args)->new(
        %args,
        subtests => 1,
    );

    test2_add_callback_post_load( sub {
        my $hub = test2_stack->top;
        $hub->follow_up(sub { $self->wait(block => 1) });
    });

    return $self;
}

sub init {
    my $self = shift;
    $self->{+TID} = get_tid();
    $self->{+PID} = $$;
    $self->{+RUNNING} = [];
    $self->{+MONITOR} = [];

    my @max = grep {defined $_} $self->{+MAX}, $ENV{T2_WORKFLOW_ASYNC};
    my $max = @max ? min(@max) : 3;
    $self->{+MAX} = $max;
}

sub spawn    { croak "not implemented" }
sub wait_set { croak "not implemented" }

my %SUPPORTED = (
    %{__PACKAGE__->SUPER::supported_meta_keys},
    map {$_ => 1} qw/iso async/,
);
sub supported_meta_keys { \%SUPPORTED }

sub can_async {
    my $self = shift;
    return 0 unless $self->{+MAX};
    return 0 unless $self->{+TID} == get_tid();
    return 0 unless $self->{+PID} == $$;

    return 1;
}

sub split_check {
    my $self = shift;
    return if $self->{+PID} == $$ && $self->{+TID} == get_tid();

    $self->{+TID} = get_tid();
    $self->{+PID} = $$;
    $self->{+MAX} = 0;
    $self->{+RUNNING} = [];
    $self->{+MONITOR} = [];

    return;
}

sub run {
    my $self = shift;
    my %params = @_;

    $self->split_check();

    my $unit     = $params{unit};
    my $args     = $params{args};
    my $no_final = $params{no_final};
    my $iso      = $unit->meta->{iso};
    my $async    = $unit->meta->{async} && $self->can_async;

    $self->verify_meta($unit);

    if ($self->{+RAND}) {
        my $p = $unit->primary;
        @$p = shuffle @$p if ref($p) eq 'ARRAY';
    }

    my $task = Test2::Workflow::Task::Isolate->new(
        unit       => $unit,
        args       => $args,
        runner     => $self,
        no_final   => $no_final,
        no_subtest => !$self->subtests($unit),
    );

    return $self->run_task($task) unless $iso || $async;

    $self->wait(block => 0) while @{$self->{+RUNNING}} >= $self->{+MAX};

    my $ctx = $unit->context;
    $ctx->send_event('Stamp', stamp => time(), name => $unit->name, action => 'spawn');
    my $run = $self->spawn($task);
    my $set = [$run, $task];

    if ($async) {
        push @{$self->{+RUNNING}} => $set;
        if (@{$self->{+MONITOR}}) {
            my $list = $self->{+MONITOR}->[-1];
            push @$list => $set;
        }
    }
    else {
        $self->wait(sets => [$set], block => 1);
    }

    return;
}

sub run_task {
    my $self = shift;
    my ($task) = @_;

    my ($ok, $err) = try {
        my $unit = $task->unit;
        my $ctx = $unit->context;

        $ctx->send_event('Stamp', stamp => time(), name => $unit->name, action => 'start');

        $task->run();

        $ctx->send_event('Stamp', stamp => time(), name => $unit->name, action => 'finish');
    };
    test2_stack->top->cull();

    # Report exceptions
    unless($ok) {
        my $ctx = $task->unit->context;
        $ctx->send_event('Exception', 'error' => $err);
    }

    return $ok;
}

sub wait {
    my $self = shift;
    my %params = @_;

    $self->split_check();

    my $sets  = $params{sets} || $self->{+RUNNING};
    my $block = $params{block};

    while (@$sets) {
        for my $set (@$sets) {
            my ($run, $task, $done) = @$set;
            local ($?, $!);

            unless ($done) {
                $done = $self->wait_set(@$set);
                test2_stack->top->cull();

                # A child can be removed form lists multiple times, but it only
                # waited on once.
                if ($done) {
                    my $unit = $task->unit;
                    my $ctx = $unit->context;
                    $ctx->send_event('Stamp', stamp => time(), name => $unit->name, action => 'reap');
                }
            }

            if ($done) {
                push @$set => $done;
                @$sets = grep {$_ != $set} @$sets if $done;
            }
        }

        # Only loop once in non-blocking mode
        last unless $block;
        sleep(0.1) if @$sets;
    }
}

sub DESTROY {
    my $self = shift;
    $self->wait;
}

1;
