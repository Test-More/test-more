#!/usr/bin/perl -w

# Test to see if is_deeply() plays well with threads.

use strict;
use Config;

BEGIN {
    unless ( $Config{'useithreads'} && 
             eval { require threads; 'threads'->import; 1; }) 
    {
        print "1..0 # Skip no working threads\n";
        exit 0;
    }
    
    unless ( $ENV{AUTHOR_TESTING} ) {
        print "1..0 # Skip many perls have broken threads.  Enable with AUTHOR_TESTING.\n";
        exit 0;
    }
}
use Test::More;

my $Num_Threads = 5;

plan tests => $Num_Threads * 100 + 6;


sub do_one_thread {
    my $kid = shift;
    my @list = ( 'x', 'yy', 'zzz', 'a', 'bb', 'ccc', 'aaaaa', 'z',
                 'hello', 's', 'thisisalongname', '1', '2', '3',
                 'abc', 'xyz', '1234567890', 'm', 'n', 'p' );
    my @list2 = @list;
    note "kid $kid before is_deeply";

    for my $j (1..100) {
        is_deeply(\@list, \@list2, "kid $kid");
    }
    note "kid $kid exit";
    return 42;
}

my @kids = ();
for my $i (1..$Num_Threads) {
    my $t = threads->new(\&do_one_thread, $i);
    note "parent $$: continue";
    push(@kids, $t);
}

for my $t (@kids) {
    note "parent $$: waiting for join";
    my $rc = $t->join();
    cmp_ok( $rc, '==', 42, "threads exit status is $rc" );
}

pass("End of test");
