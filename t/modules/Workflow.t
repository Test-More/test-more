use Test2::Bundle::Extended -target => 'Test2::Workflow';

use Test2::Workflow qw{
    workflow_build
    workflow_current
    workflow_meta
    workflow_runner
    workflow_runner_args
    workflow_var
    workflow_run
    new_proto_unit
    group_builder
    gen_unit_builder
    push_workflow_build
    pop_workflow_build
    push_workflow_vars
    pop_workflow_vars
    has_workflow_vars
};

{
    package Bar;
    use Test2::Tools::Exports;
    use Test2::Workflow ':all';
    imported_ok(qw/
        workflow_build
        workflow_current
        workflow_meta
        workflow_runner
        workflow_runner_args
        workflow_var
        workflow_run
        new_proto_unit
        group_builder
        gen_unit_builder
        push_workflow_build
        pop_workflow_build
        push_workflow_vars
        pop_workflow_vars
        has_workflow_vars

        tool_import
        tool_unimport
    /);

    use base 'Exporter';
    our @EXPORT = qw/foo/;
    sub foo { 'foo' }

    package Baz;
    use Test2::Workflow ':all';

    use Test2::Tools::Basic;
    use Test2::Tools::Exports;
    use Test2::Tools::Compare;
    use Test2::Tools::Mock;

    Bar->tool_import();
    imported_ok(qw/foo/);
    is(foo(), 'foo', "got foo");
    Bar->tool_unimport;

    ok(workflow_meta(), "got meta");
    workflow_runner('foo');
    workflow_runner_args(['foo']);

    is(workflow_meta()->runner, 'foo', "set runner");
    is(workflow_meta()->runner_args, ['foo'], "set runner args");
}

ok(Test2::Workflow::Meta->get('Baz'), "Baz got a workflow");
ok(!Test2::Workflow::Meta->get('Baz')->autorun, "unimported (autoload set to false)");

is(workflow_build(), undef, "No Build");
like( dies { push_workflow_build() }, qr/Nothing to push/, "Nothing to push" );
my $it = push_workflow_build({});
like(dies { pop_workflow_build({}) }, qr/Build stack mismatch/, "Wrong build");
like(dies { pop_workflow_build() }, qr/Build stack mismatch/, "no arg build");
is(workflow_build, $it, "got build");
is(pop_workflow_build($it), $it, "popped the build");
like(dies { pop_workflow_build({}) }, qr/Build stack mismatch/, "no build");

ok(!has_workflow_vars, "no workflow vars");
my $vars = push_workflow_vars();
ref_ok($vars, 'HASH', "pushed a hashref for us");
ok(has_workflow_vars, "have vars");
my $vars2 = {};
push_workflow_vars($vars2);
is(has_workflow_vars, 2, "2 vars in the stack");
like(
    dies { pop_workflow_vars($vars) },
    qr/Vars stack mismatch!/,
    "Cannot pop wrong vars"
);
like(
    dies { pop_workflow_vars() },
    qr/Vars stack mismatch!/,
    "Need vars to pop"
);

is(workflow_var('foo'), undef, "var foo not set");
workflow_var(foo => 42);
is(workflow_var('foo'), 42, "var was set");
workflow_var(foo => 0);
is(workflow_var('foo'), 0, "var was set to 0");
workflow_var('foo', sub { 'apple' });
is(workflow_var('foo'), 0, "not reset");
is(workflow_var('bar', sub { 'apple' }), 'apple', "setting var");
is(workflow_var('bar'), 'apple', "set var");
workflow_var('baz' => {});
ref_ok(workflow_var('baz'), 'HASH', "set baz to ref");

pop_workflow_vars($vars2);

is(workflow_var('foo'), undef, "var foo not set");
is(workflow_var('bar'), undef, "var bar not set");
is($vars2, {}, "vars were all cleared");

is(has_workflow_vars, 1, "1 left");
pop_workflow_vars($vars);
ok(!has_workflow_vars, "no more vars");
like(
    dies { pop_workflow_vars() },
    qr/Vars stack mismatch!/,
    "Nothing on the stack"
);
like(
    dies { workflow_var('foo') },
    qr/No VARS! workflow_var\(\) should only be called inside a unit sub/,
    "no vars"
);

ok(!workflow_current, "no current workflow");
my $meta = Test2::Workflow::Meta->build(__PACKAGE__, __FILE__, __LINE__, __LINE__);
$meta->set_autorun(0);
ref_is(workflow_current, $meta->unit, "got workflow from package");
$it = push_workflow_build({});
ref_is(workflow_current, $it, "got build from BUILD");
pop_workflow_build($it);
$meta->purge();

