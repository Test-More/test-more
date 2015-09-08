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
use Test::Stream::Capabilities qw/CAN_FORK CAN_THREAD/;

use Scalar::Util qw/reftype/;

BEGIN {
    my $sync = 'Test::Stream::Sync';
    def ok => (!$sync->init_done, "Not initialized right at load");

    my $guts     = $sync->GUTS;
    my $snapshot = $sync->GUTS_SNAPSHOT;

    def is => (
        $snapshot,
        {
            PID     => $$,
            TID     => get_tid(),
            NO_WAIT => 0,
            INIT    => undef,
            IPC     => undef,
            STACK   => undef,
            FORMAT  => undef,
            HOOKS   => [],
        },
        "got guts"
    );

    my $reset = sub {
        ${$guts->{PID}}     = $$;
        ${$guts->{TID}}     = get_tid();
        ${$guts->{NO_WAIT}} = 0;
        ${$guts->{INIT}}    = undef;
        ${$guts->{IPC}}     = undef;
        ${$guts->{STACK}}   = undef;
        ${$guts->{FORMAT}}  = undef;
        @{$guts->{HOOKS}}   = ();
    };

    #####################
    # Now we tests all the things that modify state, before resetting that state at the end.
    $sync->_init();
    def ok => (${$guts->{INIT}}, "init done");
    def ok => ($sync->init_done, "init done now");
    def isa_ok => (${$guts->{STACK}}, 'Test::Stream::Stack');
    def is => (${$guts->{FORMAT}}, 'Test::Stream::TAP', "formatter set to TAP");
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
    def is => (${$guts->{FORMAT}}, 'Test::Stream::TAP', "formatter set to TAP");
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
    def is => ($sync->formatter(), 'Test::Stream::TAP', "TAP formatter");
    def is => ($sync->formatter(), 'Test::Stream::TAP', "TAP formatter");
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

    if (CAN_FORK) {
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

    if (CAN_FORK) {
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
    ${$guts->{PID}}     = $snapshot->{PID};
    ${$guts->{TID}}     = $snapshot->{TID};
    ${$guts->{NO_WAIT}} = $snapshot->{NO_WAIT};
    ${$guts->{INIT}}    = $snapshot->{INIT}; 
    ${$guts->{IPC}}     = $snapshot->{IPC};
    ${$guts->{STACK}}   = $snapshot->{STACK};
    ${$guts->{FORMAT}}  = $snapshot->{FORMAT};
    @{$guts->{HOOKS}}   = @{$snapshot->{HOOKS}};
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

__END__


sub _ipc_wait {
    my $fail = 0;

    while (CAN_FORK) {
        my $pid = CORE::wait();
        my $err = $?;
        last if $pid == -1;
        next unless $err;
        $fail++;
        $err = $err >> 8;
        warn "Process $pid did not exit cleanly (status: $err)\n";
    }

    if (USE_THREADS) {
        for my $t (threads->list()) {
            $t->join;
            # In older threads we cannot check if a thread had an error unless
            # we control it and its return.
            my $err = $t->can('error') ? $t->error : undef;
            next unless $err;
            my $tid = $t->tid();
            $fail++;
            chomp($err);
            warn "Thread $tid did not end cleanly: $err\n";
        }
    }

    return 0 unless $fail;
    return 255;
}

# Set the exit status
END { _set_exit() }
sub _set_exit {
    my $exit     = $?;
    my $new_exit = $exit;

    if ($PID != $$ || $TID != get_tid()) {
        $? = $exit;
        return;
    }

    my @hubs = $STACK ? $STACK->all : ();

    if (@hubs && $IPC && !$NO_WAIT) {
        local $?;
        my %seen;
        for my $hub (reverse @hubs) {
            my $ipc = $hub->ipc || next;
            next if $seen{$ipc}++;
            $ipc->waiting();
        }

        my $ipc_exit = _ipc_wait();
        $new_exit ||= $ipc_exit;
    }

    # None of this is necessary if we never got a root hub
    if(my $root = shift @hubs) {
        my $dbg = Test::Stream::DebugInfo->new(
            frame  => [__PACKAGE__, __FILE__, 0, 'Test::Stream::Context::END'],
            detail => 'Test::Stream::Context END Block finalization',
        );
        my $ctx = Test::Stream::Context->new(
            debug => $dbg,
            hub   => $root,
        );

        if (@hubs) {
            $ctx->diag("Test ended with extra hubs on the stack!");
            $new_exit  = 255;
        }

        unless ($root->no_ending) {
            local $?;
            $root->finalize($dbg) unless $root->state->ended;
            $_->($ctx, $exit, \$new_exit) for @HOOKS;
            $new_exit ||= $root->state->failed;
        }
    }

    $new_exit = 255 if $new_exit > 255;

    $? = $new_exit;
}
