package Test2::Workflow::Task::Isolate;
use strict;
use warnings;

use Carp        qw/confess/;
use Test2::API qw/test2_stack/;

use parent 'Test2::Workflow::Task';

sub _run_primary {
    my $self = shift;

    my $hub = $self->intercept;

    my $runner = $self->runner;
    my $monitor = [];
    push @{$runner->monitor} => $monitor;

    my $ok = eval { $self->_really_run_primary(); 1 };
    my $err = $@;

    unless (@{$runner->monitor} && $runner->monitor->[-1] == $monitor) {
        my $error = "Internal error: Monitor stack mismatch!";
        if ($err) {
            chomp($err);
            $error .= " (After catching $err)";
            confess $error;
        }
    }

    pop @{$runner->monitor};

    $runner->wait(sets => $monitor, block => 1)
        if @$monitor;

    test2_stack->pop($hub);

    die $err unless $ok;

    return;
}

1;
