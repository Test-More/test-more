use Test::Stream -V1 => qw/AuthorTest/;

ok($ENV{AUTHOR_TESTING}, "AUTHOR_TESTING is set");

done_testing;
