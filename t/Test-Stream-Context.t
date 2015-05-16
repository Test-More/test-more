use strict;
use warnings;

use Test::More;

use Test::Stream::Context qw/context TOP_HUB/;

can_ok(__PACKAGE__, qw/context/);

my $frame;

# Ironically, this is a bad idea in production.
sub tool { context() };

ok(!eval { context(); return; }, "Fails in void context");
my $exception = "context() called, but return value is ignored at " . __FILE__ . ' line ' . (__LINE__ - 1);
like($@, qr/^\Q$exception\E/, "Got the exception" );

my $one = tool()->snapshot; $frame = [ __PACKAGE__, __FILE__, __LINE__, 'main::tool' ];

my $two = tool(); $frame = [ __PACKAGE__, __FILE__, __LINE__, 'main::tool' ];
ok($two->hub, "Got a hub");
isa_ok($two->hub, 'Test::Stream::Hub');
is_deeply($two->debug->frame, $frame, "Found place to report errors");

# Find existing instance
ok($one != $two, "2 different instances");
ok($two == tool(), "context() returns the same instance again");

# Test undef/collection
my $addr = "$two";
$two = undef;
$two = tool();
ok("$two" ne $addr, "Got a new context after old was undef'd");

# Hard Reset
Test::Stream::Context->clear;

my $three = tool(); $frame = [ __PACKAGE__, __FILE__, __LINE__, 'main::tool' ];
my $snap = $three->snapshot;
is_deeply($three, $snap, "Identical!");
ok($three != $snap, "Not the same instance (may share references)");

# Hard Reset
$one = undef;
$two = undef;
$three = undef;
Test::Stream::Context->clear;

my $ctx;
{ # Simulate an END block...
    local *END = sub { local *__ANON__ = 'END'; context() };
    $ctx = END(); $frame = [ __PACKAGE__, __FILE__, __LINE__, 'main::END' ];
}
is_deeply( $ctx->debug->frame, $frame, 'context is ok in an end block');

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
$ctx = Test::Stream::Context->new(
    debug => $dbg,
    hub   => $hub,
);

my $e = $ctx->build_event('Ok', pass => 1, name => 'foo');
isa_ok($e, 'Test::Stream::Event::Ok');
is($e->pass, 1, "Pass");
is($e->name, 'foo', "got name");
is_deeply($e->debug, $dbg, "Got the debug info");
ok(!@$events, "No events yet");

$e = $ctx->send_event('Ok', pass => 1, name => 'foo');
isa_ok($e, 'Test::Stream::Event::Ok');
is($e->pass, 1, "Pass");
is($e->name, 'foo', "got name");
is_deeply($e->debug, $dbg, "Got the debug info");
is(@$events, 1, "1 event");
is_deeply($events, [$e], "Hub saw the event");
pop @$events;

$e = $ctx->ok(1, 'foo');
isa_ok($e, 'Test::Stream::Event::Ok');
is($e->pass, 1, "Pass");
is($e->name, 'foo', "got name");
is_deeply($e->debug, $dbg, "Got the debug info");
is(@$events, 1, "1 event");
is_deeply($events, [$e], "Hub saw the event");
pop @$events;

$e = $ctx->note('foo');
isa_ok($e, 'Test::Stream::Event::Note');
is($e->message, 'foo', "got message");
is_deeply($e->debug, $dbg, "Got the debug info");
is(@$events, 1, "1 event");
is_deeply($events, [$e], "Hub saw the event");
pop @$events;

$e = $ctx->diag('foo');
isa_ok($e, 'Test::Stream::Event::Diag');
is($e->message, 'foo', "got message");
is_deeply($e->debug, $dbg, "Got the debug info");
is(@$events, 1, "1 event");
is_deeply($events, [$e], "Hub saw the event");
pop @$events;

$e = $ctx->plan(100);
isa_ok($e, 'Test::Stream::Event::Plan');
is($e->max, 100, "got max");
is_deeply($e->debug, $dbg, "Got the debug info");
is(@$events, 1, "1 event");
is_deeply($events, [$e], "Hub saw the event");
pop @$events;

Test::Stream::Context->clear;
my $todo = TOP_HUB->set_todo("Here be dragons");
my $dbg1 = tool()->debug;
$todo = undef;
my $dbg2 = tool()->debug;

is($dbg1->todo, 'Here be dragons', "Got todo in context created with todo in place");
is($dbg2->todo, undef, "no todo in context created after todo was removed");

done_testing;

# This is necessary cause we have a root hub that will set the exit code to 255
# since no tests were run for it :-)
TOP_HUB->set_no_ending(1);