my $file = __FILE__;
my $line = __LINE__ + 2;
is(
    dies { sub { Test2::Workflow::die_at_caller([caller()], 'foo bar') }->() },
    "foo bar at $file line $line.\n",
    "Threw error at caller"
);

sub wrap_proto_unit { new_proto_unit(@_) }

like(
    dies { wrap_proto_unit(args => [1, 2, 3]) },
    qr/wrap_proto_unit\(\) only accepts 2 line number arguments per call \(got: 1, 2, 3\)/,
    "Line number limit"
);

like(
    dies { wrap_proto_unit(args => [qw/foo bar/]) },
    qr/wrap_proto_unit\(\) only accepts 1 name argument per call \(got: 'foo', 'bar'\)/,
    "Only 1 name"
);

like(
    dies { wrap_proto_unit(args => [[]]) },
    qr/Unknown argument to wrap_proto_unit: ARRAY/,
    "Invalid arg ref"
);

like(
    dies { wrap_proto_unit(args => [{}, {}]) },
    qr/wrap_proto_unit\(\) only accepts 1 meta-hash argument per call/,
    "Only 1 meta hash"
);

like(
    dies { wrap_proto_unit(args => [sub { 1 }, sub { 2 }]) },
    qr/wrap_proto_unit\(\) only accepts 1 coderef argument per call/,
    "Only 1 coderef"
);

like(
    dies { wrap_proto_unit(args => [sub { 1 }]) },
    qr/wrap_proto_unit\(\) requires a name argument \(non-numeric string\)/,
    "Must have a name"
);

like(
    dies { wrap_proto_unit(args => ['foo']) },
    qr/wrap_proto_unit\(\) requires a code reference/,
    "Must have a coderef"
);

my $sub = sub { 1 };
my ($unit, $block, $caller) = wrap_proto_unit(args => ['foo', {foo => 1}, $sub]);
isa_ok($unit, 'Test2::Workflow::Unit');
like($caller, [__PACKAGE__, __FILE__, __LINE__ - 2, qr/wrap_proto_unit$/], "Got caller");
is($unit->meta, { foo => 1 }, "set meta");
is($unit->name, 'foo', "set name");
ok(!$unit->primary, "sub is not primary");

($unit, $block, $caller) = new_proto_unit(args => ['foo', $sub], level => 0, unit => {type => 'group'}, set_primary => 1);
isa_ok($unit, 'Test2::Workflow::Unit');
like($caller, [__PACKAGE__, __FILE__, __LINE__ - 2, qr/new_proto_unit$/], "Got caller with specified level");
is($unit->meta, {}, "no meta");
is($unit->type, 'group', "set unit params");
is($unit->primary, $sub, "sub is primary");

my @args;
my $build;
my $want = 'foo';
$unit = group_builder(foo => {foo => 'foo'}, sub { $want = wantarray; @args = @_; $build = workflow_build() });
isa_ok($unit, 'Test2::Workflow::Unit');
ref_is($build, $unit, "got unit as build in sub");
ref_is($args[0], $unit, "got unit as arg");
is($want, undef, "sub called in void context");

like(
    dies { group_builder(foo => sub { die 'uhg' }) },
    qr/uhg/,
    "exception in callback is propogated"
);

ok(!workflow_build, "build stack is consistent");

like(
    dies { group_builder(foo => sub { 1 }) },
    qr/Could not find the current build!/,
    "Void context, but no build!"
);

my $subref = sub { 1 };
my $current = mock;
push_workflow_build($current);
group_builder(foo => $subref);
pop_workflow_build($current);
like($current->{add_primary}, object { prop blessed => 'Test2::Workflow::Unit' }, "added primary");

$unit = {unit => 1};
$current = mock;
$CLASS->can('_unit_builder_callback_simple')->($current, $unit, qw/foo bar baz/);
like($current, {add_foo => $unit, add_bar => $unit, add_baz => $unit}, "callback worked as expected on current");

$current = mock;
my $mods_cb = $CLASS->can('_unit_builder_callback_modifiers');
$mods_cb->($current, $unit, qw/foo bar baz/);
ref_ok($current->add_post, 'CODE', "added post hook");
ok(!$current->add_post->(), "No-Op");

my $child = mock;
$current->modify([$child]);
$current->add_post->();
like($child, {add_foo => $unit, add_bar => $unit, add_baz => $unit}, "callback worked as expected on child");

$current = mock {type => 'group'};
$current->stash({});
my $prim_cb = $CLASS->can('_unit_builder_callback_primaries');
$prim_cb->($current, $unit, qw/buildup teardown/);
is($current->stash, {$CLASS => {buildup => [$unit], teardown => [$unit]}}, "Stash is prepared");
ref_ok($current->add_post, 'CODE', "Added post hook");

