use strict;
use warnings;

use Test::More;

use ok 'Test::Stream::State';

my $state = 'Test::Stream::State'->new;

can_ok($state, qw/count failed ended is_passing plan/);

is($state->count, 0, "count starts at 0");
is($state->failed, 0, "failed starts at 0");
is($state->is_passing, 1, "start off passing");
is($state->plan, undef, "no plan yet");

$state->is_passing(0);
is($state->is_passing, 0, "Can Fail");

$state->is_passing(1);
is($state->is_passing, 1, "Passes again");

$state->bump(1);
is($state->count, 1, "Added a passing result");
is($state->failed, 0, "still no fails");
is($state->is_passing, 1, "Still passing");

$state->bump(0);
is($state->count, 2, "Added a result");
is($state->failed, 1, "new failure");
is($state->is_passing, 0, "Not passing");

$state->is_passing(1);
is($state->is_passing, 0, "is_passing always false after a failure");

$state->set_failed(0);
$state->is_passing(1);
is($state->is_passing, 1, "Passes again");

$state->bump_fail();
is($state->count, 2, "No new result");
is($state->failed, 1, "new failure");
is($state->is_passing, 0, "Not passing");

my $file = __FILE__;
my ($fline, $sline) = (__LINE__ + 1, __LINE__ + 2);
$state->finish([__PACKAGE__, __FILE__, __LINE__]);
my $ok = eval { $state->finish([__PACKAGE__, __FILE__, __LINE__]); 1 };
my $err = $@;
ok(!$ok, "died");

is($err, <<EOT, "Got expected error");
Test already ended!
First End:  $file line $fline
Second End: $file line $sline
EOT

ok(!eval { $state->plan('foo'); 1 }, "Could not set plan to 'foo'");
like($@, qr/'foo' is not a valid plan! Plan must be an integer greater than 0, 'NO PLAN', or 'SKIP'/, "Got expected error");

ok($state->plan(5), "Can set plan to integer");
is($state->plan, 5, "Set the plan to an integer");

$state->set__plan(undef);
ok($state->plan('NO PLAN'), "Can set plan to 'NO PLAN'");
is($state->plan, 'NO PLAN', "Set the plan to 'NO PLAN'");

$state->set__plan(undef);
ok($state->plan('SKIP'), "Can set plan to 'SKIP'");
is($state->plan, 'SKIP', "Set the plan to 'SKIP'");

ok(!eval { $state->plan(5); 1 }, "Cannot change plan");
like($@, qr/You cannot change the plan/, "Got error");

done_testing;
