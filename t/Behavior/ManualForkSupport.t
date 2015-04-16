use strict;
use warnings;
use Test::More tests => 3;

my $hub = Test::Stream->shared;
$hub->set_no_ending(1);
$hub->set_use_numbers(0);

if (my $pid = fork()) {
    ok(1, "PID $$");
    waitpid($pid, 0);
    ok(!$?, "Forked process exited cleanly indicating no warnings");
}
else {
    $SIG{__WARN__} = sub { print @_; exit 1 };
    ok(1, "PID $$");
    exit 0;
}

done_testing;
