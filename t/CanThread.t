#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

my $Threads_On;
use Config;
BEGIN {
    if(
        $Config{'useithreads'} && 
        eval { require threads; 'threads'->import; 1; }
    ) 
    {
        note "threads are enabled";
        $Threads_On = 1;
    }
    else {
        note "threads are disabled";
        $Threads_On = 0;
    }
}


{
    package WithThreads;

    use TB2::Mouse;
    with "TB2::CanThread";

    has 'stuff' =>
      is        => 'rw',
    ;
}

{
    package WithoutThreads;

    use TB2::Mouse;
    with "TB2::CanThread";

    has '+coordinate_threads' =>
      default   => 0;
}


note "coordinate_threads off"; {
    my $obj = WithoutThreads->new;

    my %hash = ( foo => 23, bar => [1,2,3] );
    my $clone = $obj->shared_clone(\%hash);
    is_deeply $clone, \%hash, "shared_clone() is a pass through";

    my $var = 23;
    lock($var) if $obj->coordinate_threads;
    is $var, 23, "lock() does nothing";

    $obj->share($var);
    is $var, 23, "share() does nothing";
}


note "coordinate_threads on"; {
    my $obj = WithThreads->new;

    # Try this stuff even with threads off to make sure they don't blow up.
    my %hash = ( counter => 4, bar => [1,2,3] );
    $obj->stuff( $obj->shared_clone(\%hash) );

    my $var = 5;
    $obj->share(\$var);

    my $var2 = 1;
    $obj->share(\$var2);

    note "check lock() works with threads on or off"; {
        lock($var2);
    }

    SKIP: {
        skip "No threads" if !$Threads_On;
        my @threads = map {
            'threads'->create(sub {
                # Simple test for share
                $var++;

                # Simple test for shared_clone
                $obj->stuff->{counter}++;

                # Check lock() is doing its job
                lock($var2);

                # Remember the value of the locked variable
                my $check = $var2;

                # Wait around a few seconds, randomly, so other threads can act
                sleep(int rand(3));

                # Make sure the shared variable remains the same
                # XXX threads are broken in TB2 so don't actually run the test
                # unless it fails
                is $var2, $check, "lock() locks" if $var2 != $check;

                # Change the shared variable to try and effect other threads
                # which have locked it
                $var2 = $var2 * 2;
            })
        } 1..5;

        for my $thread (@threads) {
            $thread->join;
        }

        is $var, 10,                                                "share() shares";
        is $var2, 2**5;
        is_deeply $obj->stuff, { counter => 9, bar => [1,2,3] },    "shared_clone() shares";
    }
}

done_testing;
