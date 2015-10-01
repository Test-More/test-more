package Test::Stream::Workflow::Runner;
use strict;
use warnings;

use Test::Stream::Capabilities qw/CAN_FORK CAN_THREAD/;

BEGIN {
    if (CAN_FORK && $^O ne 'MSWin32') {
        *isolate = sub { 'fork_task' };
    }
    elsif (CAN_THREAD) {
        require threads;
        *isolate = sub { 'thread_task' };
    }
    else {
        *isolate = sub { undef };
    }
}

use Test::Stream::Util qw/try/;

use Test::Stream::Workflow::Task;
use Test::Stream::Sync;

sub subtests { 1 }

sub instance { shift }

sub import {
    my $class  = shift;
    my $caller = caller;

    require Test::Stream::Workflow::Meta;
    my $meta = Test::Stream::Workflow::Meta->get($caller) or return;
    $meta->set_runner($class->instance(@_));
}

my %SUPPORTED = map {$_ => 1} qw/todo skip iso isolate/;
sub verify_meta {
    my $class = shift;
    my ($unit) = @_;
    my $meta = $unit->meta or return;
    my $ctx = $unit->context;
    for my $k (keys %$meta) {
        next if $SUPPORTED{$k};
        $ctx->alert("'$k' is not a recognised meta-key");
    }
}

sub run {
    my $class = shift;
    my %params = @_;
    my $unit     = $params{unit};
    my $args     = $params{args};
    my $no_final = $params{no_final};

    $class->verify_meta($unit);

    my $task = Test::Stream::Workflow::Task->new(
        unit       => $unit,
        args       => $args,
        runner     => $class,
        no_final   => $no_final,
        no_subtest => !$class->subtests($unit),
    );

    my ($ok, $err) = try { $class->run_task($task) };
    Test::Stream::Sync->stack->top->cull();

    # Report exceptions
    unless($ok) {
        my $ctx = $unit->context;
        $ctx->ok(0, $unit->name, ["Caught Exception: $err"]);
    }

    return;
}

sub run_task {
    my $class = shift;
    my ($task) = @_;

    my $meta = $task->unit->meta;
    if($meta->{iso} || $meta->{isolate}) {
        my $meth = $class->isolate;

        if (!$meth) {
            my $unit = $task->unit;
            my $ctx = $unit->context;
            $ctx->debug->set_skip('No way to isolate task!');
            $ctx->ok(1, $unit->name);
            return;
        }

        return $class->$meth($task);
    }

    return $task->run();
}

sub fork_task {
    my $class = shift;
    my ($task) = @_;

    my $unit = $task->unit;
    my $name = $unit->name;
    my $ctx  = $unit->context;

    $ctx->throw("Cannot fork for '$name', system does not support forking")
        unless CAN_FORK;

    my $pid = fork;
    $ctx->throw("Fork failed for '$name'")
        unless defined $pid;

    if ($pid) {
        waitpid($pid, 0);
        my $ecode = $? >> 8;
        return (0, "Child process ($pid) exited $ecode") if $ecode;
        Test::Stream::Sync->stack->top->cull();
        return (1);
    }

    my ($ok, $err) = try {
        $task->run();
        Test::Stream::Sync->stack->top->cull();
        exit 0;
    };

    Test::Stream::Sync->stack->top->cull();
    $ctx->send_event('Exception', error => $err);
    exit 255;
}

