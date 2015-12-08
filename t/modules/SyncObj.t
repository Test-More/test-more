use Test::Stream -V1, class => 'Test::Stream::SyncObj';

use Test::Stream::Util qw/get_tid/;
use Test::Stream::Capabilities qw/CAN_THREAD CAN_REALLY_FORK/;

can_ok(
    $CLASS,
    qw{
        pid tid no_wait finalized ipc stack format exit_hooks loaded
        post_load_hooks reset format_set add_post_load_hook load add_exit_hook
        set_exit
    }
);

my $one = $CLASS->new;
is(
    $one,
    {
        pid => $$,
        tid => get_tid(),

        finalized => undef,
        ipc       => undef,
        stack     => undef,
        format    => undef,

        no_wait => 0,
        loaded  => 0,

        exit_hooks      => [],
        post_load_hooks => [],
    },
    "Got initial settings"
);

%$one = ();
is($one, {}, "wiped object");

$one->reset;
is(
    $one,
    {
        pid => $$,
        tid => get_tid(),

        finalized => undef,
        ipc       => undef,
        stack     => undef,
        format    => undef,

        no_wait => 0,
        loaded  => 0,

        exit_hooks      => [],
        post_load_hooks => [],
    },
    "Reset Object"
);

ok(!$one->format_set, "no formatter set");
$one->set_format('Foo');
ok($one->format_set, "formatter set");
$one->reset;

my $ran = 0;
my $hook = sub { $ran++ };
$one->add_post_load_hook($hook);
ok(!$ran, "did not run yet");
is($one->post_load_hooks, [$hook], "stored hook for later");

ok(!$one->loaded, "not loaded");
$one->load;
ok($one->loaded, "loaded");
is($ran, 1, "ran the hook");

$one->load;
is($ran, 1, "Did not run the hook again");

$one->add_post_load_hook($hook);
is($ran, 2, "ran the new hook");
is($one->post_load_hooks, [$hook, $hook], "stored hook for the record");

like(
    dies { $one->add_post_load_hook({}) },
    qr/Post-load hooks must be coderefs/,
    "Post-load hooks must be coderefs"
);

$one->reset;
isa_ok($one->ipc, 'Test::Stream::IPC');
ok($one->finalized, "calling ipc finalized the object");

$one->reset;
isa_ok($one->stack, 'Test::Stream::Stack');
ok($one->finalized, "calling stack finalized the object");

$one->reset;
ok($one->format, 'Got formatter');
ok($one->finalized, "calling format finalized the object");

{
    $one->reset;
    local %INC = %INC;
    delete $INC{'Test/Stream/IPC.pm'};
    ok(!$one->ipc, 'IPC not loaded, no IPC object');
    ok($one->finalized, "calling ipc finalized the object");
}

$one->reset;
$one->set_format('Foo');
is($one->format, 'Foo', "got specified formatter");
ok($one->finalized, "calling format finalized the object");

{
    local $ENV{TS_FORMATTER} = 'TAP';
    $one->reset;
    is($one->format, 'Test::Stream::Formatter::TAP', "got specified formatter");
    ok($one->finalized, "calling format finalized the object");

    local $ENV{TS_FORMATTER} = '+Test::Stream::Formatter::TAP';
    $one->reset;
    is($one->format, 'Test::Stream::Formatter::TAP', "got specified formatter");
    ok($one->finalized, "calling format finalized the object");

    local $ENV{TS_FORMATTER} = '+Fake';
    $one->reset;
    like(
        dies { $one->format },
        qr/COULD NOT LOAD FORMATTER '\+Fake' \(set by the 'TS_FORMATTER' environment variable\)/,
        "Bad formatter"
    );
}

$ran = 0;
$one->reset;
$one->add_exit_hook($hook);
is(@{$one->exit_hooks}, 1, "added an exit hook");
$one->add_exit_hook($hook);
is(@{$one->exit_hooks}, 2, "added another exit hook");

