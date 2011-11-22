#!/usr/bin/perl -w

use Config;
BEGIN {
    unless ( $Config{'useithreads'} && 
             eval { require threads; 'threads'->import; 1; }) 
    {
        print "1..0 # Skip: no working threads\n";
        exit 0;
    }
}

use strict;
use Test::Builder;

my $Num_Threads = 10;
my $Num_Results_Per_Thread = 100;

my $Test = Test::Builder->new;
$Test->exported_to('main');
$Test->plan(tests => ($Num_Threads * $Num_Results_Per_Thread) + $Num_Threads + 1 );

sub do_one_thread {
    my $kid = shift;

    $Test->note("kid $kid start");
    for (1..$Num_Results_Per_Thread) {
        $Test->ok(1, "kid $kid");
    }
    $Test->note("kid $kid end");

    return 42;
}

my @kids = ();
for my $i (1..$Num_Threads) {
    $Test->note("Starting thread $i");
    push @kids, threads->new(\&do_one_thread, $i);
    $Test->note("thread $i started");
}

for my $t (@kids) {
    $Test->note("parent: waiting for join");
    my $rc = $t->join();
    $Test->cmp_ok( $rc, '==', 42, "threads exit status is $rc" );
}

$Test->ok(1, "End of test");
