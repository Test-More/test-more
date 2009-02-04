#!/usr/bin/perl -w
# $Id$

=pod
In this branch, I'm trying out setting up "incremental planning".
What happens if plan() or done_testing() are passed '0'?
=cut

use strict;
use lib 't/lib';

use Test::Builder;
use TieOut;

my $tb = Test::Builder->create;

my $output = tie *FAKEOUT, "TieOut";
$tb->output(\*FAKEOUT);
$tb->failure_output(\*FAKEOUT);

{
    # Normalize test output
    local $ENV{HARNESS_ACTIVE};

    # Line 25
    eval { $tb->plan( tests => 0 ); };
    $tb->ok($@ eq "You said to run 0 tests at $0 line 26.\n", "setting zero tests throws an error");

    $tb->plan( tests => 1 );
    $tb->ok(1);
    $tb->ok(1);
    $tb->ok(1);
    $tb->done_testing();
    $tb->plan( tests => 2 );
    $tb->ok(1);
    $tb->ok(1);
}

my $Test = Test::Builder->new;
$Test->plan( tests => 1 );
$Test->level(0);
$Test->is_eq($output->read, <<"END");
ok 1 - setting zero tests throws an error
1..1
ok 2
ok 3
ok 4
2..4
5..6
ok 5
ok 6
END
