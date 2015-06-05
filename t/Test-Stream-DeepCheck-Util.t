use strict;
use warnings;

use Test::More;

use Test::Stream::DeepCheck::Util qw/yada render_var/;

is(${yada()}, '...', "yada");

ok(yada == yada, "always returns the same ref.");

is(render_var(undef), "undef", "Rendered undef");
is(render_var(undef, 1), "undef", "Rendered undef, strigify has no effect");

is(render_var(yada), '...', 'rendered yada');
is(render_var(yada, 1), '...', 'rendered yada, stringify has no effect');

my $ref = {};

is(render_var($ref), "$ref", "ref");
is(render_var($ref, 1), "'$ref'", "ref is wrapped in quotes if stringify is requested");

is(render_var(1), '1', "Numbers are not normally quoted");
is(render_var(1.5), '1.5', "Numbers are not normally quoted");
is(render_var(1, 1), "'1'", "Numbers are quoted when stringify is requested");

is(render_var('foo'), "'foo'", "strings always get quotes");
is(render_var('foo', 1), "'foo'", "strings always get quotes");

done_testing;
