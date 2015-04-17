use strict;
use warnings;

use Test::More;
use Test::Stream::Meta qw/init_tester/;
my $META;
BEGIN { $META = init_tester('main') }

use ok 'Test::Stream::Context';

can_ok(__PACKAGE__, qw/context/);


# Made with 'new'
my $one = Test::Stream::Context->new(); my $frame = [ __PACKAGE__, __FILE__, __LINE__, 'Test::Stream::HashBase::new' ];
is($one->pid,      $$,       "default pid is current");
is($one->encoding, 'legacy', "default encoding");
is_deeply($one->frame, $frame, "Found place to report errors");
ok($one != context(), "context() does not find 'new' instance");
$one->set;
ok($one == context(), "context() does find 'new' instance after set");
$one->clear;
ok($one != context(), "context() does not find 'new' instance after clear");
ok(!$one->provider, "No provider");

#made with 'context'
my $two = context(); $frame = [ __PACKAGE__, __FILE__, __LINE__, 'Test::Stream::Context::context' ];
is($two->pid,      $$,       "default pid is current");
is($two->encoding, 'legacy', "default encoding");
is_deeply($two->frame, $frame, "Found place to report errors");

# Find existing instance
ok($one != $two, "2 different instances");
ok($two == context(), "context() returns the same instance again");
is(Test::Stream::Context->peek, $two, "Peek got existing instance");
ok(!$two->provider, "No provider");

# Test undef/collection
my $addr = "$two";
$two = undef;
is(Test::Stream::Context->peek, undef, "Peek did not find an instance");
$two = context();
ok("$two" ne $addr, "Got a new context after old was undef'd");
is(Test::Stream::Context->peek, $two, "Peek got existing instance");

# Hard Reset
Test::Stream::Context->clear;

# Test alert and throw
my $three = context(); $frame = [ __PACKAGE__, __FILE__, __LINE__, 'Test::Stream::Context::context' ];
ok(!$three->provider, "No provider");
my ($warning, $ret, $exception);
{
    local $SIG{__WARN__} = sub { $warning = shift };
    $three->alert("Hi there!");

    $ret = eval { $three->throw("Game Over"); 1 };
    $exception = $@;
}
ok(!$ret, "threw exception");
like($warning, qr/Hi there! at \Q$frame->[1]\E line \Q$frame->[2]\E/, "got warning from correct file+line");
like($exception, qr/Game Over at \Q$frame->[1]\E line \Q$frame->[2]\E/, "got exception from correct file+line");

is_deeply( [$three->call], $frame, "Call" );

is($three->package, $frame->[0], "got package");
is($three->file,    $frame->[1], "got file");
is($three->line,    $frame->[2], "got line");
is($three->subname, $frame->[3], "got subname");

my $snap = $three->snapshot;
is_deeply($three, $snap, "Identical!");
ok($three != $snap, "Not the same instance (may share references)");

is($three->meta, $META, "found metadata");

my @TODO;
$one->push_todo('foo');
push @TODO => $one->peek_todo;
push @TODO => $two->peek_todo;
push @TODO => $three->peek_todo;
$two->push_todo('bar');
push @TODO => $one->peek_todo;
push @TODO => $three->pop_todo;
push @TODO => $one->peek_todo;
$three->pop_todo;
push @TODO => $one->peek_todo;

# Check these here to make sure they are not themselves TODO
is( shift @TODO, 'foo', "got todo");
is( shift @TODO, 'foo', "todo is shared");
is( shift @TODO, 'foo', "todo is shared");
is( shift @TODO, 'bar', "got todo a");
is( shift @TODO, 'bar', "popped todo");
is( shift @TODO, 'foo', "still todo");
is( shift @TODO, undef, "no todo");

# Not exported by default
'Test::Stream::Context'->import('inspect_todo');
can_ok(__PACKAGE__, qw/inspect_todo/);

is_deeply(
    inspect_todo(__PACKAGE__),
    { TODO => [], PKG => undef, TB => undef, META => undef },
    "Nothing TODO"
);

{
    'Test::Stream::Context'->push_todo('TODO Context');
    local $TODO = 'TODO var';
    Test::Builder->new->todo_start('TODO TB');
    $META->set_todo('TODO Meta');

    my $todo_data = inspect_todo(__PACKAGE__);

    $TODO = undef;
    $META->set_todo(undef);
    Test::Builder->new->todo_end;
    'Test::Stream::Context'->pop_todo();

    is_deeply(
        $todo_data,
        {
            TODO => [ 'TODO Context' ],
            TB   => 'TODO TB',
            META => 'TODO Meta',
            PKG  => 'TODO var',
        },
        "Got all the TODOs!"
    );
}

is_deeply(
    inspect_todo(__PACKAGE__),
    { TODO => [], TB => undef, PKG => undef, META => undef },
    "Nothing TODO"
);


# Hard Reset
$one = undef;
$two = undef;
$three = undef;
Test::Stream::Context->clear;

############
# First sub to ask for a context() is the provider.
############

