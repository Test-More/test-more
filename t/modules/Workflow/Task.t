use Test::Stream -V1, Intercept, Compare => '*', Class => ['Test::Stream::Workflow::Task'];
use Test::Stream::Workflow::Runner;

use Test::Stream::Workflow qw/has_workflow_vars/;

like(
    dies { $CLASS->new },
    qr/Attribute 'unit' is required/,
    "must provide unit"
);

my $unit = mock;
my $one = $CLASS->new(unit => $unit);
isa_ok($one, $CLASS);
ref_ok($one->args, 'ARRAY', "args created automatically");
is($one->stage, $CLASS->STAGE_BUILDUP(), "set stage");
is($one->_buildup_idx, 0, "buildup idx set to 0");
is($one->_teardown_idx, 0, "teardown idx set to 0");
is($one->failed, 0, "0 failures");
is($one->events, 0, "0 events");
is($one->pending, 0, "0 pending iterations");
is($one->exception, undef, "no exception");

for (qw/stage _buildup_idx _teardown_idx failed events pending/) {
    my $method = "set_$_";
    $one->$method(1);
}

$one->reset;
is($one->stage, $CLASS->STAGE_BUILDUP(), "set stage");
is($one->_buildup_idx, 0, "buildup idx set to 0");
is($one->_teardown_idx, 0, "teardown idx set to 0");
is($one->failed, 0, "0 failures");
is($one->events, 0, "0 events");
is($one->pending, 0, "0 pending iterations");
is($one->exception, undef, "no exception");

{
    my $ran = 0;
    my $mock = mock $CLASS => (override => { iterate => sub { $ran++ }});
    my $code = \&{$one};
    ref_ok($code, 'CODE', "code overloading");
    $code->();
    is($ran, 1, "ran iterate");
}

ok(!$one->finished, "not finished");
$one->set_exception(1);
ok($one->finished, "finished due to exception");
$one->set_exception(0);
$one->set_stage($one->STAGE_COMPLETE());
ok($one->finished, "finished due to complete");

$one->reset;

is($one->subtest, 1, "subtest by default");
$one->set_no_final(1);
is($one->subtest, 0, "no subtest without final");
$one->set_no_final(0);
$one->set_no_subtest(1);
is($one->subtest, 0, "no subtest when disabled");
$one->set_no_subtest(0);


ok(!$one->_have_primary, "no primary");
$unit->primary('x');
ok(!$one->_have_primary, "not a ref for primary");
$unit->primary({});
ok(!$one->_have_primary, "wrong ref for primary");
$unit->primary([]);
ok(!$one->_have_primary, "empty array for primary");
$unit->primary(sub { 1 });
ok($one->_have_primary, "sub is a valid primary");
$unit->primary([1]);
ok($one->_have_primary, "populated array as primary");
$unit->primary(undef);


{
    local $ENV{TS_WORKFLOW};
    my $control = $unit->{'~~MOCK~CONTROL~~'};
    $control->add('contains' => sub { 0 });
    ok($one->should_run, "no request, so just run");
    $ENV{TS_WORKFLOW} = 'foo';
    $one->set_no_final(1);
    ok($one->should_run, "no_final always run");

    $one->set_no_final(0);
    ok(!$one->should_run, "should not run");

    $control->override('contains' => sub { 1 });
    ok($one->should_run, "Run if the unit matches");
    $control->reset('contains');
}

$one->set_stage($one->STAGE_COMPLETE);
ok(!$one->run, "already complete is a no-op");
$one->reset;

{
    my $mock = mock $CLASS => (
        override => { should_run => sub { 0 } },
    );
    ok(!$one->run, "no-op due to should_run being 0");
}

my $debug = Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'none']);
my $new_ctx = sub {
    return Test::Stream::Context->new(
        debug => $debug,
        hub   => Test::Stream::Sync->stack->top,
    );
};
$unit->{'~~MOCK~CONTROL~~'}->add( context => $new_ctx );

$one->reset;
$unit->name('bob');
warns { $debug->set_skip('foo') };

is(
    intercept { $one->run },
    array {
        event Skip => sub {
            call name   => 'bob';
            call reason => 'foo';
        };
        end;
    },
    "Got the skip event"
);
is($one->stage, $one->STAGE_COMPLETE, "stage set to complete after skip");

$one->reset;
warns { $debug->set_skip(undef) };