like(
    dies { $one->add_exit_hook({}) },
    qr/End hooks must be coderefs/,
    "Exit hooks must be coderefs"
);

if (CAN_REALLY_FORK) {
    $one->reset;
    my $pid = fork;
    die "Failed to fork!" unless defined $pid;
    unless($pid) { exit 0 }

    is($one->_ipc_wait, 0, "No errors");

    $pid = fork;
    die "Failed to fork!" unless defined $pid;
    unless($pid) { exit 255 }
    my @warnings;
    {
        local $SIG{__WARN__} = sub { push @warnings => @_ };
        is($one->_ipc_wait, 255, "Process exited badly");
    }
    like(\@warnings, [qr/Process .* did not exit cleanly \(status: 255\)/], "Warn about exit");
}

if (CAN_THREAD && $] ge '5.010') {
    require threads;
    $one->reset;

    threads->new(sub { 1 });
    is($one->_ipc_wait, 0, "No errors");

    if (threads->can('error')) {
        threads->new(sub {
            close(STDERR);
            close(STDOUT);
            die "xxx"
        });
        my @warnings;
        {
            local $SIG{__WARN__} = sub { push @warnings => @_ };
            is($one->_ipc_wait, 255, "Thread exited badly");
        }
        like(\@warnings, [qr/Thread .* did not end cleanly: xxx/], "Warn about exit");
    }
}

{
    $one->reset();
    local $? = 0;
    $one->set_exit;
    is($?, 0, "no errors on exit");
}

{
    $one->reset();
    $one->set_tid(1);
    local $? = 0;
    $one->set_exit;
    is($?, 0, "no errors on exit");
}

{
    $one->reset();
    $one->stack->top;
    $one->no_wait(1);
    local $? = 0;
    $one->set_exit;
    is($?, 0, "no errors on exit");
}

{
    $one->reset();
    $one->stack->top->set_no_ending(1);
    local $? = 0;
    $one->set_exit;
    is($?, 0, "no errors on exit");
}

{
    $one->reset();
    $one->stack->top->state->bump_fail;
    $one->stack->top->state->bump_fail;
    local $? = 0;
    $one->set_exit;
    is($?, 2, "number of failures");
}

{
    $one->reset();
    local $? = 500;
    $one->set_exit;
    is($?, 255, "set exit code to a sane number");
}

{
    local %INC = %INC;
    delete $INC{'Test/Stream/IPC.pm'};
    $one->reset();
    my @events;
    $one->stack->top->filter(sub { push @events => $_[1]; undef});
    $one->stack->new_hub;
    local $? = 0;
    $one->set_exit;
    is($?, 255, "errors on exit");
    like(\@events, [{message => qr/Test ended with extra hubs on the stack!/}], "got diag");
}

{
    $one->reset();
    my @events;
    $one->stack->top->filter(sub { push @events => $_[1]; undef});
    $one->stack->new_hub;
    ok($one->stack->top->ipc, "Have IPC");
    $one->stack->new_hub;
    ok($one->stack->top->ipc, "Have IPC");
    $one->stack->top->set_ipc(undef);
    ok(!$one->stack->top->ipc, "no IPC");
    $one->stack->new_hub;
    local $? = 0;
    $one->set_exit;
    is($?, 255, "errors on exit");
    like(\@events, [{message => qr/Test ended with extra hubs on the stack!/}], "got diag");
}

if (CAN_REALLY_FORK) {
    local $SIG{__WARN__} = sub { };
    $one->reset();
    my $pid = fork;
    die "Failed to fork!" unless defined $pid;
    unless ($pid) { exit 255 }
    $one->stack->top;

    local $? = 0;
    $one->set_exit;
    is($?, 255, "errors on exit");

    $one->reset();
    $pid = fork;
    die "Failed to fork!" unless defined $pid;
    unless ($pid) { exit 255 }
    $one->stack->top;

    local $? = 122;
    $one->set_exit;
    is($?, 122, "kept original exit");
}

done_testing;
