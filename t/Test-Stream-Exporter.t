use strict;
use warnings;

use Test::More;

{
    package My::Exporter;
    use Test::Stream::Exporter;
    use Test::More;
    use Carp qw/croak/;

    export         a => sub { 'a' };
    default_export b => sub { 'b' };

    export 'c';
    sub c { 'c' }

    default_export x => sub { 'x' };

    no Test::Stream::Exporter;

    sub export {
        croak "This is a custom sub";
    }

    ok(!__PACKAGE__->can($_), "removed $_\()") for qw/default_export exports default_exports/;
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

done_testing;