$unit->primary(undef);
is(
    intercept { $one->run },
    array {
        event Ok => sub {
            call name => 'bob';
            call pass => 0;
            call diag => array {
                match qr/Failed/,
                'No primary actions defined! Nothing to do!'
            }
        };
        end;
    },
    "Got failure from lack of actions"
);
is($one->stage, $one->STAGE_COMPLETE, "stage set to complete after failure");

$one->reset;
$unit->primary(sub { 1 });

{
    my $events = 0;
    my $ok = 1;
    my $ran = 0;
    my $subtest = 0;
    my $vars = undef;
    my $mock = mock $CLASS;
    $mock->override(iterate => sub {
        $ran++;
        $vars = has_workflow_vars();
        return unless $events;
        ok($ok);
        my $self = shift;
        $self->{events}++;
        $self->{failed}++ unless $ok;
    });
    $mock->override(subtest => sub { $subtest });

    is(
        intercept { $one->run },
        array { event Ok => { pass => 0, name => 'bob', diag => [ match qr/Failed/, 'No events were generated' ] } },
        "Need events"
    );
    ok($vars, "added vars");

    $one->reset;
    $one->set_no_final(1);
    is(
        intercept { $one->run },
        array { end },
        "Do not need events with no_final"
    );
    $one->set_no_final(0);
    ok(!$vars, "did not add vars");

    $one->reset;
    $subtest = 1;
    is(
        intercept { $one->run },
        array { event Ok => { pass => 0, name => 'bob', diag => [ match qr/Failed/, 'No events were generated' ] } },
        "Need events even in subtest"
    );

    $one->reset;
    $events = 1;
    $ran = 0;
    is(
        intercept { $one->run },
        array { event Subtest => { pass => 1, name => 'bob' } },
        "Got subtest event (pass)"
    );
    is($ran, 1, "ran the iteration");

    $one->reset;
    $ok = 0;
    $ran = 0;
    is(
        intercept { $one->run },
        array { event Subtest => { pass => 0, name => 'bob' } },
        "Got subtest event (fail)"
    );
    is($ran, 1, "ran the iteration");

    $one->reset;
    $ran = 0;
    $subtest = 0;
    $ok = 1;
    $one->set_no_final(0);
    is(
        intercept { $one->run },
        array { event Ok => { pass => 1 }; event Ok => { pass => 1, name => 'bob' }; end },
        "Got inner event + bob"
    );
    is($ran, 1, "ran the iteration");

    $one->reset;
    $ran = 0;
    $subtest = 0;
    $ok = 1;
    $one->set_no_final(1);
    is(
        intercept { $one->run },
        array { event Ok => { pass => 1 }; end },
        "Got inner event only"
    );
    is($ran, 1, "ran the iteration");

    $one->set_no_final(0);
    $one->reset;
    $ran = 0;
    $ok = 0;
    is(
        intercept { $one->run },
        array {
            event Ok => { pass => 0 };
            event Ok => { pass => 0, name => 'bob' };
            end;
        },
        "Got failure event"
    );
    is($ran, 1, "ran the iteration");

    $one->set_no_final(1);
    $one->reset;
    $ran = 0;
    $ok = 0;
    is(
        intercept { $one->run },
        array {
            event Ok => { pass => 0 };
            event Ok => { pass => 0, name => 'bob' };
            end;
        },
        "Got failure event"
    );
    is($ran, 1, "ran the iteration");

    $one->reset;
}

{
    my %ran;
    my $mock = mock $CLASS;
    $mock->override(
        _run_buildups  => sub { $ran{buildup}++ },
        _run_primaries => sub { $ran{primary}++ },
        _run_teardowns => sub { $ran{teardown}++ },
    );
    $one->set_stage($one->STAGE_COMPLETE);
    $one->set_pending(1);
    ok(!$one->iterate, 'no-op');
    is($one->pending, 0, "not pending anymore");
    ok(!$ran{buildup}, "did not run buildups");
    ok(!$ran{primary}, "did not run primaries");
    ok(!$ran{teardown}, "did not run teardowns");

    $one->reset;
    $one->iterate;
    ok($ran{buildup}, "ran buildups");
    ok(!$ran{primary}, "did not run primaries");
    ok(!$ran{teardown}, "did not run teardowns");

    %ran = ();
    $one->reset;
    $one->set_stage($one->STAGE_PRIMARY);
    $one->iterate;
    ok(!$ran{buildup}, "did not run buildups");
    ok($ran{primary}, "ran primaries");
    ok(!$ran{teardown}, "did not run teardowns");

    %ran = ();
    $one->reset;
    $one->set_stage($one->STAGE_TEARDOWN);
    $one->iterate;
    ok(!$ran{buildup}, "did not run buildups");
    ok(!$ran{primary}, "did not run primaries");
    ok($ran{teardown}, "ran teardowns");

    %ran = ();
    $mock->override(_run_buildups => sub { die 'xxx' });
    $one->reset;
    is(
        intercept { $one->iterate },
        array {
            event Exception => { error => match qr/xxx/ };
        },
        "Got exception event"
    );
    like($one->exception, qr/xxx/, "stored exception");
    is($one->failed, 1, "recorded failure");
}

