use Test2::Bundle::Extended -target => 'Test2::Workflow::Meta';

my $events = intercept {
    def ok => (!$CLASS->get('Foo'), "no meta for Foo yet");
    my $one = $CLASS->build('Foo', 'Foo.pm', 1, 'EOF');
    def ref_is => ($one, $CLASS->build('Foo'), "Returns the first ref on sequencial builds");
    def ref_is => ($one, $CLASS->get('Foo'), "Can retrieve build");
    def is => ($one->autorun, 1, "autorun by default");
    def ok => ($one->unit, "added a unit");

    $one->unit->set_primary(sub { ok(1, 'inside') });

    done_testing;
};

do_def;

is(
    $events,
    array {
        event Ok => { pass => 1, name => 'inside' };
        event Plan => { max => 1 };
        end;
    },
    "Ran the base unit"
);

my $meta = $CLASS->build('Bar', 'Bar.pm', 1, 10);
ref_is($CLASS->get('Bar'), $meta, "met is set");
$meta->purge();
ok(!$CLASS->get('Bar'), "meta purged directly");

$meta = $CLASS->build('Bar', 'Bar.pm', 1, 10);
ref_is($CLASS->get('Bar'), $meta, "met is set");
$CLASS->purge('Bar');
ok(!$CLASS->get('Bar'), "meta purged through class");

like(
    dies { $CLASS->purge() },
    qr/You must specify a package to purge/,
    "Nothing to purge"
);

$meta = $CLASS->build('Bar', 'Bar.pm', 1, 10);
$meta->set_unit(undef);
like(
    dies { $meta->purge() },
    qr/You must specify a package to purge/,
    "Can't find package"
);

$CLASS->purge('Bar');

done_testing;
