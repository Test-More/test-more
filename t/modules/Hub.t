use strict;
use warnings;

use Test2::IPC;
BEGIN { require "t/tools.pl" };
use Test2::API qw/context/;
use Test2::Util qw/CAN_FORK CAN_THREAD CAN_REALLY_FORK/;

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

    use base 'Test2::Event';
    use Test2::Util::HashBase qw{msg};
}

tests basic => sub {
    my $hub = Test2::Hub->new(
        formatter => My::Formatter->new,
    );

    my $send_event = sub {
        my ($msg) = @_;
        my $e = My::Event->new(msg => $msg, trace => 'fake');
        $hub->send($e);
    };

    ok(my $e1 = $send_event->('foo'), "Created event");
    ok(my $e2 = $send_event->('bar'), "Created event");
    ok(my $e3 = $send_event->('baz'), "Created event");

    my $old = $hub->format(My::Formatter->new);

    ok($old->isa('My::Formatter'), "old formatter");
    is_deeply(
        $old,
        [$e1, $e2, $e3],
        "Formatter got all events"
    );
};

tests follow_ups => sub {
    my $hub = Test2::Hub->new;
    $hub->state->set_count(1);

    my $trace = Test2::Context::Trace->new(
        frame => [__PACKAGE__, __FILE__, __LINE__],
    );

    my $ran = 0;
    $hub->follow_up(sub {
        my ($d, $h) = @_;
        is_deeply($d, $trace, "Got trace");
        is_deeply($h, $hub, "Got hub");
        ok(!$hub->state->ended, "Hub state has not ended yet");
        $ran++;
    });

    like(
        exception { $hub->follow_up('xxx') },
        qr/follow_up only takes coderefs for arguments, got 'xxx'/,
        "follow_up takes a coderef"
    );

    $hub->finalize($trace);

    is($ran, 1, "ran once");

    is_deeply(
        $hub->state->ended,
        $trace->frame,
        "Ended at the expected place."
    );

    eval { $hub->finalize($trace) };

    is($ran, 1, "ran once");

    $hub = undef;
};

tests IPC => sub {
    my ($driver) = Test2::Global::test2_ipc_drivers;
    is($driver, 'Test2::IPC::Driver::Files', "Default Driver");
    my $ipc = $driver->new;
    my $hub = Test2::Hub->new(
        formatter => My::Formatter->new,
        ipc => $ipc,
    );

    my $build_event = sub {
        my ($msg) = @_;
        return My::Event->new(msg => $msg, trace => 'fake');
    };

    my $e1 = $build_event->('foo');
    my $e2 = $build_event->('bar');
    my $e3 = $build_event->('baz');

    my $do_send = sub {
        $hub->send($e1);
        $hub->send($e2);
        $hub->send($e3);
    };

    my $do_check = sub {
        my $name = shift;

        my $old = $hub->format(My::Formatter->new);

        ok($old->isa('My::Formatter'), "old formatter");
        is_deeply(
            $old,
            [$e1, $e2, $e3],
            "Formatter got all events ($name)"
        );
    };

    if (CAN_REALLY_FORK) {
        my $pid = fork();
        die "Could not fork!" unless defined $pid;

        if ($pid) {
            is(waitpid($pid, 0), $pid, "waited properly");
            ok(!$?, "child exited with success");
            $hub->cull();
            $do_check->('Fork');
        }
        else {
            $do_send->();
            exit 0;
        }
    }

    if (CAN_THREAD && $] ge '5.010') {
        require threads;
        my $thr = threads->new(sub { $do_send->() });
        $thr->join;
        $hub->cull();
        $do_check->('Threads');
    }

    $do_send->();
    $hub->cull();
    $do_check->('no IPC');
};

tests listen => sub {
    my $hub = Test2::Hub->new();

    my @events;
    my @counts;
    my $it = $hub->listen(sub {
        my ($h, $e, $count) = @_;
        is_deeply($h, $hub, "got hub");
        push @events => $e;
        push @counts => $count;
    });

    my $second;
    my $it2 = $hub->listen(sub { $second++ });

    my $ok1 = Test2::Event::Ok->new(
        pass => 1,
        name => 'foo',
        trace => Test2::Context::Trace->new(
            frame => [ __PACKAGE__, __FILE__, __LINE__ ],
        ),
    );

    my $ok2 = Test2::Event::Ok->new(
        pass => 0,
        name => 'bar',
        trace => Test2::Context::Trace->new(
            frame => [ __PACKAGE__, __FILE__, __LINE__ ],
        ),
    );

    my $ok3 = Test2::Event::Ok->new(
        pass => 1,
        name => 'baz',
        trace => Test2::Context::Trace->new(
            frame => [ __PACKAGE__, __FILE__, __LINE__ ],
        ),
    );

    $hub->send($ok1);
    $hub->send($ok2);

    $hub->unlisten($it);

    $hub->send($ok3);

    is_deeply(\@counts, [1, 2], "Got counts");
    is_deeply(\@events, [$ok1, $ok2], "got events");
    is($second, 3, "got all events in listener that was not removed");

    like(
        exception { $hub->listen('xxx') },
        qr/listen only takes coderefs for arguments, got 'xxx'/,
        "listen takes a coderef"
    );
};

