use strict;
use warnings;

use Test2::IPC;
use Test2::Tester;
use Test2::Util qw/get_tid/;
use Test2::Util qw/CAN_THREAD CAN_REALLY_FORK/;

my $CLASS = 'Test2::Global::Instance';

my $one = $CLASS->new;
is_deeply(
    $one,
    {
        pid      => $$,
        tid      => get_tid(),
        contexts => {},

        finalized => undef,
        ipc       => undef,
        stack     => undef,
        format    => undef,

        no_wait => 0,
        loaded  => 0,

        exit_callbacks            => [],
        post_load_callbacks       => [],
        context_init_callbacks    => [],
        context_release_callbacks => [],
    },
    "Got initial settings"
);

%$one = ();
is_deeply($one, {}, "wiped object");

$one->reset;
is_deeply(
    $one,
    {
        pid      => $$,
        tid      => get_tid(),
        contexts => {},

        finalized => undef,
        ipc       => undef,
        stack     => undef,
        format    => undef,

        no_wait => 0,
        loaded  => 0,

        exit_callbacks            => [],
        post_load_callbacks       => [],
        context_init_callbacks    => [],
        context_release_callbacks => [],
    },
    "Reset Object"
);

ok(!$one->format_set, "no formatter set");
$one->set_format('Foo');
ok($one->format_set, "formatter set");
$one->reset;

my $ran = 0;
my $callback = sub { $ran++ };
$one->add_post_load_callback($callback);
ok(!$ran, "did not run yet");
is_deeply($one->post_load_callbacks, [$callback], "stored callback for later");

ok(!$one->loaded, "not loaded");
$one->load;
ok($one->loaded, "loaded");
is($ran, 1, "ran the callback");

$one->load;
is($ran, 1, "Did not run the callback again");

$one->add_post_load_callback($callback);
is($ran, 2, "ran the new callback");
is_deeply($one->post_load_callbacks, [$callback, $callback], "stored callback for the record");

like(
    exception { $one->add_post_load_callback({}) },
    qr/Post-load callbacks must be coderefs/,
    "Post-load callbacks must be coderefs"
);

$one->reset;
ok($one->ipc, 'got ipc');
ok($one->finalized, "calling ipc finalized the object");

$one->reset;
ok($one->stack, 'got stack');
ok($one->finalized, "calling stack finalized the object");

$one->reset;
ok($one->format, 'Got formatter');
ok($one->finalized, "calling format finalized the object");

{
    $one->reset;
    local %INC = %INC;
    delete $INC{'Test2/IPC.pm'};
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
    is($one->format, 'Test2::Formatter::TAP', "got specified formatter");
    ok($one->finalized, "calling format finalized the object");

    local $ENV{TS_FORMATTER} = '+Test2::Formatter::TAP';
    $one->reset;
    is($one->format, 'Test2::Formatter::TAP', "got specified formatter");
    ok($one->finalized, "calling format finalized the object");

    local $ENV{TS_FORMATTER} = '+Fake';
    $one->reset;
    like(
        exception { $one->format },
        qr/COULD NOT LOAD FORMATTER '\+Fake' \(set by the 'TS_FORMATTER' environment variable\)/,
        "Bad formatter"
    );
}

$ran = 0;
$one->reset;
$one->add_exit_callback($callback);
is(@{$one->exit_callbacks}, 1, "added an exit callback");
$one->add_exit_callback($callback);
is(@{$one->exit_callbacks}, 2, "added another exit callback");

like(
    exception { $one->add_exit_callback({}) },
    qr/End callbacks must be coderefs/,
    "Exit callbacks must be coderefs"
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
    like($warnings[0], qr/Process .* did not exit cleanly \(status: 255\)/, "Warn about exit");
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
        like($warnings[0], qr/Thread .* did not end cleanly: xxx/, "Warn about exit");
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
    delete $INC{'Test2/IPC.pm'};
    $one->reset();
    my @events;
    $one->stack->top->filter(sub { push @events => $_[1]; undef});
    $one->stack->new_hub;
    local $? = 0;
    $one->set_exit;
    is($?, 255, "errors on exit");
    like($events[0]->message, qr/Test ended with extra hubs on the stack!/, "got diag");
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
    like($events[0]->message, qr/Test ended with extra hubs on the stack!/, "got diag");
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

{
    my $ctx = bless {
        trace => Test2::Context::Trace->new(frame => ['Foo::Bar', 'Foo/Bar.pm', 42, 'xxx']),
    }, 'Test2::Context';
    $one->contexts->{1234} = $ctx;

    local $? = 500;
    my $warnings = warnings { $one->set_exit };
    is($?, 255, "set exit code to a sane number");

    is_deeply(
        $warnings,
        [
            "context object was never released! This means a testing tool is behaving very badly at Foo/Bar.pm line 42.\n"
        ],
        "Warned about unfreed context"
    );
}

done_testing;


__END__


