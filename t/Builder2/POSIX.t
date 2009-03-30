#!/usr/bin/perl -w

use strict;
use lib 't/lib';

use Test::More;

use Test::Builder2::Result;

use_ok 'Test::Builder2::Output::POSIX';

my $posix = Test::Builder2::Output::POSIX->new;
$posix->trap_output;

{
    $posix->begin;
    is $posix->read, "Running $0\n", "begin()";
}

{
    my $result = Test::Builder2::Result->new(
        type            => 'pass',
        description     => "basset hounds got long ears",
    );
    $posix->result($result);
    is $posix->read, "PASS: basset hounds got long ears\n";
}

{
    $posix->end;
    is $posix->read, "";
}

done_testing(4);
