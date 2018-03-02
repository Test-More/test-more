use Test2::Tools::Tiny;
use Data::GUID qw/guid_string/;

my $ug = Data::UUID->new;
Test2::API::test2_add_uuid_via(sub { $ug->create_str() });

my $count = $ENV{OK_COUNT} || 100000;
plan($count);

ok(1, "an ok") for 1 .. $count;

1;
