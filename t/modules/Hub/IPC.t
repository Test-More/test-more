use strict;
use warnings;

use Test::Stream::IPC;
use Test::Stream::Capabilities qw/CAN_FORK CAN_THREAD/;
use Test::Stream;
use Test::Stream::Hub;

{
    package My::Formatter;

    sub new { bless [], shift };

    my $check = 1;
    sub write {
        my $self = shift;
        my ($e, $count) = @_;
        push @$self => $e;
    }
}

{
    package My::Event;

    use Test::Stream::Event(
        accessors => [qw/msg/],
    );
}

my ($driver) = Test::Stream::IPC->drivers;
is($driver, 'Test::Stream::IPC::Files', "Default Driver");
my $ipc = $driver->new;
my $hub = Test::Stream::Hub->new(
    formatter => My::Formatter->new,
    ipc => $ipc,
);

sub build_event {
    my ($msg) = @_;
    return My::Event->new(msg => $msg, debug => 'fake');
}

my $e1 = build_event('foo');
my $e2 = build_event('bar');
my $e3 = build_event('baz');

sub do_send {
    $hub->send($e1);
    $hub->send($e2);
    $hub->send($e3);
}

sub do_check {
    my $name = shift;

    my $old = $hub->format(My::Formatter->new);

    isa_ok($old, 'My::Formatter');
    is_deeply(
        $old,
        [$e1, $e2, $e3],
        "Formatter got all events ($name)"
    );
}

if (CAN_FORK) {
    my $pid = fork();
    die "Could not fork!" unless defined $pid;

    if ($pid) {
        is(waitpid($pid, 0), $pid, "waited properly");
        ok(!$?, "child exited with success");
        $hub->cull();
        do_check('Fork');
    }
    else {
        do_send();
        exit 0;
    }
}

if (CAN_THREAD) {
    require threads;
    my $thr = threads->new(sub { do_send() });
    $thr->join;
    $hub->cull();
    do_check('Threads');
}

do_send();
$hub->cull();
do_check('no IPC');

$hub = undef;

done_testing;
