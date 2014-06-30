use strict;
use warnings;
use Test::More qw/modern/;
use Test::Tester2;

ok(1, "Result in parent" );

if (my $pid = fork()) {
    waitpid($pid, 0);
    cull();
}
else {
    ok(1, "Result in child");
    exit 0;
}

is(Test::Builder::Stream->shared->tests_run, 2, "Got the forked result");

helpers qw/my_ok/;
sub my_ok { Test::Builder->new->ok(@_) }

nesting_helpers qw/my_nester/;
sub my_nester(&) { Test::Builder->new->ok($_[0]->(), "my_nester exit" )}

my @lines;

my $results = intercept {
    my_ok( 1, "good" ); push @lines => __LINE__;
    my_ok( 0, "bad" );  push @lines => __LINE__;

    my_nester { 1 }; push @lines => __LINE__;

    my_nester {
        my_ok( 1, "good nested" ); push @lines => __LINE__;
        my_ok( 0, "bad nested" );  push @lines => __LINE__;
        0;
    }; push @lines => __LINE__;
};

results_are(
    $results,

    ok   => { line => $lines[0], bool => 1, name => "good" },
    ok   => { line => $lines[1], bool => 0, name => "bad" },
    diag => { line => $lines[1], message => qr/failed test 'bad'/i },

    ok   => { line => $lines[2], bool => 1, name => "my_nester exit" },

    ok   => { line => $lines[3], bool => 1, name => "good nested" },
    ok   => { line => $lines[4], bool => 0, name => "bad nested" },
    diag => { line => $lines[4], message => qr/failed test 'bad nested'/i },
    ok   => { line => $lines[5], bool => 0, name => "my_nester exit" },
);

done_testing;
