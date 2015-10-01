use Test::Stream -V1, Capabilities, Intercept, Compare => '*', Class => ['Test::Stream::Workflow::Runner'];
require Test::Stream::Workflow::Meta;
use Test::Stream::Util qw/get_tid/;

is($CLASS->subtests, 1, "subtests enabled by default");

{
    package NO;
    use Test::Stream -V1;
    # Make sure it doesn't die, it is mostly a no-op
    $main::CLASS->import;
    ok(!Test::Stream::Workflow::Meta->get('NO'), "no meta for package 'NO'");

    package YES;
    use Test::Stream -V1;
    my $meta = Test::Stream::Workflow::Meta->build(
        __PACKAGE__,
        __FILE__,
        __LINE__,
        __LINE__,
    );
    $meta->set_autorun(0);
    ok(!$meta->runner, "no runner set");
    $main::CLASS->import;
    is($meta->runner, $main::CLASS, "runner set");
}

my $unit = Test::Stream::Workflow::Unit->new(
    name => 'foo',
    package => __PACKAGE__,
    file => __FILE__,
    start_line => __LINE__,
    end_line => __LINE__,
);

ok(lives { $CLASS->verify_meta($unit) }, "lack of meta is fine");

$unit->set_meta({});
ok(lives { $CLASS->verify_meta($unit) }, "empty meta is fine");

$unit->set_meta({todo => 'foo', skip => 'foo', iso => 1});
ok(lives { $CLASS->verify_meta($unit) }, "All valid keys");

$unit->set_meta({todo => 'foo', skip => 'foo', iso => 1, foo => 'bar'});
like(
    warning { $CLASS->verify_meta($unit) },
    qr/'foo' is not a recognised meta-key/,
    "Got warning for bad key"
);

my $mock = mock $CLASS => (
    override => {
        run_task => sub { die 'xxx' },
    },
);
my @call;
$unit->set_primary(sub { ok(1); @call = @_ });

$unit->set_meta({todo => 1});
like(
    intercept { $CLASS->run(unit => $unit, args => ['xxx'], no_final => 0) },
    array {
        event Ok => { pass => 0, effective_pass => 1, diag => array {
            item 1 => qr/Caught Exception: xxx/,
        }};
    },
    "Caught exception (todo)"
);

$unit->set_meta({});
like(
    intercept { $CLASS->run(unit => $unit, args => ['xxx'], no_final => 0) },
    array {
        event Ok => { pass => 0, effective_pass => 0, diag => array {
            item 1 => qr/Caught Exception: xxx/,
        }};
    },
    "Caught exception"
);

$mock->reset_all;

is(
    intercept { $CLASS->run(unit => $unit, args => ['xxx'], no_final => 0) },
    array {
        event Subtest => sub {
            call pass => 1;
            call subevents => array {
                event Ok => { pass => 1 };
                event Plan => { max => 1 };
                end;
            };
        };
        end;
    },
    "finalized"
);
is(\@call, ['xxx'], "got args in sub");

is(
    intercept { $CLASS->run(unit => $unit, args => ['xxx'], no_final => 1) },
    array {
        event Ok => { pass => 1 };
        end;
    },
    "not finalized"
);
is(\@call, ['xxx'], "got args in sub");

my $ran = 0;
my $task = mock { unit => $unit };
$task->{'~~MOCK~CONTROL~~'}->add(run => sub { $ran++ });
$unit->set_meta({});
$CLASS->run_task($task);
is($ran, 1, "ran task");

if ($CLASS->isolate) {
    $ran = 0;
    $unit->set_meta({iso => 1});
    $task->{'~~MOCK~CONTROL~~'}->override(run => sub {
        ok(1, "Event");
        $ran++;
    });

    my $events = intercept { $CLASS->run_task($task) };
    is(
        $events,
        array {
            event Ok => sub {
                call pass => 1;
                call name => 'Event';
            };
        },
        "got event"
    );
    is($ran, 0, "ran was not altered locally due to isolation mechanism");

    if ($CLASS->isolate eq 'fork_task' || threads->can('error')) {
        $task->{'~~MOCK~CONTROL~~'}->override(run => sub {
            $ran++;
            die "XXX $$";
        });
        $events = intercept { $CLASS->run_task($task) };
        like(
            $events,
            array {
                event Exception => { error => qr/XXX/ };
            },
            "got exception event"
        );
    }
}

{
    $ran = 0;
    $unit->set_meta({iso => 1});
    $task->{'~~MOCK~CONTROL~~'}->override(run => sub {
        ok(1, "Event");
        $ran++;
    });

    my $mock = mock $CLASS => (
        override => {
            isolate => sub { undef },
        },
    );

    my $events = intercept { $CLASS->run_task($task) };
    is(
        $events,
        array {
            event Ok => sub {
                call pass => 1;
                call name => $unit->name;
                prop skip => 'No way to isolate task!';
            };
        },
        "Skipped"
    );
    is($ran, 0, "ran was not altered locally due to isolation mechanism");
}



done_testing;
