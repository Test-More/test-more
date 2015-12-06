use Test::Stream -V1, -Tester;

use Test::Stream::Context qw/context release/;

can_ok(__PACKAGE__, qw/context release/);

my $error = dies { context(); 1 };
my $exception = "context() called, but return value is ignored at " . __FILE__ . ' line ' . (__LINE__ - 1);
like($error, qr/^\Q$exception\E/, "Got the exception" );

my $ref;
my $frame;
sub wrap(&) {
    my $ctx = context();
    my ($pkg, $file, $line, $sub) = caller(0);
    $frame = [$pkg, $file, $line, $sub];

    $_[0]->($ctx);

    $ref = "$ctx";

    $ctx->release;
}

wrap {
    my $ctx = shift;
    ok($ctx->hub, "got hub");
    isa_ok($ctx->hub, 'Test::Stream::Hub');
    delete $ctx->debug->frame->[4];
    is($ctx->debug->frame, $frame, "Found place to report errors");
};

wrap {
    my $ctx = shift;
    ok("$ctx" ne "$ref", "Got a new context");
    my $new = context();
    ok($ctx == $new, "Additional call to context gets same instance");
    delete $ctx->debug->frame->[4];
    is($ctx->debug->frame, $frame, "Found place to report errors");
    $new->release;
};

wrap {
    my $ctx = shift;
    my $snap = $ctx->snapshot;
    is($ctx, $snap, "snapshot is identical");
    ok($ctx != $snap, "snapshot is a new instance");
};

my $end_ctx;
{ # Simulate an END block...
    local *END = sub { local *__ANON__ = 'END'; context() };
    my $ctx = END(); $frame = [ __PACKAGE__, __FILE__, __LINE__, 'main::END' ];
    $end_ctx = $ctx->snapshot;
    $ctx->release;
}
delete $end_ctx->debug->frame->[4];
is( $end_ctx->debug->frame, $frame, 'context is ok in an end block');

sub release_test_single {
    my $ctx = context();
    release $ctx, 42;
}

sub release_test_list {
    my $ctx = context();
    release $ctx, 42, 42;
}

sub release_test_array {
    my $ctx = context();
    my @foo = (42, 42);
    release $ctx, @foo;
}

sub stuff { 'stuff', 'more stuff' };

sub release_test_call {
    my $ctx = context();
    release $ctx, stuff();
}

is(
    release_test_single(),
    42,
    "Got scalar value"
);

is(
    [release_test_list()],
    [42, 42],
    "Got list"
);

is(
    [release_test_array()],
    [42, 42],
    "Got array values"
);

is(
    [release_test_call()],
    ['stuff', 'more stuff'],
    "Got return from called sub"
);

# Test event generation
{
    package My::Formatter;

    sub write {
        my $self = shift;
        my ($e) = @_;
        push @$self => $e;
    }
}
my $events = bless [], 'My::Formatter';
my $hub = Test::Stream::Hub->new(
    formatter => $events,
);
my $dbg = Test::Stream::DebugInfo->new(
    frame => [ 'Foo::Bar', 'foo_bar.t', 42, 'Foo::Bar::baz' ],
);
my $ctx = Test::Stream::Context->new(
    debug => $dbg,
    hub   => $hub,
);

my $e = $ctx->build_event('Ok', pass => 1, name => 'foo');
isa_ok($e, 'Test::Stream::Event::Ok');
is($e->pass, 1, "Pass");
is($e->name, 'foo', "got name");
is($e->debug, $dbg, "Got the debug info");
ok(!@$events, "No events yet");

$e = $ctx->send_event('Ok', pass => 1, name => 'foo');
isa_ok($e, 'Test::Stream::Event::Ok');
is($e->pass, 1, "Pass");
is($e->name, 'foo', "got name");
is($e->debug, $dbg, "Got the debug info");
is(@$events, 1, "1 event");
is($events, [$e], "Hub saw the event");
pop @$events;

$e = $ctx->ok(1, 'foo');
isa_ok($e, 'Test::Stream::Event::Ok');
is($e->pass, 1, "Pass");
is($e->name, 'foo', "got name");
is($e->debug, $dbg, "Got the debug info");
is(@$events, 1, "1 event");
is($events, [$e], "Hub saw the event");
pop @$events;