# Test that these have the shortcut exit with stage advancement
$one->reset;
$unit->buildup(undef);
$unit->teardown(undef);
$one->runner('FAKE'); # Make sure recursion kills
$one->_run_buildups;
is($one->stage, $one->STAGE_PRIMARY, "advanced stage, but no work done");
$one->_run_teardowns;
is($one->stage, $one->STAGE_COMPLETE, "advanced stage, but no work done");

$one->reset;
my $child1 = mock { name => 'child1' };
my $child2 = mock { name => 'child2' };
$child1->{'~~MOCK~CONTROL~~'}->add( context => $new_ctx );
$child2->{'~~MOCK~CONTROL~~'}->add( context => $new_ctx );

$unit->buildup([$child1, $child2]);
my @calls;
$one->set_runner('Fake::Runner');
my $runner = mock 'Fake::Runner' => (
    add => {
        run => sub {
            push @calls => [@_];
        },
    },
);
$one->set_args(['x']);
$one->_run_buildups();

is(
    \@calls,
    array {
        item array {
            item 'Fake::Runner';
            item 'unit'; item exact_ref $child1;
            item 'no_final'; item 1;
            item 'args'; item ['x'];
            end;
        };
        item array {
            item 'Fake::Runner';
            item 'unit'; item exact_ref $child2;
            item 'no_final'; item 1;
            item 'args'; item ['x'];
            end;
        };
        end;
    },
    "Called twice, with expected args"
);
is($one->stage, $one->STAGE_PRIMARY(), "bumped stage");

@calls = ();
$one->reset;
$child1->wrap(1);
$child2->wrap(1);
$runner->override(
    run => sub {
        push @calls => [@_, pending => $one->pending];
        $one->set_pending(0);
        ok($one->stage != $one->STAGE_PRIMARY(), "stage not bumped yet");
        $one->_run_buildups;
    },
);
$one->_run_buildups();
is(
    \@calls,
    array {
        item array {
            item 'Fake::Runner';
            item 'unit'; item exact_ref $child1;
            item 'no_final'; item 1;
            item 'args'; item [$one];
            item 'pending'; item 1;
            end;
        };
        item array {
            item 'Fake::Runner';
            item 'unit'; item exact_ref $child2;
            item 'no_final'; item 1;
            item 'args'; item [$one];
            item 'pending'; item 1;
            end;
        };
        end;
    },
    "Called twice, with expected args, recursed"
);
is($one->stage, $one->STAGE_PRIMARY(), "bumped stage");

$one->reset;
$runner->override(run => sub { 1 });
is(
    intercept { $one->_run_buildups },
    array {
        event Ok => { pass => 0, name => 'child1', diag => [ match qr/Failed/, match qr/Inner sub was never called/ ]};
        event Ok => { pass => 0, name => 'child2', diag => [ match qr/Failed/, match qr/Inner sub was never called/ ]};
        end;
    },
    "Got failed event from not running inner sub"
);

$runner->override(
    run => sub {
        push @calls => [@_];
    },
);

@calls = ();
$one->reset;
$child1->wrap(0);
$child2->wrap(0);
$unit->teardown([$child2, $child1]);
$one->_run_teardowns;
is(
    \@calls,
    array {
        item array {
            item 'Fake::Runner';
            item 'unit'; item exact_ref $child2;
            item 'no_final'; item 1;
            item 'args'; item ['x'];
            end;
        };
        item array {
            item 'Fake::Runner';
            item 'unit'; item exact_ref $child1;
            item 'no_final'; item 1;
            item 'args'; item ['x'];
            end;
        };
        end;
    },
    "Called twice, with expected args"
);
is($one->stage, $one->STAGE_COMPLETE, "complete");

