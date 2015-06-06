use Test::Stream::Sync;

my $BEGIN_INIT;
my $POST_IPC_INIT;

BEGIN { $BEGIN_INIT = Test::Stream::Sync->init_done }

use Test::Stream::IPC;

BEGIN { $POST_IPC_INIT = Test::Stream::Sync->init_done }

use Test::Stream;

BEGIN {
    ok(!$BEGIN_INIT, "Not initialized right at load");
    ok(!$POST_IPC_INIT, "Not initialized by ipc");
    ok(Test::Stream::Sync->init_done, "Test::Stream initialized sync")
}

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
