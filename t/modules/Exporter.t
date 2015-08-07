use strict;
use warnings;

use Test::Stream;

{
    package My::Exporter;
    use Test::Stream::Exporter;
    use Test::Stream;
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
is_deeply(
    [sort @{$meta->default}],
    [sort qw/b x/],
    "Got default list"
);

is_deeply(
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
    use Test::Stream;
    My::Exporter->import('-all');
    can_ok(__PACKAGE__, qw/a b c x/);

    package Temp2;
    use Test::Stream;
    My::Exporter->import('-all', c => {-as => 'cc'});
    can_ok(__PACKAGE__, qw/a b cc x/);
    ok(!__PACKAGE__->can('c'), "did not import under old name");
}

done_testing;
