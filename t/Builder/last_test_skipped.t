#!/usr/bin/perl

# A bug where TB1->skip did not record seeing a test go by

use strict;
use warnings;

require Test::Builder;

# TB2 + TB2::Module will end the stream before TB1
require Test::Builder2::Module;
require Test::Builder2;

my $tb = Test::Builder->new;
$tb->plan(tests => 2);
$tb->ok(1);
$tb->skip("Just for testing");

END {
    die "Test exited abnormally with $?" if $?;
}
