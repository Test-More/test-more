#!/usr/bin/perl -w
# $Id$

=pod
In this branch, I'm trying out setting up "incremental planning".
Sometimes you just want a single plan at the end of the test;
with incremental planning, you can do this using done_testing().
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

    $tb->ok(1);
    $tb->ok(1);
    $tb->ok(1);
    $tb->ok(1);
    $tb->ok(1);
    $tb->done_testing(5);
}

my $Test = Test::Builder->new;
$Test->plan( tests => 1 );
$Test->level(0);
$Test->is_eq($output->read, <<"END");
ok 1
ok 2
ok 3
ok 4
ok 5
1..5
END
