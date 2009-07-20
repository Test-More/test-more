#!/usr/bin/perl -w

# Full test of using a non-TAP outputter.

use strict;
use lib 't/lib';

use Test::More;
use Test::Builder2;
use Test::Builder2::Formatter::POSIX;

my $test = Test::Builder2->new;

my $posix = Test::Builder2::Formatter::POSIX->new;
$posix->trap_output;

$test->formatter($posix);

$test->ok(1, "this is a pass");
is $posix->read, <<"END";
PASS: this is a pass
END

$test->ok(0, "this is a fail");
is $posix->read, "FAIL: this is a fail\n";

done_testing(2);
