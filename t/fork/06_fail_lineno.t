use strict;
use warnings;
use Test::More tests => 2;
use Test::SharedFork;
use File::Temp qw/tempfile/;

local $ENV{LANG} = "C";

my $out = do {
    open my $fh, ">", \my $out or die $!;
    my $test = Test::Builder->create();
    $test->output($fh);
    $test->failure_output($fh);
    $test->todo_output($fh);
    $test->ok(0);
    $out;
};

unlike($out, qr{lib/Test/SharedFork});
like($out, qr{t/06_fail_lineno.t line \d+\.});

