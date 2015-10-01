use strict;
use warnings;

# Never do this anywhere else.
BEGIN {
    package Test::Stream::Sync;
    my @warnings;
    {
        local $SIG{__WARN__} = sub { push @warnings => @_ };
        require Test::Stream::Sync;
    }
    warn $_ for grep { $_ !~ m/Enabling Test::Stream::Sync debug features/ } @warnings;
}

use Test::Stream::DeferredTests;
use Test::Stream::Util qw/get_tid/;
use Test::Stream::Capabilities qw/CAN_THREAD CAN_REALLY_FORK/;

use Scalar::Util qw/reftype/;

BEGIN {
    local $ENV{TS_FORMATTER};
    my $sync = 'Test::Stream::Sync';
    def ok => (!$sync->init_done, "Not initialized right at load");

    my $guts     = $sync->GUTS;
    my $snapshot = $sync->GUTS_SNAPSHOT;

    def is => (
        $snapshot,
        {
            PID       => $$,
            TID       => get_tid(),
            NO_WAIT   => 0,
            INIT      => undef,
            IPC       => undef,
            STACK     => undef,
            FORMAT    => undef,
            HOOKS     => [],
            LOADED    => 0,
            POST_LOAD => [],
        },
        "got guts"
    );

    my $reset = sub {
        ${$guts->{PID}}       = $$;
        ${$guts->{TID}}       = get_tid();
        ${$guts->{NO_WAIT}}   = 0;
        ${$guts->{INIT}}      = undef;
        ${$guts->{IPC}}       = undef;
        ${$guts->{STACK}}     = undef;
        ${$guts->{FORMAT}}    = undef;
        @{$guts->{HOOKS}}     = ();
        ${$guts->{LOADED}}    = 0;
        @{$guts->{POST_LOAD}} = ();
    };

    #####################
    # Now we tests all the things that modify state, before resetting that state at the end.
    $sync->_init();
    def ok => (${$guts->{INIT}}, "init done");
    def ok => ($sync->init_done, "init done now");
    def isa_ok => (${$guts->{STACK}}, 'Test::Stream::Stack');
    def is => (${$guts->{FORMAT}}, 'Test::Stream::Formatter::TAP', "formatter set to TAP");
    def ok => (!${$guts->{IPC}}, "No IPC yet");
    def ok => (! scalar @{$guts->{HOOKS}}, "no hooks yet");
    $reset->();

    require Test::Stream::IPC;
    Test::Stream::IPC->import();
    def ok => (!$sync->init_done, "Not initialized by IPC");
    $sync->_init();
    def ok => ($sync->init_done, "init done now");
    def ok => (${$guts->{INIT}}, "init done");
    def isa_ok => (${$guts->{STACK}}, 'Test::Stream::Stack');
    def is => (${$guts->{FORMAT}}, 'Test::Stream::Formatter::TAP', "formatter set to TAP");
    def isa_ok => (${$guts->{IPC}}, 'Test::Stream::IPC');

    my @errs;
    my $hook = sub { 1 };
    $sync->add_hook($hook);
    $sync->add_hook($hook);
    eval { $sync->add_hook(); }; push @errs => $@;
    eval { $sync->add_hook('foo'); }; push @errs => $@;
    eval { $sync->add_hook([]); }; push @errs => $@;
    def is => ($sync->hooks, 2, "2 hooks");
    def is => ([@{$guts->{HOOKS}}], [$hook, $hook], "Added hooks");
    def like => (
        [@errs],
        [
            qr/End hooks must be coderefs/,
            qr/End hooks must be coderefs/,
            qr/End hooks must be coderefs/,
        ],
        "Got expected exceptions",
    );

    $reset->();
    def ok => (!$sync->init_done, "Not initialized yet");
    def isa_ok => ($sync->stack(), 'Test::Stream::Stack');
    def isa_ok => ($sync->stack(), 'Test::Stream::Stack');
    def ok => ($sync->init_done, "init done now");

    $reset->();
    def ok => (!$sync->init_done, "Not initialized yet");
    def isa_ok => ($sync->ipc(), 'Test::Stream::IPC');
    def isa_ok => ($sync->ipc(), 'Test::Stream::IPC');
    def ok => ($sync->init_done, "init done now");

    $reset->();
    def ok => (!$sync->init_done, "Not initialized yet");
    def is => ($sync->formatter(), 'Test::Stream::Formatter::TAP', "TAP formatter");
    def is => ($sync->formatter(), 'Test::Stream::Formatter::TAP', "TAP formatter");
    def ok => ($sync->init_done, "init done now");

    $reset->();
    $sync->set_formatter('Fake::Fake');
    eval { $sync->set_formatter('Fake::Fake') };
    def like => ($@, qr/Global Formatter already set/, "cannot set formatter multiple times");
    def ok => (!$sync->init_done, "Not initialized yet");
    def is => ($sync->formatter(), 'Fake::Fake', "FAKE formatter");
    def is => ($sync->formatter(), 'Fake::Fake', "FAKE formatter");
    def ok => ($sync->init_done, "init done now");

    $reset->();
    eval { $sync->set_formatter() };
    def like => ($@, qr/No formatter specified/, "must specifty formatter");

    $reset->();
    {
        local $ENV{TS_FORMATTER} = 'Fake';
        eval { $sync->formatter };
        def like => (
            $@,
            qr/COULD NOT LOAD FORMATTER 'Fake' \(set by the 'TS_FORMATTER' environment variable\)/,
            "Bad formatter"
        );
    }

    $reset->();
    {
        local $ENV{TS_FORMATTER} = '+Foo';
        local $INC{'Foo.pm'} = __FILE__;
        def is => ($sync->formatter, 'Foo', "Used env var formatter (full)");
    }

    $reset->();
    {
        local $ENV{TS_FORMATTER} = 'Foo';
        local $INC{'Test/Stream/Formatter/Foo.pm'} = __FILE__;
        def is => ($sync->formatter, 'Test::Stream::Formatter::Foo', "Used env var formatter (short)");
    }

    $reset->();
    def is => ($sync->no_wait, 0, "no_wait is off");
    $sync->no_wait(1);
    def is => ($sync->no_wait, 1, "no_wait is on");
    $sync->no_wait(0);
    def is => ($sync->no_wait, 0, "no_wait is off again");
    $sync->_init;
    def is => ($sync->no_wait, 0, "no_wait is off");
    $sync->no_wait(1);
    def is => ($sync->no_wait, 1, "no_wait is on");
    $sync->no_wait(0);
    def is => ($sync->no_wait, 0, "no_wait is off again");

    if (CAN_REALLY_FORK) {
        $reset->();
        my $pid = fork;
        die "Failed to fork!" unless defined $pid;
        unless($pid) { exit 0 }

        def is => ($sync->_ipc_wait, 0, "No errors");

        $pid = fork;
        die "Failed to fork!" unless defined $pid;
        unless($pid) { exit 255 }
        my @warnings;
        {
            local $SIG{__WARN__} = sub { push @warnings => @_ };
            def is => ($sync->_ipc_wait, 255, "Process exited badly");
        }
        def like => (\@warnings, [qr/Process .* did not exit cleanly \(status: 255\)/], "Warn about exit");
    }

    if (CAN_THREAD && $] ge '5.010') {
        require threads;
        $reset->();

        threads->new(sub { 1 });
        def is => ($sync->_ipc_wait, 0, "No errors");

        if (threads->can('error')) {
            threads->new(sub {
                close(STDERR);
                close(STDOUT);
                die "xxx"
            });
            my @warnings;
            {
                local $SIG{__WARN__} = sub { push @warnings => @_ };
                def is => ($sync->_ipc_wait, 255, "Process exited badly");
            }
            def like => (\@warnings, [qr/Thread .* did not end cleanly: xxx/], "Warn about exit");
        }
    }

    $reset->();
    local $? = 0;
    $sync->_set_exit;
    def is => ($?, 0, "no errors on exit");

    $reset->();
    def is => (Test::Stream::Sync->loaded, 0, "not loaded");
    def is => (Test::Stream::Sync->loaded, 0, "not modified by checking");

    my ($ranA, $ranB) = (0, 0);
    Test::Stream::Sync->post_load(sub { $ranA++ });
    Test::Stream::Sync->post_load(sub { $ranB++ });
    def is => (Test::Stream::Sync->loaded, 0, "not loaded");
    def is => ($ranA, 0, "Did not run");
    def is => ($ranB, 0, "Did not run");
    def is => (Test::Stream::Sync->post_loads, 2, "2 loads");

    Test::Stream::Sync->loaded(0); # False value
    def is => (Test::Stream::Sync->loaded, 0, "not loaded");
    def is => ($ranA, 0, "Did not run");
    def is => ($ranB, 0, "Did not run");

    Test::Stream::Sync->loaded('true');
    def is => ($ranA, 1, "ran once");
    def is => ($ranB, 1, "ran once");
    def is => (Test::Stream::Sync->loaded, 1, "loaded");

    Test::Stream::Sync->loaded(1);
    def is => ($ranA, 1, "Only ran once");
    def is => ($ranB, 1, "Only ran once");
    def is => (Test::Stream::Sync->loaded, 1, "loaded");

    Test::Stream::Sync->post_load(sub { $ranA++ });
    def is => ($ranA, 2, "Ran right away");

    #####################
    # Reset everything
    $reset->();
}


