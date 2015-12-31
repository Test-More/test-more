package Test2::API;
use strict;
use warnings;

use Test2::API::Instance();
use Test2::API::Context();
use Test2::Util::Trace();

use Test2::Hub::Subtest();
use Test2::Hub::Interceptor();
use Test2::Hub::Interceptor::Terminator();

use Carp qw/croak confess longmess/;
use Scalar::Util qw/weaken blessed/;
use Test2::Util qw/get_tid/;

our @EXPORT_OK = qw{
    context release
    intercept
    run_subtest

    test2_init_done
    test2_load_done

    test2_pid
    test2_tid
    test2_stack
    test2_no_wait

    test2_add_callback_context_init
    test2_add_callback_context_release
    test2_add_callback_exit
    test2_add_callback_post_load

    test2_ipc
    test2_ipc_drivers
    test2_ipc_add_driver
    test2_ipc_polling
    test2_ipc_disable_polling
    test2_ipc_enable_polling

    test2_formatter
    test2_formatters
    test2_formatter_add
    test2_formatter_set
};
use base 'Exporter';

my $INST     = Test2::API::Instance::_internal_use_only_private_instance();
my $STACK    = $INST->stack;
my $CONTEXTS = $INST->contexts;
my $INIT_CBS = $INST->context_init_callbacks;

# Set the exit status
END { $INST->set_exit() }

sub test2_init_done { $INST->finalized }
sub test2_load_done { $INST->loaded }

sub test2_pid     { $INST->pid }
sub test2_tid     { $INST->tid }
sub test2_stack   { $INST->stack }
sub test2_no_wait {
    $INST->set_no_wait(@_) if @_;
    $INST->no_wait;
}

sub test2_add_callback_context_init    { $INST->add_context_init_callback(@_) }
sub test2_add_callback_context_release { $INST->add_context_release_callback(@_) }
sub test2_add_callback_post_load       { $INST->add_post_load_callback(@_) }
sub test2_add_callback_exit            { $INST->add_exit_callback(@_) }

sub test2_ipc                 { $INST->ipc }
sub test2_ipc_add_driver      { $INST->add_ipc_driver(@_) }
sub test2_ipc_drivers         { @{$INST->ipc_drivers} }
sub test2_ipc_polling         { $INST->ipc_polling }
sub test2_ipc_enable_polling  { $INST->enable_ipc_polling }
sub test2_ipc_disable_polling { $INST->disable_ipc_polling }

sub test2_formatter     { $INST->formatter }
sub test2_formatters    { @{$INST->formatters} }
sub test2_formatter_add { $INST->add_formatter(@_) }
sub test2_formatter_set {
    my ($formater) = @_;
    croak "No formatter specified" unless $formater;
    croak "Global Formatter already set" if $INST->formatter_set;
    $INST->set_formatter($formater);
}

sub context {
    my %params = (level => 0, wrapped => 0, @_);

    # If something is getting a context then the sync system needs to be
    # considered loaded...
    $INST->load unless $INST->{loaded};

    croak "context() called, but return value is ignored"
        unless defined wantarray;

    my $stack   = $params{stack} || $STACK;
    my $hub     = $params{hub}   || @$stack ? $stack->[-1] : $stack->top;
    my $hid     = $hub->{hid};
    my $current = $CONTEXTS->{$hid};

    my $level = 1 + $params{level};
    my ($pkg, $file, $line, $sub) = caller($level);
    unless ($pkg) {
        confess "Could not find context at depth $level" unless $params{fudge};
        ($pkg, $file, $line, $sub) = caller(--$level) while ($level >= 0 && !$pkg);
    }

    my $depth = $level;
    $depth++ while caller($depth + 1) && (!$current || $depth <= $current->{_depth} + $params{wrapped});
    $depth -= $params{wrapped};

    if ($current && $params{on_release} && $current->{_depth} < $depth) {
        $current->{_on_release} ||= [];
        push @{$current->{_on_release}} => $params{on_release};
    }

    return $current if $current && $current->{_depth} < $depth;

    # Handle error condition of bad level
    _depth_error($current, [$pkg, $file, $line, $sub, $depth])
        if $current;

    # Directly bless the object here, calling new is a noticable performance
    # hit with how often this needs to be called.
    my $trace = bless(
        {
            frame => [$pkg, $file, $line, $sub],
            pid   => $$,
            tid   => get_tid(),
        },
        'Test2::Util::Trace'
    );

    # Directly bless the object here, calling new is a noticable performance
    # hit with how often this needs to be called.
    $current = bless(
        {
            stack  => $stack,
            hub    => $hub,
            trace  => $trace,
            _depth => $depth,
            _err   => $@,
            $params{on_release} ? (_on_release => [$params{on_release}]) : (),
        },
        'Test2::API::Context'
    );

    weaken($CONTEXTS->{$hid} = $current);

    $_->($current) for @$INIT_CBS;

    if (my $hcbk = $hub->{_context_init}) {
        $_->($current) for @$hcbk;
    }

    $params{on_init}->($current) if $params{on_init};

    return $current;
}

