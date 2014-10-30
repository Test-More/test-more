#!/usr/bin/perl

use strict;
use warnings;

use threads;
use Test::More;

subtest my_subtest => sub {
    my $file = __FILE__;
    $file =~ s/\.t$/.load/;
    do $file || die $@;
};

done_testing;