use Test::Stream qw/-V1 -Tester/;
BEGIN { def ok => (Test::Stream::Sync->init_done, "Test::Stream initialized sync") }

do_def;

is(Test::Stream::Sync->no_wait, 0, "waiting is on by default");

ok(Test::Stream::Sync->ipc, "Got an IPC instance");
isa_ok(Test::Stream::Sync->ipc, 'Test::Stream::IPC');

ok(Test::Stream::Sync->stack, "Got a stack instance");
isa_ok(Test::Stream::Sync->stack, 'Test::Stream::Stack');

is(
    Test::Stream::Sync->stack->top->ipc,
    Test::Stream::Sync->ipc,
    "top hub got our IPC instance"
);

{
    my $sync = 'Test::Stream::Sync';

    my $guts     = $sync->GUTS;
    my $snapshot = $sync->GUTS_SNAPSHOT;

    my $reset = sub {
        ${$guts->{PID}}     = $$;
        ${$guts->{TID}}     = get_tid() || 0;
        ${$guts->{NO_WAIT}} = 0;
        ${$guts->{INIT}}    = undef;
        ${$guts->{IPC}}     = undef;
        ${$guts->{STACK}}   = undef;
        ${$guts->{FORMAT}}  = undef;
        @{$guts->{HOOKS}}   = ();
    };

    {
        $reset->();
        ${$guts->{TID}} = 1;
        local $? = 0;
        $sync->_set_exit;
        def is => ($?, 0, "no errors on exit");
    }

    {
        $reset->();
        $sync->stack->top;
        $sync->no_wait(1);
        local $? = 0;
        $sync->_set_exit;
        def is => ($?, 0, "no errors on exit");
    }

    {
        $reset->();
        $sync->stack->top->set_no_ending(1);
        local $? = 0;
        $sync->_set_exit;
        def is => ($?, 0, "no errors on exit");
    }

    {
        $reset->();
        $sync->stack->top->state->bump_fail;
        $sync->stack->top->state->bump_fail;
        local $? = 0;
        $sync->_set_exit;
        def is => ($?, 2, "number of failures");
    }

    {
        $reset->();
        local $? = 500;
        $sync->_set_exit;
        def is => ($?, 255, "set exit code to a sane number");
    }

    {
        local %INC = %INC;
        delete $INC{'Test/Stream/IPC.pm'};
        $reset->();
        my @events;
        $sync->stack->top->munge(sub { push @events => $_[1]; $_[1] = undef });
        $sync->stack->new_hub;
        local $? = 0;
        $sync->_set_exit;
        def is => ($?, 255, "errors on exit");
        def like => (\@events, [{ message => qr/Test ended with extra hubs on the stack!/ }], "got diag");
    }

    {
        $reset->();
        my @events;
        $sync->stack->top->munge(sub { push @events => $_[1]; $_[1] = undef });
        $sync->stack->new_hub;
        def ok => ($sync->stack->top->ipc, "Have IPC");
        $sync->stack->new_hub;
        def ok => ($sync->stack->top->ipc, "Have IPC");
        $sync->stack->top->set_ipc(undef);
        def ok => (!$sync->stack->top->ipc, "no IPC");
        $sync->stack->new_hub;
        local $? = 0;
        $sync->_set_exit;
        def is => ($?, 255, "errors on exit");
        def like => (\@events, [{ message => qr/Test ended with extra hubs on the stack!/ }], "got diag");
    }

    if (CAN_REALLY_FORK) {
        local $SIG{__WARN__} = sub { };
        $reset->();
        my $pid = fork;
        die "Failed to fork!" unless defined $pid;
        unless($pid) { exit 255 }
        $sync->stack->top;

        local $? = 0;
        $sync->_set_exit;
        def is => ($?, 255, "errors on exit");

        $reset->();
        $pid = fork;
        die "Failed to fork!" unless defined $pid;
        unless($pid) { exit 255 }
        $sync->stack->top;

        local $? = 122;
        $sync->_set_exit;
        def is => ($?, 122, "kept original exit");
    }


    # Restore things
    ${$guts->{PID}}       = $snapshot->{PID};
    ${$guts->{TID}}       = $snapshot->{TID};
    ${$guts->{NO_WAIT}}   = $snapshot->{NO_WAIT};
    ${$guts->{INIT}}      = $snapshot->{INIT};
    ${$guts->{IPC}}       = $snapshot->{IPC};
    ${$guts->{STACK}}     = $snapshot->{STACK};
    ${$guts->{FORMAT}}    = $snapshot->{FORMAT};
    @{$guts->{HOOKS}}     = @{$snapshot->{HOOKS}};
    ${$guts->{LOADED}}    = $snapshot->{LOADED};
    @{$guts->{POST_LOAD}} = @{$snapshot->{POST_LOAD}};
}

do_def;

{
    package FOLLOW;
    sub DESTROY {
        return if $_[0]->{fixed};
        print "not ok - Did not run end!";
        exit 255;
    }
}

our $kill = bless {fixed => 0}, 'FOLLOW';

Test::Stream::Sync->add_hook(sub {
    print "# Running END hook\n";
    $kill->{fixed} = 1;
});

done_testing;
