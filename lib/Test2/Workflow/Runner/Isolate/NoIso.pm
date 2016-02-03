package Test2::Workflow::Runner::Isolate::NoIso;
use strict;
use warnings;

use Test2::Util qw/CAN_THREAD/;

use parent 'Test2::Workflow::Runner::Isolate';

sub can_async { 0 }

sub spawn {
    my $self = shift;
    my ($task) = @_;

    my $unit = $task->unit;

    my $ctx = $unit->context;
    $ctx->skip($unit->name, "No isolation method is available");

    $ctx->note("Cannot use fork() for isolation on this system") unless $self->no_fork || $ENV{T2_WORKFLOW_NO_FORK};

    unless ($self->no_threads || $ENV{T2_WORKFLOW_NO_THREADS}) {
        $ctx->note("Cannot use threads for isolation on this system");

        if (CAN_THREAD && eval { require threads }) {
            my $ver = threads->VERSION;
            $ctx->note("System supports threads, but threads version ($ver) is not sufficient (need: 1.34)");
        }
    }

    return 1;
}

sub wait {
    my $self = shift;
    my %params = @_;

    $self->split_check();

    my $sets = $params{sets} || $self->{+RUNNING};

    @$sets = ();
    return 1;
}

1;