sub a_provider { context() }
$one = a_provider(); $frame = [ __PACKAGE__, __FILE__, __LINE__, 'main::a_provider' ];
is_deeply($one->frame, $frame, "Found place to report errors");
is_deeply($one->provider, [ __PACKAGE__, 'a_provider' ], "Found provider");
$one = undef;

sub not_a_provider {
    $frame = [ __PACKAGE__, __FILE__, __LINE__, 'main::a_provider' ]; a_provider();
}
$one = not_a_provider();
is_deeply($one->frame, $frame, "Found place to report errors");
is_deeply($one->provider, [ __PACKAGE__, 'a_provider' ], "Found provider");
$one = undef;

sub nested_provider {
    my $ctx = context();
    my $nest = not_a_provider();
    is($nest, $ctx, "nested ctx is same instance");
    return $ctx;
}
$one = nested_provider(); $frame = [ __PACKAGE__, __FILE__, __LINE__, 'main::nested_provider' ];
is_deeply($one->frame, $frame, "Found place to report errors");
is_deeply($one->provider, [ __PACKAGE__, 'nested_provider' ], "Found provider");
$one = undef;


sub run_todo {
    package FOO;
    my @CTX;

    sub a_provider { Test::Stream::Context::context() }

    push @CTX => a_provider()->snapshot();

    Test::Builder->new->todo_start('TODO TB');
    push @CTX => a_provider()->snapshot();

    {
        no warnings 'once';
        local $main::TODO = 'TODO tester';
        push @CTX => a_provider()->snapshot();
    }

    {
        no warnings 'once';
        local $FOO::TODO = 'TODO var';
        push @CTX => a_provider()->snapshot();
    }

    $META->set_todo('TODO Meta');
    push @CTX => a_provider()->snapshot();

    'Test::Stream::Context'->push_todo('TODO Context');
    push @CTX => a_provider()->snapshot();

    # Cleanup
    $META->set_todo(undef);
    Test::Builder->new->todo_end;
    'Test::Stream::Context'->pop_todo();

    return @CTX;
}

my @CTX = run_todo();

ok(!$CTX[0]->in_todo, "not in todo");
ok(!$CTX[0]->todo, "no todo message");
# This validates _find_tester
ok(!$CTX[0]->meta, "FOO is not a tester (main pkg meta was used to find todo)");

ok($CTX[1]->in_todo, "in todo (TB)");
is($CTX[1]->todo, "TODO TB", "todo message (TB)");

ok($CTX[2]->in_todo, "in todo (Tester)");
is($CTX[2]->todo, "TODO tester", "todo message (Tester)");

ok($CTX[3]->in_todo, "in todo (Package)");
is($CTX[3]->todo, "TODO var", "todo message (Package)");

ok($CTX[4]->in_todo, "in todo (Meta)");
is($CTX[4]->todo, "TODO Meta", "todo message (Meta)");

ok($CTX[5]->in_todo, "in todo (Context)");
is($CTX[5]->todo, "TODO Context", "todo message (Context)");



# Hard reset;
Test::Stream::Context->clear;

# Build with no tool
my $ctx = context()->snapshot; $frame = [ __PACKAGE__, __FILE__, __LINE__, 'Test::Stream::Context::context' ];
is_deeply($ctx->frame, $frame, "Got reasonable context when not called from tool (unexpected usage)");

$ctx = a_provider()->snapshot; $frame = [ __PACKAGE__, __FILE__, __LINE__, 'main::a_provider' ];
is_deeply($ctx->frame, $frame, "Got reasonable context when not called from tool (expected usage)");

{
    $Test::Builder::Level = $Test::Builder::Level + 1;
    $ctx = not_a_provider()->snapshot; $frame = [ __PACKAGE__, __FILE__, __LINE__, 'main::not_a_provider' ];
    is_deeply($ctx->frame, $frame, "Honor Test::Builder::Level");
}

my $ran_harder = 0;
{
    package Test::Builder;
    my $orig = Test::Stream::Context->can('_find_context_harder');
    no warnings 'redefine';
    local *Test::Stream::Context::_find_context_harder = sub { $ran_harder++; goto &$orig };
    sub provide { Test::Stream::Context::context()->snapshot }
    sub provide_2 { provide() };
    $ctx = provide_2();
}
is($ran_harder, 1, "Took a hard look");
is_deeply(
    $ctx->frame,
    ['<UNKNOWN>', '<UNKNOWN>', 0, '<UNKNOWN>'],
    "Could not find a context, Test::Builder nonsense (This never happens in practice)"
);

{ # Simulate an END block...
    package Test::Builder;
    local *END = sub { local *__ANON__ = 'END'; provide_2() };
    $ctx = END(); $frame = [ __PACKAGE__, __FILE__, __LINE__, 'Test::Builder::END' ];
}
is_deeply( $ctx->frame, $frame, 'Test::Builder context is ok in an end block');

sub deep_bad_level {
    local $Test::Builder::Level = 10;
    return Test::Stream::Context::context()->snapshot;
}
$ctx = deep_bad_level(); $frame = [ __PACKAGE__, __FILE__, __LINE__, 'main::deep_bad_level' ];
is_deeply($ctx->frame, $frame, "Legacy support, just find something sane");

done_testing;
