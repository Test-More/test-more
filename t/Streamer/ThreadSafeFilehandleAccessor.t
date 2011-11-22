#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

my $Have_Threads;

use Config;
BEGIN {
    # Have to load threads before threads::shared.
    $Have_Threads = $Config{'useithreads'} && eval { require threads; 'threads'->import; 1; };
}
use threads::shared;

# A class for testing
{
    package MyStreamer;

    use TB2::Mouse;
    use TB2::ThreadSafeFilehandleAccessor fh_accessors => [qw(this_fh that_fh)];
}


note "construction and accessors"; {
    my $obj = MyStreamer->new(
        this_fh         => \*STDOUT,
    );

    is $obj->this_fh, \*STDOUT;
    ok !$obj->that_fh;

    my $string = '';
    open my $fh, ">", \$string;
    $obj->this_fh($fh);

    print { $obj->this_fh } "Hello world!\n";

    is $string, "Hello world!\n", "works with scalar ref filehandles";
}


note "with threads"; SKIP: {
    skip "need working threads" unless $Have_Threads;

    my $str = '';
    open my $fh, ">", \$str;

    # Create and share a streamer
    my $obj = MyStreamer->new( this_fh => $fh );
    $obj = shared_clone($obj);
    isa_ok $obj, "MyStreamer";

    print { $obj->this_fh } "before the threads\n";

    # Make some threads and exercise the streamer
    my @threads = map {
        "threads"->create(sub {
            print { $obj->this_fh } "from the thread\n";

            my $want = <<'END';
before the threads
from the thread
END

            # The counter might not be thread safe, so don't issue a test unless we fail.
            is $str, $want if $str ne $want;
        })
    } 1..5;
    $_->join for @threads;
    print { $obj->this_fh } "after the threads\n";

    # $str isn't shared, so we won't see the thread's output.
    # It seems if $str is shared Perl segfaults... boogers.
    is $str, <<'END';
before the threads
after the threads
END

}


done_testing;
