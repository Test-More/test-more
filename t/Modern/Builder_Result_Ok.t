use strict;
use warnings;

use Test::More 'modern';

require_ok 'Test::Builder::Result::Ok';

isa_ok('Test::Builder::Result::Ok', 'Test::Builder::Result');

can_ok('Test::Builder::Result::Ok', qw/bool real_bool name todo skip/);

my $one = Test::Builder::Result::Ok->new(
    trace => {report => {file => 'fake.t', line => 42, package => 'Fake::Fake'}},
    bool => 1,
    real_bool => 1,
    name => 'fake',
    in_todo => 0,
    todo => undef,
    skip => undef,
);

is($one->to_tap(1), "ok 1 - fake\n", "TAP output, success");

$one->bool(0);
$one->real_bool(0);
is($one->to_tap(), "not ok - fake\n", "TAP output, fail");

$one->real_bool(1);
$one->in_todo(1);
$one->todo("Blah");
is($one->to_tap(), "ok - fake # TODO Blah\n", "TAP output, todo");

$one->in_todo(0);
$one->todo(undef);
$one->skip("Don't do it!");
is($one->to_tap(), "ok - fake # skip Don't do it!\n", "TAP output, skip");

$one->in_todo(1);
$one->todo("Don't do it!");
$one->skip("Don't do it!");
is($one->to_tap(), "ok - fake # TODO & SKIP Don't do it!\n", "TAP output, skip + todo");

$one->skip("Different");
ok( !eval { $one->to_tap; 1}, "Different reasons dies" );
like( $@, qr{^2 different reasons to skip/todo: \$VAR1}, "Useful message" );

done_testing;