sub thread_task {
    my $class = shift;
    my ($task) = @_;

    my $unit = $task->unit;
    my $name = $unit->name;
    my $ctx  = $unit->context;

    $ctx->throw("Cannot thread for '$name', system does not support threads")
        unless CAN_THREAD;

    my $t = threads->create(sub {
        my ($ok, $err) = try { $task->run() };
        Test::Stream::Sync->stack->top->cull();
        return 'good' if $ok;

        $ctx->send_event('Exception', error => $err)
    });

    $t->join;
    $ctx->send_event('Exception', error => $t->error)
        if threads->can('error') && $t->error;

    Test::Stream::Sync->stack->top->cull();
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Workflow::Runner - Simple runner for workflows.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 DESCRIPTION

This is a basic class for running workflows. This class is intended to be
subclasses for more fancy/feature rich workflows.

=head1 SYNOPSIS

=head2 SUBCLASS

    package My::Runner;
    use strict;
    use warnings;

    use parent 'Test::Stream::Workflow::Runner';

    sub instance {
        my $class = shift;
        return $class->new(@_);
    }

    sub subtest {
        my $self = shift;
        my ($unit) = @_;
        ...
        return $bool
    }

    sub verify_meta {
        my $self = shift;
        my ($unit) = @_;
        my $meta = $unit->meta || return;
        warn "the 'foo' meta attribute is not supported" if $meta->{foo};
        ...
    }

    sub run_task {
        my $self = shift;
        my ($task) = @_;
        ...
        $task->run();
        ...
    }

=head2 USE SUBCLASS

    use Test::Stream qw/-V1 Spec/;

    use My::Runner; # Sets the runner for the Spec plugin.

    ...

=head1 METHODS

=head2 CLASS METHODS

=over 4

=item $class->import()

=item $class->import(@instance_args)

The import method checks the calling class to see if it has an
L<Test::Stream::Workflow::Meta> instance, if it does then it sets the runner.
The runner that is set is the result of calling
C<< $class->instance(@instance_args) >>. The instance_args are optional.

If there is no meta instance for the calling class then import is a no-op.

=item $bool = $class->subtests($unit)

This determines if the units should be run as subtest or flat. The base class
always returns true for this. This is a hook that allows you to override the
default behavior.

=item $runner = $class->instance()

=item $runner = $class->instance(@args)

This is a hook allowing you to construct an instance of your runner. The base
class simply returns the class name as it does not need to be instansiated. If
your runner needs to maintain state then this can return a blessed instance.

=back

=head2 CLASS AND/OR OBJECT METHODS

These are made to work on the class itself, but should also work just fine on a
blessed instance if your subclass needs to be instantiated.

=over 4

=item $runner->verify_meta($unit)

This method reads the C<< $unit->meta >> hash and warns about any unrecognised
keys. Your subclass should override this if it wants to add support for any
meta-keys.

=item $runner->run(unit => $unit, args => $arg)

=item $runner->run(unit => $unit, args => $arg, no_final => $bool)

Tell the runner to run a unit with the specified args. The args are optional.
The C<no_final> arg is optional, it should be used on support units that should
not produce final results (or be a subtest of their own).

=item $runner->run_task($task)

The C<run()> method composes a unit into a C<Test::Stream::Workflow::Task>
object. This object is then handed off to C<run_task()> to be run. At its
simplest this method should run C<< $task->run() >>. The base class will simply
run the task, unless the 'iso' (or 'isolate') meta attribute is set to true, in
which case it delegates to C<fork_task()> or C<thread_task> depending on whats
available. IF no method of isolatin the task is available it will skip the
task.

=item $runner->fork_task($task)

This method will attempt to fork. In the parent process it will wait for the
child to complete, then return. In the child process the task will be run, then
the process will exit.

This is a way to run a task in isolation ensuring that no global state is
modified for future tests. This implementation does not support any parallelism
as the parent waits for the child to complete before it continues.

This method will throw an exception if the current system does not support
forking. It will throw a different exception if it attempts to fork and cannot
for any reason.

=item $runner->thread_task($task)

This method will attempt to spawn a thread. In the parent thread it will wait
for the child to complete, then return. In the child thread the task will be
run, then the thread will exit.

This is a way to run a task in isolation ensuring that no global state is
modified for future tests. This implementation does not support any parallelism
as the parent waits for the child to complete before it continues.

This method will throw an exception if the current system does not support
threading.

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

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
