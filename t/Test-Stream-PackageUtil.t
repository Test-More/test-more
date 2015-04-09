use strict;
use warnings;

use Test::Stream;
use Test::More;

use ok 'Test::Stream::PackageUtil';

can_ok(__PACKAGE__, qw/package_sym package_purge_sym/);

my $ok = package_sym(__PACKAGE__, CODE => 'ok');
is($ok, \&ok, "package sym gave us the code symbol");

my $todo = package_sym(__PACKAGE__, SCALAR => 'TODO');
is($todo, \$TODO, "got the TODO scalar");

our $foo = 'foo';
our @foo = ('f', 'o', 'o');
our %foo = (f => 'oo');
sub foo { 'foo' };

is(foo(), 'foo', "foo() is defined");
is($foo, 'foo', '$foo is defined');
is_deeply(\@foo, [ 'f', 'o', 'o' ], '@foo is defined');
is_deeply(\%foo, { f => 'oo' }, '%foo is defined');

package_purge_sym(__PACKAGE__, CODE => 'foo');

is($foo, 'foo', '$foo is still defined');
is_deeply(\@foo, [ 'f', 'o', 'o' ], '@foo is still defined');
is_deeply(\%foo, { f => 'oo' }, '%foo is still defined');
my $r = eval { __PACKAGE__->foo() };
my $e = $@;
ok(!$r, "Failed to call foo()");
like($e, qr/Can't locate object method "foo" via package "main"/, "foo() is not defined anymore");
ok(!__PACKAGE__->can('foo'), "can() no longer thinks we can do foo()");

{
    package Foo;

    sub Bar { 'bar' };
    our $Bar = 'bar';
    our @Bar = ('b', 'a', 'r');
    our %Bar = (bar => 1);

    package Foo::Bar;
    sub xxx { 'xxx' };
}

package_purge_sym('Foo', CODE => 'Bar');
ok(!Foo->can('Bar'), "Removed CODE");
is($Foo::Bar, 'bar', 'SCALAR Preserved');
is_deeply(\@Foo::Bar, ['b', 'a', 'r'], 'ARRAY Preserved');
is_deeply(\%Foo::Bar, {bar => 1}, 'HASH Preserved');
can_ok('Foo::Bar', 'xxx');
is('Foo::Bar'->xxx, 'xxx', "nested namespace preserved");

done_testing;
