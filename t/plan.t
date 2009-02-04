#!/usr/bin/perl -w
# $Id$

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

    $tb->plan( tests => 4 );
    $tb->plan( tests => 4 );
    $tb->ok(1);
    $tb->ok(1);
    $tb->ok(1);

    eval { $tb->plan('no_plan')  };
    $tb->ok($@ eq sprintf("You tried to plan twice at %s line %d.\n", $0, __LINE__ -1),
      'disallow changing plan' );
}

my $Test = Test::Builder->new;
$Test->plan( tests => 1 );
$Test->level(0);
$Test->is_eq($output->read, <<"END");
1..4
4..8
ok 1
ok 2
ok 3
ok 4 - disallow changing plan
END