my $child1 = mock {type => 'anything'};
my $child2 = mock {primary => [mock {}], type => 'group'};
my $child3 = mock {modify => ['a'], buildup => ['a'], primary => ['a'], teardown => ['a']};
$current->primary([$child1, $child2, $child3]);

$current->add_post->();

ok(!$current->{modify}, "not added to current");
ok(!$current->{buildup}, "not added to current");
ok(!$current->{teardown}, "not added to current");
ok(!$child2->{modify}, "not added to child2");
ok(!$child2->{buildup}, "not added to child2");
ok(!$child2->{teardown}, "not added to child2");

like(
    $child1,
    {
        buildup  => [$unit],
        teardown => [$unit],
        modify   => DNE,
        primary  => DNE,
    },
    "child 1"
);
like(
    $child2,
    {
        primary => [{
            buildup  => [$unit],
            teardown => [$unit],
            modify   => DNE,
            primary  => DNE,
        }],
    },
    "child 2"
);
like(
    $child3,
    {
        buildup  => [$unit, 'a'],
        teardown => ['a', $unit],
        modify   => ['a'],
        primary  => ['a'],
    },
    "child 3, order in which things are added (push vs unshift)"
);
is($current->stash, {}, "stash restored");

$prim_cb->($current, $unit, qw/modify primary/);
is($current->stash, {$CLASS => {modify => [$unit], primary => [$unit]}}, "Stash is prepared");
ref_ok($current->add_post, 'CODE', "Added post hook");
$current->add_post->();

like(
    $child1,
    {
        buildup  => [$unit],
        teardown => [$unit],
        modify   => [$unit],
        primary  => [$unit],
    },
    "child 1"
);
like(
    $child2,
    {
        primary => [{
            buildup  => [$unit],
            teardown => [$unit],
            modify   => [$unit],
            primary  => [$unit],
        }],
    },
    "child 2"
);
like(
    $child3,
    {
        buildup  => [$unit, 'a'],
        teardown => ['a', $unit],
        modify   => [$unit, 'a'],
        primary  => ['a', $unit],
    },
    "child 3, order in which things are added (push vs unshift)"
);

is($current->stash, {}, "stash restored");

like(
    dies { gen_unit_builder() },
    qr/'callback' is a required argument/,
    "Must have callback"
);
like(
    dies { gen_unit_builder(callback => 'foo') },
    qr/'stashes' is a required argument/,
    "Invalid callback (string)"
);

like(
    dies { gen_unit_builder(callback => 'foo', stashes => []) },
    qr/'foo' is not a valid callback/,
    "Invalid callback (string)"
);
like(
    dies { gen_unit_builder(callback => {}, stashes => []) },
    qr/'HASH.*' is not a valid callback/,
    "Invalid callback (hash)"
);
like(
    dies { gen_unit_builder(callback => sub {}, stashes => 'foo') },
    qr/'stashes' must be an array reference \(got: foo\)/,
    "bad stash"
);
like(
    dies { gen_unit_builder(callback => 'simple', stashes => ['foo', 'bar']) },
    qr/'bar\+foo' is not a valid stash/,
    "bad stash"
);

my $gen = gen_unit_builder(callback => sub { @args = @_; }, stashes => ['primary']);
ref_ok($gen, 'CODE', "got a code ref");

like(
    dies { my $x = $gen->('foo', {apple => 1}, sub { 1 }) },
    qr/must only be called in a void context/,
    "void context only"
);

like(
    dies { $gen->('foo', {apple => 1}, sub { 1 }) },
    qr/Could not find the current build!/,
    "need a build"
);

$current = push_workflow_build({});
$gen->('foo', {apple => 1}, sub { 1 });
pop_workflow_build($current);
like(
    \@args,
    array {
        item exact_ref $current;
        item object {
            prop blessed => 'Test2::Workflow::Unit';
            call type => 'single';
            call wrap => F();
        };
        item 'primary';
        end;
    },
    "Got expected args"
);

$gen = gen_unit_builder(callback => sub { @args = @_; }, stashes => ['buildup', 'teardown']);
$current = push_workflow_build({});
$gen->('foo', {apple => 1}, sub { 1 });
pop_workflow_build($current);
like(
    \@args,
    array {
        item exact_ref $current;
        item object {
            prop blessed => 'Test2::Workflow::Unit';
            call type => 'single';
            call wrap => T();
        };
        item 'buildup';
        item 'teardown';
        end;
    },
    "Got expected args for wrap"
);

done_testing;
