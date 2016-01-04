BEGIN { require 't/tools.pl' };

my $count = $ENV{OK_COUNT} || 100000;
plan($count);

ok(1, "an ok") for 1 .. $count;

1;
