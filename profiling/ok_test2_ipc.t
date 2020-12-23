use strict;
use warnings;
use Test2::IPC;
use if $ENV{PIPE}, 'Test2::IPC::Driver::AtomicPipe';
use Test2::Tools::Tiny;

my $count = $ENV{OK_COUNT} || 100000;
plan($count);

ok(1, "an ok") for 1 .. $count;

1;