$e = $ctx->note('foo');
isa_ok($e, 'Test::Stream::Event::Note');
is($e->message, 'foo', "got message");
is($e->debug, $dbg, "Got the debug info");
is(@$events, 1, "1 event");
is($events, [$e], "Hub saw the event");
pop @$events;

$e = $ctx->diag('foo');
isa_ok($e, 'Test::Stream::Event::Diag');
is($e->message, 'foo', "got message");
is($e->debug, $dbg, "Got the debug info");
is(@$events, 1, "1 event");
is($events, [$e], "Hub saw the event");
pop @$events;

$e = $ctx->plan(100);
isa_ok($e, 'Test::Stream::Event::Plan');
is($e->max, 100, "got max");
is($e->debug, $dbg, "Got the debug info");
is(@$events, 1, "1 event");
is($events, [$e], "Hub saw the event");
pop @$events;

# Test todo (deprecated)
my ($dbg1, $dbg2);
my $todo = Test::Stream::Sync->stack->top->set_todo("Here be dragons");
wrap { $dbg1 = shift->debug };
$todo = undef;
wrap { $dbg2 = shift->debug };

is($dbg1->_todo, 'Here be dragons', "Got todo in context created with todo in place");
is($dbg2->_todo, undef, "no todo in context created after todo was removed");


# Test hooks

my @hooks;
$hub =  Test::Stream::Sync->stack->top;
my $ref1 = $hub->add_context_init(sub { push @hooks => 'hub_init' });
my $ref2 = $hub->add_context_release(sub { push @hooks => 'hub_release' });
Test::Stream::Context->ON_INIT(sub { push @hooks => 'global_init' });
Test::Stream::Context->ON_RELEASE(sub { push @hooks => 'global_release' });

sub {
    push @hooks => 'start';
    my $ctx = context(on_init => sub { push @hooks => 'ctx_init' }, on_release => sub { push @hooks => 'ctx_release' });
    push @hooks => 'deep';
    my $ctx2 = sub {
        context(on_init => sub { push @hooks => 'ctx_init_deep' }, on_release => sub { push @hooks => 'ctx_release_deep' });
    }->();
    push @hooks => 'release_deep';
    $ctx2->release;
    push @hooks => 'release_parent';
    $ctx->release;
    push @hooks => 'released_all';

    push @hooks => 'new';
    $ctx = context(on_init => sub { push @hooks => 'ctx_init2' }, on_release => sub { push @hooks => 'ctx_release2' });
    push @hooks => 'release_new';
    $ctx->release;
    push @hooks => 'done';
}->();

$hub->remove_context_init($ref1);
$hub->remove_context_release($ref2);
@Test::Stream::Context::ON_INIT = ();
@Test::Stream::Context::ON_RELEASE = ();

is(
    \@hooks,
    [qw{
        start
        global_init
        hub_init
        ctx_init
        deep
        release_deep
        release_parent
        ctx_release_deep
        ctx_release
        hub_release
        global_release
        released_all
        new
        global_init
        hub_init
        ctx_init2
        release_new
        ctx_release2
        hub_release
        global_release
        done
    }],
    "Got all hook in correct order"
);

{
    my $ctx = context(level => -1);

    local $@ = 'testing error';
    my $one = Test::Stream::Context->new(
        debug => Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'blah']),
        hub => Test::Stream::Sync->stack->top,
    );
    is($one->_err, 'testing error', "Copied \$@");
    is($one->_depth, 0, "default depth");

    my $ran = 0;
    my $doit = sub {
        is(\@_, [qw/foo bar/], "got args");
        is(context(), $one, "The one context is our context");
        $ran++;
        die "Make sure old context is restored";
    };

    eval { $one->do_in_context($doit, 'foo', 'bar') };
    is(context(level => -1, wrapped => -2), $ctx, "Old context restored");
    $ctx->release;

    ok(lives { $one->do_in_context(sub {1}) }, "do_in_context works without an original")
}

