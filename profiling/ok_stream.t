use Test::Stream;

my $count = 100000;
plan($count);

ok(1, "an ok") for 1 .. $count;

1;
