package Test::Stream::Workflow::Task;
use strict;
use warnings;

use Carp qw/croak/;
use Scalar::Util qw/reftype/;
use Test::Stream::Sync();
use Test::Stream::Util qw/CAN_SET_SUB_NAME set_sub_name update_mask/;

use overload(
    'fallback' => 1,
    '&{}' => sub {
        my $self = shift;
        my @caller = caller(0);
        update_mask($caller[1], $caller[2], '*', {restart => 1, stop => 1, 3 => 'CONTINUE'});
        my $out = sub { $self->iterate(@_) };
        set_sub_name(__PACKAGE__ . '::iterator', $out)
            if CAN_SET_SUB_NAME;
        return $out;
    },
);

use Test::Stream::Workflow qw/push_workflow_vars pop_workflow_vars/;
use Test::Stream::Plugin::Subtest qw/subtest_buffered/;
use Test::Stream::Util qw/try set_sub_name CAN_SET_SUB_NAME/;

use Test::Stream::HashBase(
    accessors => [
        qw{
            unit args runner
            no_final no_subtest
            stage
            _buildup_idx _teardown_idx
            exception
            failed events pending
        }
    ]
);

sub STAGE_BUILDUP()  { 0 }
sub STAGE_PRIMARY()  { 1 }
sub STAGE_TEARDOWN() { 2 }
sub STAGE_COMPLETE() { 3 }

sub init {
    my $self = shift;

    croak "Attribute 'unit' is required"
        unless $self->{+UNIT};

    $self->{+ARGS} ||= [];

    $self->reset;
}

sub finished {
    my $self = shift;
    return 1 if $self->{+EXCEPTION};
    return 1 if $self->{+STAGE} >= STAGE_COMPLETE();

    return 0;
}

sub subtest {
    my $self = shift;
    return 0 if $self->{+NO_FINAL};
    return 0 if $self->{+NO_SUBTEST};
    return 1;
}

sub reset {
    my $self = shift;

    $self->{+STAGE}         = STAGE_BUILDUP();
    $self->{+_BUILDUP_IDX}  = 0;
    $self->{+_TEARDOWN_IDX} = 0;
    $self->{+FAILED}        = 0;
    $self->{+EVENTS}        = 0;
    $self->{+PENDING}       = 0;
    $self->{+EXCEPTION}     = undef;
}

sub _have_primary {
    my $self = shift;

    my $primary = $self->{+UNIT}->primary;

    # Make sure we have primary, and that it is a ref
    return 0 unless $primary;
    return 0 unless ref $primary;

    # code ref is fine
    my $type = reftype($primary);
    return 1 if $type eq 'CODE';

    # array ref is fine if it is populated
    return 0 unless $type eq 'ARRAY';
    return @$primary;
}

sub should_run {
    my $self = shift;
    return 1 unless defined $ENV{TS_WORKFLOW};
    return 1 if $self->{+NO_FINAL};
    return 1 if $self->{+UNIT}->contains($ENV{TS_WORKFLOW});
    return 0;
}

sub run {
    my $self = shift;

    return if $self->finished;
    return unless $self->should_run;

    my $unit = $self->{+UNIT};
    my $ctx = $unit->context;
    my $meta = $unit->meta;

    my $skip;
    $skip = $meta->{skip} if $meta && defined $meta->{skip};
    $skip ||= $ctx->debug->_skip; # Private accessor for deprecated thing, just until it goes away

    # Skip?
    if ($skip) {
        $self->{+STAGE} = STAGE_COMPLETE();
        $ctx->skip($unit->name, $skip);
        return;
    }

    # Make sure we have something to do!
    unless ($self->_have_primary) {
        return if $self->{+UNIT}->is_root;
        $self->{+STAGE} = STAGE_COMPLETE();
        $ctx->ok(0, $self->{+UNIT}->name, ['No primary actions defined! Nothing to do!']);
        return;
    }

    my $vars;
    $vars = push_workflow_vars({}) unless $self->{+NO_FINAL};

    if ($self->subtest) {
        $ctx->do_in_context(
            \&subtest_buffered,
            $self->{+UNIT}->name,
            sub {
                $self->iterate();
                $ctx->ok(0, $unit->name, ["No events were generated"])
                    unless $self->{+EVENTS};
            }
        );
    }
    else {
        $self->iterate();

        $ctx->ok(0, $unit->name, ["No events were generated"])
            unless $self->{+EVENTS} || $self->{+NO_FINAL};

        $ctx->ok(!$self->{+FAILED}, $unit->name)
            if $self->{+FAILED} || !$self->{+NO_FINAL};
    }

    pop_workflow_vars($vars) if $vars;

    # In case something is holding a reference to vars itself.
    %$vars = ();
    $vars = undef;

    return;
}

sub iterate {
    my $self = shift;

    $self->{+PENDING}-- if $self->{+PENDING};

    return if $self->finished;

    my ($ok, $err) = try {
        $self->_run_buildups  if $self->{+STAGE} == STAGE_BUILDUP();
        $self->_run_primaries if $self->{+STAGE} == STAGE_PRIMARY();
        $self->_run_teardowns if $self->{+STAGE} == STAGE_TEARDOWN();
    };

    unless ($ok) {
        $self->{+FAILED}++;
        $self->{+EXCEPTION} = $err;
        $self->unit->context->send_event('Exception', error => $err);
    }

    return;
}