@calls = ();
$child1->wrap(1);
$child2->wrap(1);
$one->reset;
$one->_run_teardowns;
is(
    \@calls,
    array { end },
    "Just return"
);
ok($one->stage != $one->STAGE_COMPLETE, "not done yet");

$one->_run_teardowns;
is(
    \@calls,
    array { end },
    "Just return again"
);
ok($one->stage != $one->STAGE_COMPLETE, "not done yet");

$one->_run_teardowns;
is(
    \@calls,
    array { end },
    "Nothing to run this time"
);
is($one->stage, $one->STAGE_COMPLETE, "Done!");


$one->reset;
$one->set_no_final(0);
my $l = $one->_listener;
$l->(undef, mock { causes_fail => 0 });
is($one->events, 1, "1 event");
is($one->failed, 0, "0 failures");
$l->(undef, mock { causes_fail => 1 });
is($one->events, 2, "2 event");
is($one->failed, 1, "1 failures");
$l->(undef, mock { causes_fail => 0 });
is($one->events, 3, "3 event");
is($one->failed, 1, "1 failures");


$one->reset;
$one->set_no_final(1);
$unit->wrap(0);
$l = $one->_listener;
$l->(undef, mock { causes_fail => 0 });
is($one->events, 1, "1 event");
is($one->failed, 0, "0 failures");
$l->(undef, mock { causes_fail => 1 });
is($one->events, 2, "2 event");
is($one->failed, 1, "1 failures");
$l->(undef, mock { causes_fail => 0 });
is($one->events, 3, "3 event");
is($one->failed, 1, "1 failures");


my $ran = 0;
$one->reset;
$one->set_no_final(0);
$unit->wrap(0);
$unit->modify(undef);
$unit->primary(sub { ok(1); ok(0); $ran++ });
is(
    intercept { $one->_run_primaries },
    array {
        event Ok => { pass => 1 };
        event Ok => { pass => 0 };
    },
    "Got expected events"
);
is($ran, 1, "ran once");
is($one->failed, 1, "1 failure");
is($one->events, 2, "2 events");
is($one->stage, $one->STAGE_TEARDOWN(), "set stage");


@calls = ();
$ran = 0;
my $mod_ran = 0;
my $mod = Test::Stream::Workflow::Unit->new(
    primary => sub { ok(1, 'first'); $mod_ran++ },
    name => 'foo',
    package => __PACKAGE__,
    file => __FILE__,
    start_line => __LINE__,
    end_line => __LINE__,
);
$one->reset;
$one->set_runner('Test::Stream::Workflow::Runner');
$one->set_no_final(0);
$unit->wrap(0);
$unit->modify([$mod]);
$unit->primary(sub { ok(1, 'second'); ok(0, 'third'); $ran++ });
is(
    intercept { $one->_run_primaries },
    array {
        event Subtest => sub {
            call subevents => array {
                event Ok => { pass => 1, name => 'first' };
                event Ok => { pass => 1, name => 'second' };
                event Ok => { pass => 0, name => 'third' };
            };
        };
    },
    "Got expected events"
);
is($ran, 1, "ran once");
is($mod_ran, 1, "ran mod");
is($one->failed, 1, "1 failure");
is($one->events, 2, "2 events");
is($one->stage, $one->STAGE_TEARDOWN(), "set stage");


@calls = ();
$ran = 0;
$mod_ran = 0;
my $prim = Test::Stream::Workflow::Unit->new(
    primary => sub { ok(1, 'second'); ok(0, 'third'); $ran++ },
    name => 'foo',
    package => __PACKAGE__,
    file => __FILE__,
    start_line => __LINE__,
    end_line => __LINE__,
);
$one->reset;
$one->set_runner('Test::Stream::Workflow::Runner');
$one->set_no_final(0);
$unit->wrap(0);
$unit->modify([$mod]);
$unit->primary([$prim]);
is(
    intercept { $one->_run_primaries },
    array {
        event Subtest => sub {
            call subevents => array {
                event Ok => { pass => 1, name => 'first' };
                event Subtest => sub {
                    call subevents => array {
                        event Ok => { pass => 1, name => 'second' };
                        event Ok => { pass => 0, name => 'third' };
                    };
                };
            };
        };
    },
    "Got expected events"
);
is($ran, 1, "ran once");
is($mod_ran, 1, "ran mod");
is($one->failed, 1, "1 failure");
is($one->events, 1, "1 events");
is($one->stage, $one->STAGE_TEARDOWN(), "set stage");

done_testing;
