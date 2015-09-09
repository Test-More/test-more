use Test::Stream -V1;

{
    package My::Exporter;
    use Test::Stream::Exporter;
    use Test::Stream -V1;
    use Carp qw/croak/;

    export         a => sub { 'a' };
    default_export b => sub { 'b' };

    our $default_export = 100;
    {
        package My::Exporter::default_export;
        sub here { 1 };
    }

    sub export_from { 1 };

    export 'c';
    sub c { 'c' }

    default_export x => sub { 'x' };

    no Test::Stream::Exporter;

    sub export {
        croak "This is a custom sub";
    }

    ok(!__PACKAGE__->can($_), "removed $_\()") for qw/default_export exports default_exports/;
    ok(__PACKAGE__->can('export_from'), "Did not remove a custom sub with a conflicting name");
    is($My::Exporter::default_export, 100, "Did not remove other glob items");
    can_ok('My::Exporter::default_export', 'here');
    is('My::Exporter::default_export'->here, 1, "Did not remove package of same name as sub");
}

My::Exporter->import;
can_ok(__PACKAGE__, qw/x b/);

My::Exporter->import(qw/a c/);
can_ok(__PACKAGE__, qw/a b c x/);

My::Exporter->import();
can_ok(__PACKAGE__, qw/a b c x/);

is(__PACKAGE__->$_(), $_, "$_() eq '$_', Function is as expected") for qw/a b c x/;

my $meta = Test::Stream::Exporter::Meta::get('My::Exporter');
isa_ok($meta, 'Test::Stream::Exporter::Meta');
is(
    [sort @{$meta->default}],
    [sort qw/b x/],
    "Got default list"
);

is(
    $meta->exports,
    {
        a => __PACKAGE__->can('a'),
        b => __PACKAGE__->can('b'),
        c => __PACKAGE__->can('c'),
        x => __PACKAGE__->can('x'),
    },
    "Exports are what we expect"
);

my ($error, $return);
{
  local $@;
  $return = eval { My::Exporter->export; 1 };
  $error = $@;
}
ok( !$return, 'Custom fatal export sub died as expected');
like( $error, qr/This is a custom sub/, 'Custom fatal export sub died as expected with the right message');

My::Exporter->import(a => { -as => 'aaa' }, a => { -as => 'xxx' });
is(aaa(), 'a', "imported under an alternative name 1");
is(xxx(), 'a', "imported under an alternative name 2");

{
    package Temp1;
    use Test::Stream -V1;
    My::Exporter->import('-all');
    can_ok(__PACKAGE__, qw/a b c x/);

    package Temp2;
    use Test::Stream -V1;
    My::Exporter->import('-all', c => {-as => 'cc'});
    can_ok(__PACKAGE__, qw/a b cc x/);
    ok(!__PACKAGE__->can('c'), "did not import under old name");

    package Temp3;
    use Test::Stream -V1;
    My::Exporter->import('-default');
    can_ok(__PACKAGE__, qw/b x/);
    ok(!__PACKAGE__->can('a'), "did not import a");
    ok(!__PACKAGE__->can('c'), "did not import c");

    package Temp4;
    use Test::Stream -V1;
    for my $f (qw/export exports default_export default_exports/) {
        my $fc = Test::Stream::Exporter->can($f);
        like(
            dies { $fc->('x') },
            qr/Temp4 is not an exporter!\?/,
            "Cannot call $f from non-exporter"
        );
    }
}

Test::Stream::Exporter::export_from('My::Exporter', 'Temp5', []);
can_ok('Temp5', qw/b x/);

Test::Stream::Exporter::export_from('My::Exporter', 'Temp6');
can_ok('Temp6', qw/b x/);

like(
    dies { Test::Stream::Exporter::export_from('My::Exporter', 'Temp7', ['fake']) },
    qr/"fake" is not exported by the My::Exporter module/,
    "Bad export name"
);

like(
    dies { Test::Stream::Exporter::export_from('My::Exporter', 'Temp7', ['a' => []]) },
    qr/import options must be specified as a hashref, got 'ARRAY/,
    "Bad export options type"
);

like(
    dies { Test::Stream::Exporter::export_from('My::Exporter', 'Temp7', ['a' => {-foo => 1}]) },
    qr/'-foo' is not a valid export option for export 'a'/,
    "Bad export options type"
);

Test::Stream::Exporter::export_from('My::Exporter', 'Temp7', ['a' => {-as => 'A', -prefix => 'pre_', -postfix => '_post'}]);
can_ok('Temp7', 'pre_A_post');

Test::Stream::Exporter::export_from('My::Exporter', 'Temp7', ['x' => {}]);
can_ok('Temp7', 'x');

{
    package Temp8;
    use Test::Stream -V1;
    use Test::Stream::Exporter;
    BEGIN { imported_ok('export') };
    no Test::Stream::Exporter qw/export/;
    BEGIN { not_imported_ok('export') };
}

done_testing;