tests metadata => sub {
    my $hub = Test2::Hub->new();

    my $default = { foo => 1 };
    my $meta = $hub->meta('Foo', $default);
    is_deeply($meta, $default, "Set Meta");

    $meta = $hub->meta('Foo', {});
    is_deeply($meta, $default, "Same Meta");

    $hub->delete_meta('Foo');
    is($hub->meta('Foo'), undef, "No Meta");

    $hub->meta('Foo', {})->{xxx} = 1;
    is($hub->meta('Foo')->{xxx}, 1, "Vivified meta and set it");

    like(
        exception { $hub->meta(undef) },
        qr/Invalid key '\(UNDEF\)'/,
        "Cannot use undef as a meta key"
    );

    like(
        exception { $hub->meta(0) },
        qr/Invalid key '0'/,
        "Cannot use 0 as a meta key"
    );

    like(
        exception { $hub->delete_meta(undef) },
        qr/Invalid key '\(UNDEF\)'/,
        "Cannot use undef as a meta key"
    );

    like(
        exception { $hub->delete_meta(0) },
        qr/Invalid key '0'/,
        "Cannot use 0 as a meta key"
    );
};

tests filter => sub {
    my $hub = Test2::Hub->new();

    my @events;
    my $it = $hub->filter(sub {
        my ($h, $e) = @_;
        is($h, $hub, "got hub");
        push @events => $e;
        return $e;
    });

    my $count;
    my $it2 = $hub->filter(sub { $count++; $_[1] });

    my $ok1 = Test2::Event::Ok->new(
        pass => 1,
        name => 'foo',
        trace => Test2::Context::Trace->new(
            frame => [ __PACKAGE__, __FILE__, __LINE__ ],
        ),
    );

    my $ok2 = Test2::Event::Ok->new(
        pass => 0,
        name => 'bar',
        trace => Test2::Context::Trace->new(
            frame => [ __PACKAGE__, __FILE__, __LINE__ ],
        ),
    );

    my $ok3 = Test2::Event::Ok->new(
        pass => 1,
        name => 'baz',
        trace => Test2::Context::Trace->new(
            frame => [ __PACKAGE__, __FILE__, __LINE__ ],
        ),
    );

    $hub->send($ok1);
    $hub->send($ok2);

    $hub->unfilter($it);

    $hub->send($ok3);

    is_deeply(\@events, [$ok1, $ok2], "got events");
    is($count, 3, "got all events, even after other filter was removed");

    $hub = Test2::Hub->new();
    @events = ();

    $hub->filter(sub { undef });
    $hub->listen(sub {
        my ($hub, $e) = @_;
        push @events => $e;
    });

    $hub->send($ok1);
    $hub->send($ok2);
    $hub->send($ok3);

    ok(!@events, "Blocked events");

    like(
        exception { $hub->filter('xxx') },
        qr/filter only takes coderefs for arguments, got 'xxx'/,
        "filter takes a coderef"
    );
};

tests todo_system => sub {
    my $hub = Test2::Hub->new();

    {
        my $todo = $hub->set_todo('foo');
        ok($todo, "True");
        is($hub->get_todo, 'foo', "In todo");
    }

    is($hub->get_todo, undef, "Todo ended");

    my $todo = $hub->set_todo('foo');
    ok($todo, "True");
    is($hub->get_todo, 'foo', "In todo");
    $todo = undef;
    is($hub->get_todo, undef, "Todo ended");

    # Imitate Test::Builders todo:
    our $TODOX;
    {
        local $TODOX = $hub->set_todo('foo');
        ok($TODOX, "True");
        is($hub->get_todo, 'foo', "In todo");
    }
    is($hub->get_todo, undef, "Todo ended");

    my $warnings = warnings { $hub->set_todo('xxx') };
    like(
        $warnings->[0],
        qr/set_todo\Q(...)\E called in void context, todo not set!/,
        "Need to capture the todo!"
    );

    $warnings = warnings { my $todo = $hub->set_todo() },
    like(
        $warnings->[0],
        qr/set_todo\(\) called with undefined argument, todo not set!/,
        "Todo cannot be undef"
    );
};

done_testing;
