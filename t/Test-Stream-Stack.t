use Test::Stream;
use Test::Stream::Stack;
use Test::Stream::Interceptor qw/lives dies/;

ok(my $stack = Test::Stream::Stack->new, "Create a stack");
isa_ok($stack, 'Test::Stream::Stack');

ok(!@$stack, "Empty stack");
ok(!$stack->peek, "Nothing to peek at");

ok(lives { $stack->cull },  "cull lives when stack is empty");
ok(lives { $stack->all },   "all lives when stack is empty");
ok(lives { $stack->clear }, "clear lives when stack is empty");

like(
    dies { $stack->pop(Test::Stream::Hub->new) },
    qr/No hubs on the stack/,
    "No hub to pop"
);

my $hub = Test::Stream::Hub->new;
ok($stack->push($hub), "pushed a hub");

like(
    dies { $stack->pop($hub) },
    qr/You cannot pop the root hub/,
    "Root hub cannot be popped"
);

$stack->push($hub);
like(
    dies { $stack->pop(Test::Stream::Hub->new) },
    qr/Hub stack mismatch, attempted to pop incorrect hub/,
    "Must specify correct hub to pop"
);

is_deeply(
    [ $stack->all ],
    [ $hub, $hub ],
    "Got all hubs"
);

ok(lives { $stack->pop($hub) }, "Popped the correct hub");

is_deeply(
    [ $stack->all ],
    [ $hub ],
    "Got all hubs"
);

is($stack->peek, $hub, "got the hub");
is($stack->top, $hub, "got the hub");

$stack->clear;

is_deeply(
    [ $stack->all ],
    [ ],
    "no hubs"
);

ok(my $top = $stack->top, "Generated a top hub");
is($top->ipc, Test::Stream::Sync->ipc, "Used sync's ipc");
isa_ok($top->format, 'Test::Stream::TAP');

is($stack->top, $stack->top, "do not generate a new top if there is already a top");

ok(my $new = $stack->new_hub(), "Add a new hub");
is($stack->top, $new, "new one is on top");
is($new->ipc, $top->ipc, "inherited ipc");
is($new->format, $top->format, "inherited formatter");

my $new2 = $stack->new_hub(formatter => undef, ipc => undef);
ok(!$new2->ipc, "built with no ipc");
ok(!$new2->format, "built with no formatter");

done_testing;
