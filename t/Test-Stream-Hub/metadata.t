use strict;
use warnings;
use Test::More;

use Test::Stream::Hub;
my $hub = Test::Stream::Hub->new();

my $default = { foo => 1 };
my $meta = $hub->meta('Foo', $default);
is($meta, $default, "Set Meta");

$meta = $hub->meta('Foo', {});
is($meta, $default, "Same Meta");

$hub->delete_meta('Foo');
is($hub->meta('Foo'), undef, "No Meta");

$hub->meta('Foo', {})->{xxx} = 1;
is($hub->meta('Foo')->{xxx}, 1, "Vivified meta and set it");

done_testing;
