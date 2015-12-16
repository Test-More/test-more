BEGIN { require 't/tools.pl' };

my $count = 10000;
plan($count);

ok(1, "an ok") for 1 .. $count;

1;