sub _depth_error {
    my $ctx = shift;
    my ($details) = @_;
    my ($pkg, $file, $line, $sub, $depth) = @$details;

    my $oldframe = $ctx->{trace}->frame;
    my $olddepth = $ctx->{_depth};

    my $mess = longmess();

    warn <<"    EOT";
context() was called to retrieve an existing context, however the existing
context was created in a stack frame at the same, or deeper level. This usually
means that a tool failed to release the context when it was finished.

Old context details:
   File: $oldframe->[1]
   Line: $oldframe->[2]
   Tool: $oldframe->[3]
  Depth: $olddepth

New context details:
   File: $file
   Line: $line
   Tool: $sub
  Depth: $depth

Trace: $mess

Removing the old context and creating a new one...
    EOT

    my $hid = $ctx->{hub}->hid;
    delete $CONTEXTS->{$hid};
    $ctx->release;
}

sub release($;$) {
    $_[0]->release;
    return $_[1];
}

sub intercept(&) {
    my $code = shift;

    my $ctx = context();

    my $ipc;
    if (my $global_ipc = test2_ipc()) {
        my $driver = blessed($global_ipc);
        $ipc = $driver->new;
    }

    my $hub = Test2::Hub::Interceptor->new(
        ipc => $ipc,
        no_ending => 1,
    );

    my @events;
    $hub->listen(sub { push @events => $_[1] });

    $ctx->stack->top; # Make sure there is a top hub before we begin.
    $ctx->stack->push($hub);

    # Do not use 'try' cause it localizes __DIE__, and does not preserve $@
    # or $!
    my ($ok, $err);
    {
        local $@ = $@;
        local $! = int($!);
        $ok = eval { $code->(hub => $hub, context => $ctx->snapshot); 1 };
        $err = $@;
    }

    $hub->cull;
    $ctx->stack->pop($hub);

    my $trace = $ctx->trace;
    $ctx->release;

    die $err unless $ok
        || (blessed($err) && $err->isa('Test2::Hub::Interceptor::Terminator'));

    $hub->finalize($trace, 1)
        if $ok
        && !$hub->no_ending
        && !$hub->ended;

    return \@events;
}

