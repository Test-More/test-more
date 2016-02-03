use Test2::Bundle::Extended -target => 'Test2::Workflow::Runner';

require Test2::Workflow::Meta;
use Test2::Util qw/get_tid/;

is($CLASS->instance->subtests, 1, "subtests enabled by default");

{
    package NO;
    use Test2::Bundle::Extended;
    # Make sure it doesn't die, it is mostly a no-op
    $main::CLASS->import;
    ok(!Test2::Workflow::Meta->get('NO'), "no meta for package 'NO'");

    package YES;
    use Test2::Bundle::Extended;
    my $meta = Test2::Workflow::Meta->build(
        __PACKAGE__,
        __FILE__,
        __LINE__,
        __LINE__,
    );
    $meta->set_autorun(0);
    ok(!$meta->runner, "no runner set");
    $main::CLASS->import;
    isa_ok($meta->runner, $main::CLASS);
}

my $unit = Test2::Workflow::Unit->new(
    name => 'foo',
    package => __PACKAGE__,
    file => __FILE__,
    start_line => __LINE__,
    end_line => __LINE__,
);

ok(lives { $CLASS->verify_meta($unit) }, "lack of meta is fine");

$unit->set_meta({});
ok(lives { $CLASS->verify_meta($unit) }, "empty meta is fine");

$unit->set_meta({todo => 'foo', skip => 'foo'});
ok(lives { $CLASS->verify_meta($unit) }, "All valid keys");

$unit->set_meta({todo => 'foo', skip => 'foo', foo => 'bar'});
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
    intercept { $CLASS->instance->run(unit => $unit, args => ['xxx'], no_final => 0) },
    array {
        event Ok => { pass => 0, effective_pass => 1 };
        event Note => {};
        event Note => { message => qr/Caught Exception: xxx/ };
    },
    "Caught exception (todo)"
);

$unit->set_meta({});
like(
    intercept { $CLASS->instance->run(unit => $unit, args => ['xxx'], no_final => 0) },
    array {
        fail_events Ok => { pass => 0, effective_pass => 0 };
        event Diag => { message => qr/Caught Exception: xxx/ };
    },
    "Caught exception"
);

$mock->reset_all;

is(
    intercept { $CLASS->instance->run(unit => $unit, args => ['xxx'], no_final => 0) },
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
    intercept { $CLASS->instance->run(unit => $unit, args => ['xxx'], no_final => 1) },
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
$CLASS->instance->run_task($task);
is($ran, 1, "ran task");

done_testing;
