use Test::Stream -V1;
use Test::Stream::Exporter::Meta;

my $META = 'Test::Stream::Exporter::Meta';

is($META->EXPORTS, 'exports', "exports constant");
is($META->PACKAGE, 'package', "package constant");
is($META->DEFAULT, 'default', "default constant");

like(
    dies { $META->new('') },
    qr/Package is required/,
    "Must provide a package"
);

is( $META->get('Temp1'), undef, "No meta for Temp1" );
my $one = $META->new('Temp1');
isa_ok($one, $META);
ref_is($one, $META->get('Temp1'), 'get returns the meta for Temp1');
is(
    $one,
    {
        exports => {},
        default => [],
        package => 'Temp1',
    },
    "Object is as expected"
);

is($one->exports, {}, "no exports");
is($one->default, [], "no defaults");
is($one->package, 'Temp1', "got the package");

sub Temp1::c { 1 }
my $ref = sub { 1 };
$one->add(0, 'a', $ref);
$one->add(1, 'b', $ref);
$one->add(0, 'c');

is(
    $one->exports,
    {
        a => $ref,
        b => $ref,
        c => Temp1->can('c'),
    },
    "Added Exports"
);

is(
    $one->default,
    ['b'],
    "added the default"
);

like(
    dies { $one->add(0, undef, $ref) },
    qr/Name is mandatory/,
    "Must have name"
);

like(
    dies { $one->add(0, 'a', $ref) },
    qr/a is already exported/,
    "Can't export the same name twice"
);

like(
    dies { $one->add(0, 'd') },
    qr/No reference or package sub found for 'd' in 'Temp1'/,
    "Need something to export"
);

sub Temp1::da { 1 }
sub Temp1::db { 1 }
sub Temp1::dc { 1 }
sub Temp1::dd { 1 }
sub Temp1::na { 1 }
sub Temp1::nb { 1 }
sub Temp1::nc { 1 }
sub Temp1::nd { 1 }

$one->add_bulk(
    1,
    qw/ da db dc dd /,
);

$one->add_bulk(
    0,
    qw/ na nb nc nd /,
);

like(
    dies { $one->add_bulk(0, 'da') },
    qr/da is already exported/,
    "Can't add it more than once"
);

like(
    dies { $one->add_bulk(0, 'ooo') },
    qr/No reference or package sub found for 'ooo' in 'Temp1'/,
    "Can't add it more than once"
);

is(
    $one->exports,
    {
        a => $ref,
        b => $ref,
        c => Temp1->can('c'),
        da => Temp1->can('da'),
        db => Temp1->can('db'),
        dc => Temp1->can('dc'),
        dd => Temp1->can('dd'),
        na => Temp1->can('na'),
        nb => Temp1->can('nb'),
        nc => Temp1->can('nc'),
        nd => Temp1->can('nd'),
    },
    "Added Exports"
);

is(
    $one->default,
    [qw/b da db dc dd/],
    "added the default"
);

done_testing;