sub run_subtest {
    my ($name, $code, $buffered, @args) = @_;

    my $ctx = context();

    $ctx->note($name) unless $buffered;

    my $parent = $ctx->hub;

    my $stack = $ctx->stack || $STACK;
    my $hub = $stack->new_hub(
        class => 'Test2::Hub::Subtest',
    );

    my @events;
    $hub->set_nested( $parent->isa('Test2::Hub::Subtest') ? $parent->nested + 1 : 1 );
    $hub->listen(sub { push @events => $_[1] });
    $hub->format(undef) if $buffered;

    my $no_diag = defined($parent->get_todo) || $parent->parent_todo;
    $hub->set_parent_todo($no_diag) if $no_diag;

    my ($ok, $err, $finished);
    T2_SUBTEST_WRAPPER: {
        # Do not use 'try' cause it localizes __DIE__, and does not preserve $@
        # or $!
        local $@ = $@;
        local $! = int($!);
        $ok = eval { $code->(@args); 1 };
        $err = $@;

        # They might have done 'BEGIN { skip_all => "whatever" }'
        if (!$ok && $err =~ m/Label not found for "last T2_SUBTEST_WRAPPER"/) {
            $ok  = undef;
            $err = undef;
        }
        else {
            $finished = 1;
        }
    }
    $stack->pop($hub);

    my $trace = $ctx->trace;

    if (!$finished) {
        if(my $bailed = $hub->bailed_out) {
            $ctx->bail($bailed->reason);
        }
        my $code = $hub->exit_code;
        $ok = !$code;
        $err = "Subtest ended with exit code $code" if $code;
    }

    $hub->finalize($trace, 1)
        if $ok
        && !$hub->no_ending
        && !$hub->ended;

    my $pass = $ok && $hub->is_passing;
    my $e = $ctx->build_event(
        'Subtest',
        pass => $pass,
        name => $name,
        buffered  => $buffered,
        subevents => \@events,
    );

    my $plan_ok = $hub->check_plan;

    $e->set_diag([
        $e->default_diag,
        $ok ? () : ("Caught exception in subtest: $err"),
        $plan_ok
            ? ()
            : defined($plan_ok)
                ? ("Bad subtest plan, expected " . $hub->plan . " but ran " . $hub->count)
                : (),
    ]) unless $pass;

    $ctx->hub->send($e);

    $ctx->release;
    return $pass;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::API - Primary interface for writing Test2 based testing tools.

=head1 EXPERIMENTAL RELEASE

This is an experimental release. Using this right now is not recommended.

=head1 ***INTERNALS NOTE***

B<The internals of this package are subject to change at any time!> The public
methods provided will not change in backwords incompatible ways (once there is
a stable release), but the underlying implementation details might.
B<Do not break encapsulation here!>

Currently the implementation is to create a single instance of the
L<Test2::API::Instance> Object. All class methods defer to the single
instance. There is no public access to the singleton, and that is intentional.
The class methods provided by this package provide the only functionality
publicly exposed.

This is done primarily to avoid the problems Test::Builder had by exposing its
singleton. We do not want anyone to replace this singleton, rebless it, or
directly muck with its internals. If you need to do something, and cannot
because of the restrictions placed here then please report it as an issue. If
possible we will create a way for you to implement your functionality without
exposing things that should not be exposed.

=head1 DESCRIPTION

This package exports all the functions necessary to write and/or verify testing
tools. Using these building blocks you can begin writing test tools very
quickly. You are also provided with tools that help you to test the tools you
write.

=head1 SYNOPSYS

=head2 WRITING A TOOL

The C<context()> method is your primary interface into the Test2 framework.

    package My::Ok;
    use Test2::API qw/context/;

    our @EXPORT = qw/my_ok/;
    use base 'Exporter';

    # Just like ok() from Test::More
    sub my_ok($;$) {
        my ($bool, $name) = @_;
        my $ctx = context(); # Get a context
        $ctx->ok($bool, $name);
        $ctx->release; # Release the context
        return $bool;
    }

See L<Test2::API::Context> for a list of methods avabilable on the context object.

=head2 TESTING YOUR TOOLS

The C<intercept { ... }> tool lets you temporarily intercept all events
generated by the test system:

    use Test2::API qw/intercept/;

    use My::Ok qw/my_ok/;

    my $events = intercept {
        # These events are not displayed
        my_ok(1, "pass");
        my_ok(0, "fail");
    };

    my_ok(@$events == 2, "got 2 events, the pass and the fail");
    my_ok($events->[0]->pass, "first event passed");
    my_ok(!$events->[1]->pass, "second event failed");

=head2 OTHER API FUNCTIONS

    use Test2::API qw{
        test2_init_done
        test2_stack
        test2_ipc
        test2_formatter_set
        test2_formatter
    };

    my $init  = test2_init_done();
    my $stack = test2_stack();
    my $ipc   = test2_ipc();

    test2_formatter_set($FORMATTER)
    my $formatter = test2_formatter();

    ... And others ...

=head1 MAIN API EXPORTS

All exports are optional, you must specify subs to import.

    use Test2::API qw/context intercept run_subtest/;

This is the list of exports that are most commonly needed. If you are simply
writing a tool then this is probably all you need. If you need something and
you cannot find it here then you can also look at L</OTHER API EXPORTS>.

These exports lack the 'test2_' prefix because of how important/common they
are. Exports in the L</OTHER API EXPORTS> section have the 'test2_' prefix to
ensure they stand out.

=head2 context(...)

Usage:

=over 4

=item $ctx = context()

=item $ctx = context(%params)

=back

The C<context()> function will always return the current context to you. If
there is already a context active it will be returned. If there is not an
active context one will be generated. When a context is generated it will
default to using the file and line number where the currently running sub was
called from.

Please see L<Test2::API::Context/"CRITICAL DETAILS"> for important rules about what
you can and acannot do with a context once it is obtained.

B<Note> This function will throw an exception if you ignore the context object
it returns.

=head3 OPTIONAL PARAMETERS

All parameters to C<context> are optional.

=over 4

=item level => $int

If you must obtain a context in a sub deper than your entry point you can use
this to tell it how many EXTRA stack frames to look back. If this option is not
provided the default of C<0> is used.

    sub third_party_tool {
        my $sub = shift;
        ... # Does not obtain a context
        $sub->();
        ...
    }

    third_party_tool(sub {
        my $ctx = context(level => 1);
        ...
        $ctx->release;
    });

=item wrapped => $int

Use this if you need to write your own tool that wraps a call to C<context()>
with the intent that it should return a context object.

    sub my_context {
        my %params = ( wrapped => 0, @_ );
        $params{wrapped}++;
        my $ctx = context(%params);
        ...
        return $ctx;
    }

    sub my_tool {
        my $ctx = my_context();
        ...
        $ctx->release;
    }

If you do not do this than tools you call that also check for a context will
notice that the context they grabbed was created at the same stack depth, which
will trigger protective measures that warn you and destroy the existing
context.

=item stack => $stack

Normally C<context()> looks at the global hub stack. If you are maintaining
your own L<Test2::API::Stack> instance you may pass it in to be used
instead of the global one.

=item hub => $hub

Use this parameter if you want to onbtain the context for a specific hub
instead of whatever one happens to be at the top of the stack.

=item on_init => sub { ... }

This lets you provide a callback sub that will be called B<ONLY> if your call
to c<context()> generated a new context. The callback B<WILL NOT> be called if
C<context()> is returning an existing context. The only argument passed into
the callback will be the context object itself.

    sub foo {
        my $ctx = context(on_init => sub { 'will run' });

        my $inner = sub {
            # This callback is not run since we are getting the existing
            # context from our parent sub.
            my $ctx = context(on_init => sub { 'will NOT run' });
            $ctx->release;
        }
        $inner->();

        $ctx->release;
    }

=item on_release => sub { ... }

This lets you provide a callback sub that will be called when the context
instance is released. This callback will be added to the returned context even
if an existing context is returned. If multiple calls to context add callbacks
then all will be called in reverse order when the context is finally released.

    sub foo {
        my $ctx = context(on_release => sub { 'will run second' });

        my $inner = sub {
            my $ctx = context(on_release => sub { 'will run first' });

            # Neither callback runs on this release
            $ctx->release;
        }
        $inner->();

        # Both callbacks run here.
        $ctx->release;
    }

=back

=head2 release($;$)

Usage:

=over 4

=item release $ctx;

=item release $ctx, ...;

=back

This is intended as a shortcut that lets you release your context and return a
value in one statement. This function will get your context, and an optional
return value. It will release your context, then return your value. Scalar
context is always assumed.

    sub tool {
        my $ctx = context();
        ...

        return release $ctx, 1;
    }

This tool is most useful when you want to return the value you get from calling
a function that needs to see the current context:

    my $ctx = context();
    my $out = some_tool(...);
    $ctx->release;
    return $out;

We can combine the last 3 lines of the above like so:

    my $ctx = context();
    release $ctx, some_tool(...);

=head2 intercept(&)

Usage:

    my $events = intercept {
        ok(1, "pass");
        ok(0, "fail");
        ...
    };

This function takes a codeblock as its only argument, and it has a prototype.
It will execute the codeblock, intercepting any generated events in the
process. It will return an array reference with all the generated event
objects. All events should be subclasses of L<Test2::Event>.

This is a very low-level subtest tool. This is useful for writing tools which
procude subtests. This is not intended for people simply writing tests.

=head2 run_subtest(...)

Usage:

    run_subtest($NAME, \&CODE, $BUFFERED, @ARGS)

This will run the provided codeblock with the args in C<@args>. This codeblock
will be run as a subtest. A subtest is an isolated test state that is condensed
into a single L<Test2::Event::Subtest> event, which contains all events
generated inside the subtest.

=head3 ARGUMENTS:

=over 4

=item $NAME

The name of the subtest.

=item \&CODE

The code to run inside the subtest.

=item $BUFFERED

If this is true then the subtest will be buffered. In a buffered subtest the
child events are hidden from the formatter, the formatter will only recieve the
final L<Test2:Event::Subtest> event. In an unbuffered subtest the formatter
will see all events as they happen, as well as the final one.

=item @ARGS

Any extra arguments you want passed into the subtest code.

=back

=head1 OTHER API EXPORTS

Exports in this section are not commonly needed. These all have the 'test2_'
prefix to help ensure they stand out. You should look at the L</MAIN API
EXPORTS> section before looking here. This section is one where "Great power
comes with great responsiblity". It is possible to break things badly if you
are not careful with these.

All exports are optional, you need to list which ones you want at import time:

    use Test2::API qw/test2_init_done .../;

=head2 STATUS AND INITIALIZATION STATE

These provide access to internal state and object instances.

=over 4

=item $bool = test2_init_done()

This will return true if the stack and ipc instances have already been
initialized. It will return false if they have not. Init happens as late as
possible, it happens as soon as a tool requests the ipc instance, the
formatter, or the stack.

=item $bool = test2_load_done()

This will simply return the boolean value of the loaded flag. If Test2 has
finished loading this will be true, otherwise false. Loading is considered
complete the first time a tool requests a context.

=item $stack = test2_stack()

This will return the global L<Test2::API::Stack> instance. If this has not
yet been initialized it will be initialized now.

=item $bool = test2_no_wait()

=item test2_no_wait($bool)

This can be used to get/set the no_wait status. Waiting is turned on by
default. Waiting will cause the parent process/thread to wait until all child
processes and threads are finished before exiting. You will almost never want
to turn this off.

=back

=head2 BEHAVIOR HOOKS

These are hooks that allow you to add custom behavior to actions taken by Test2
and tools built on top of it.

=over 4

=item test2_add_callback_exit(sub { ... })

This can be used to add a callback that is called after all testing is done. This
is too late to add additional results, the main use of this callback is to set the
exit code.

    test2_add_callback_exit(
        sub {
            my ($context, $exit, \$new_exit) = @_;
            ...
        }
    );

The C<$context> passed in will be an instance of L<Test2::API::Context>. The
C<$exit> argument will be the original exit code before anything modified it.
C<$$new_exit> is a reference to the new exit code. You may modify this to
change the exit code. Please note that C<$$new_exit> may already be different
from C<$exit>

=item test2_add_callback_post_load(sub { ... })

Add a callback that will be called when Test2 is finished loading. This
means the callback will be run once, the first time a context is obtained.
If Test2 has already finished loading then the callback will be run immedietly.

=item test2_add_callback_context_init(sub { ... })

Add a callback that will be called every time a new context is created. The
callback will recieve the newly created context as its only argument.

=item test2_add_callback_context_release(sub { ... })

Add a callback that will be called every time a context is released. The
callback will recieve the released context as its only argument.

=back

=head2 IPC AND CONCURRENCY

These let you access, or specify, the IPC system internals.

=over 4

=item $ipc = test2_ipc()

This will return the global L<Test2::IPC::Driver> instance. If this has not yet
been initialized it will be initialized now.

=item test2_ipc_add_driver($DRIVER)

Add an IPC driver to the list. This will add the driver to the start of the
list.

=item @drivers = test2_ipc_drivers()

Get the list of IPC drivers.

=item $bool = test2_ipc_polling()

Check if polling is enabled.

=item test2_ipc_enable_polling()

Turn on polling. This will cull events from other processes and threads every
time a context is created.

=item test2_ipc_disable_polling()

Turn off IPC polling.

=back

=head2 MANAGING FORMATTERS

These let you access, or specify, the formatters that can/should be used.

=over 4

=item $formatter = test2_formatter

This will return the global formatter class. This is not an instance. By
default the formatter is set to L<Test2::Formatter::TAP>.

You can override this default using the C<T2_FORMATTER> environment variable.

Normally 'Test2::Formatter::' is prefixed to the value in the
environment variable:

    $ T2_FORMATTER='TAP' perl test.t     # Use the Test2::Formatter::TAP formatter
    $ T2_FORMATTER='Foo' perl test.t     # Use the Test2::Formatter::Foo formatter

If you want to specify a full module name you use the '+' prefix:

    $ T2_FORMATTER='+Foo::Bar' perl test.t     # Use the Foo::Bar formatter

=item test2_formatter_set($class_or_instance)

Set the global formatter class. This can only be set once. B<Note:> This will
override anything specified in the 'T2_FORMATTER' environment variable.

=item @formatters = test2_formatters()

Get a list of all loaded formatters.

=item test2_formatter_add($class_or_instance)

Add a formatter to the list. Last formatter added is used at initialization. If
this is called after initialization a warning will be issued.

=back

=head1 OTHER EXAMPLES

See the C</Examples/> directory included in this distribution.

=head1 SEE ALSO

L<Test2::API::Context> - Detailed documentation of the context object.

L<Test2::IPC> - The IPC system used for threading/fork support.

L<Test2::Formatter> - Formatters such as TAP live here.

L<Test2::Event> - Events live in this namespace.

L<Test2::Hub> - All events eventually funnel through a hub. Custom hubs are how
C<intercept()> and C<run_subtest()> are implemented.

=head1 MAGIC

This package has an END block. This END block is responsible for setting the
exit code based on the test results. This end block also calls the callbacks that
can be added to this package.

=head1 SOURCE

The source code repository for Test2 can be found at
F<http://github.com/Test-More/Test2/>.

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