{
    my $warnings;
    my $exit;
    sub {
        my $ctx = context();

        local $? = 0;
        $warnings = warns { Test::Stream::Context::_do_end() };
        $exit = $?;

        $ctx->release;
    }->();

    {
        my $line = __LINE__ - 3;
        my $file = __FILE__;
        is(
            $warnings,
            [
                "context object was never released! This means a testing tool is behaving very badly at $file line $line.\n"
            ],
            "Warned about unfreed context"
        );

        is($exit, 255, "set exit code to 255");
    }
}

{
    like(dies { Test::Stream::Context->new() }, qr/The 'debug' attribute is required/, "need to have debug");

    my $debug = Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'foo']);
    like(dies { Test::Stream::Context->new(debug => $debug) }, qr/The 'hub' attribute is required/, "need to have hub");

    my $hub = Test::Stream::Sync->stack->top;
    my $ctx = Test::Stream::Context->new(debug => $debug, hub => $hub);
    is($ctx->{_depth}, 0, "depth set to 0 when not defined.");

    $ctx = Test::Stream::Context->new(debug => $debug, hub => $hub, _depth => 1);
    is($ctx->{_depth}, 1, "Do not reset depth");

    like(
        dies { $ctx->release },
        qr/release\(\) should not be called on a non-canonical context/,
        "Non canonical context, do not release"
    );
    ok(!$ctx, "ctx still destroyed from bad release");
}

sub {
    my $caller = [caller(0)];
    my $ctx = context();

    my $warnings = warns { $ctx = undef };
    my @parts = split /^\n/m, $warnings->[0];
    is(
        \@parts,
        [
            <<"            EOT",
Context was not released! Releasing at destruction\.
Context creation details:
  Package: main
     File: $caller->[1]
     Line: $caller->[2]
     Tool: $caller->[3]
            EOT
            match qr/Trace: .*/,
        ],
        "Got warning about unreleased context"
    );

    ok(@$warnings == 1, "Only 1 warning");
}->();

sub {
    like(
        dies { my $ctx = context(level => 20) },
        qr/Could not find context at depth 21/,
        "Level sanity"
    );

    ok(
        lives {
            my $ctx = context(level => 20, fudge => 1);
            $ctx->release;
        },
        "Was able to get context when fudging level"
    );
}->();

{
    my $warnings;
    sub {
        my ($ctx1, $ctx2);
        sub { $ctx1 = context() }->();

        my @warnings;
        {
            local $SIG{__WARN__} = sub { push @warnings => @_ };
            $ctx2 = context();
            $ctx1 = undef;
        }

        $ctx2->release;

        is(
            \@warnings,
            [
                match qr/^context\(\) was called to retrieve an existing context, however the existing/,
            ],
            "Got expected warning"
        );
    }->();
}

sub {
    my $ctx = context();
    my $e = dies { $ctx->throw('xxx') };
    ok(!$ctx, "context was destroyed");
    like($e, qr/xxx/, "got exception");

    $ctx = context();
    like(warning { $ctx->alert('xxx') }, qr/xxx/, "got warning");
    $ctx->release;
}->();

sub {
    my $ctx = context;
    my $clone = $ctx;
    $ctx = $clone->snapshot;
    $clone->release;

    is($ctx->_parse_event('Ok'), 'Test::Stream::Event::Ok', "Got the Ok event class");
    is($ctx->_parse_event('+Test::Stream::Event::Ok'), 'Test::Stream::Event::Ok', "Got the +Ok event class");

    like(
        dies { $ctx->_parse_event('+DFASGFSDFGSDGSD') },
        qr/Could not load event module 'DFASGFSDFGSDGSD': Can't locate DFASGFSDFGSDGSD\.pm/,
        "Bad event type"
    );
}->();

{
    my ($e1, $e2);
    intercept {
        my $ctx = context();
        $e1 = $ctx->ok(0, 'foo', ['xxx']);
        $e2 = $ctx->ok(0, 'foo');
        $ctx->release;
    };

    like(
        $e1->diag,
        [
            qr/Failed test 'foo'/,
            'xxx',
        ],
        "Chekc diag"
    );

    like(
        $e2->diag,
        [
            qr/Failed test 'foo'/,
        ],
        "Chekc diag"
    );
}

done_testing;