sub _run_buildups {
    my $self = shift;

    my $buildups = $self->{+UNIT}->buildup;

    # No Buildups
    unless ($buildups) {
        $self->{+STAGE} = STAGE_PRIMARY() if $self->{+STAGE} == STAGE_BUILDUP();
        return;
    }

    while ($self->{+_BUILDUP_IDX} < @$buildups) {
        my $bunit = $buildups->[$self->{+_BUILDUP_IDX}++];
        if ($bunit->wrap) {
            $self->{+PENDING}++;
            $self->runner->run(unit => $bunit, no_final => 1, args => [$self]);
            if ($self->{+PENDING}) {
                $self->{+PENDING}--;
                my $ctx = $bunit->context;
                my $trace = $ctx->debug->trace;
                $ctx->ok(0, $bunit->name, ["Inner sub was never called $trace"]);
            }
        }
        else {
            $self->runner->run(unit => $bunit, no_final => 1, args => $self->{+ARGS});
        }
    }

    $self->{+STAGE} = STAGE_PRIMARY() if $self->{+STAGE} == STAGE_BUILDUP();
}

sub _listener {
    my $self = shift;

    return sub {
        my ($hub, $e) = @_;
        $self->{+EVENTS}++;
        $self->{+FAILED}++ if $e->causes_fail;
    } unless $self->{+NO_FINAL};

    my $ctx = $self->{+UNIT}->context;
    my $trace = $ctx->debug->trace;
    $trace = "wrapped $trace" if $self->{+UNIT}->wrap;

    return sub {
        my ($hub, $e) = @_;
        $self->{+EVENTS}++;
        return unless $e->causes_fail;
        $self->{+FAILED}++;
        return unless $e->can('diag');
        $e->set_diag([]) unless $e->diag;
        push @{$e->diag} => $trace;
    };
}

sub _run_primary {
    my $self = shift;
    my $unit = $self->{+UNIT};
    my $primary = $unit->primary;

    my $hub = Test::Stream::Sync->stack->top;
    my $l = $hub->listen($self->_listener) if $hub->is_local;

    if(reftype($primary) eq 'ARRAY') {
        $self->runner->run(unit => $_, args => $self->{+ARGS}) for @$primary
    }
    else {
        BEGIN { update_mask(__FILE__, __LINE__ + 1, '*', {stop => 1, hide => 1}) }
        $primary->(@{$self->{+ARGS}});
    }

    $hub->unlisten($l) if $l;
}

sub _run_primaries {
    my $self = shift;

    # Make sure this does not run again
    $self->{+STAGE} = STAGE_TEARDOWN() if $self->{+STAGE} < STAGE_TEARDOWN();

    my $modifiers = $self->{+UNIT}->modify || return $self->_run_primary();

    for my $mod (@$modifiers) {
        my $primary = sub {
            $mod->primary->(@{$self->{+ARGS}});
            $self->_run_primary();
        };

        my $name = $mod->name;
        set_sub_name($name, $primary) if CAN_SET_SUB_NAME;

        my $temp = Test::Stream::Workflow::Unit->new(
            %$mod,
            primary => $primary,
        );
        $self->runner->run(unit => $temp, args => $self->{+ARGS});
    }
}

sub _run_teardowns {
    my $self = shift;

    my $teardowns = $self->{+UNIT}->teardown;
    unless ($teardowns) {
        $self->{+STAGE} = STAGE_COMPLETE();
        return;
    }

    while($self->{+_TEARDOWN_IDX} < @$teardowns) {
        my $tunit = $teardowns->[$self->{+_TEARDOWN_IDX}++];
        # Popping a wrap
        return if $tunit->wrap;

        $self->runner->run(unit => $tunit, no_final => 1, args => $self->{+ARGS});
    }

    $self->{+STAGE} = STAGE_COMPLETE();
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Workflow::Task - Compiled form of a unit.

=head1 EXPERIMENTAL CODE WARNING

C<This module is still EXPERIMENTAL>. Test-Stream is now stable, but this
particular module is still experimental. You are still free to use this module,
but you have been warned that it may change in backwords incompatible ways.
This message will be removed from this modules POD once it is considered
stable.

=head1 DESCRIPTION

This object is a temporary object created by a runner to process
L<Test::Stream::Workflow::Unit> objects.

=head1 SYNOPSIS

You rarely encounter a task object, they are mainyl used under the hood. When
you do get one you usually just want to call C<iterate()> on it. This can be
done by treating it as a coderef.

    $task->();

Or direcectly:

    $task->iterate();

=head1 METHODS

=over 4

=item $task->run()

Run the task, this should only every be done by a runner.

=item $task->iterate()

Sometimes tasks are recursive. This method is how they resume running in a
recursive structure.

=item $task->reset()

Reset the task. This is rarely needed.

=item $ar = $task->args()

Get the args that will be passed to the primary actions.

=item $bool = $task->finished()

Check if the task has finished running.

=item $bool = $task->no_final()

True if the task is not required to generate events.

=item $bool = $task->should_run()

True if there is still work to be done.

=item $bool = $task->subtest()

True if the task should produce a subtest.

=item $int = $task->events()

Number of events produced by the primary actions.

=item $int = $task->failed()

Number of failures produced inside the primary actions.

=item $int = $task->pending()

How many pending iterations remain.

=item $int = $task->stage()

What stage the task is in.

=item $msg = $task->exception()

If an exception has occured the message will be stored here.

=item $unit = $task->unit()

Get the unit the task wraps.

=item $runner = $task->runner()

Get the runner instance and/or class.

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
