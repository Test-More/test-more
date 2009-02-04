#!/usr/bin/perl -w
# $Id$

=pod
In this branch, I'm trying out setting up "incremental planning".
I want C<Test::Builder> to emit partial plans every time C<plan()>
is called; the testing harness can later combine plans to come up
with a single 'conclusive' plan.
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

    $tb->plan( tests => 3 );
    $tb->ok(1);
    $tb->ok(1);
    $tb->ok(1);
    $tb->plan( tests => 2 );
    $tb->ok(1);
    $tb->ok(1);
}

my $Test = Test::Builder->new;
$Test->level(0);
$Test->is_eq($output->read, <<"END");
1..3
ok 1
ok 2
ok 3
4..5
ok 4
ok 5
END
$Test->ok(1);
$Test->ok(1);
$Test->ok(1);
$Test->done_testing();
