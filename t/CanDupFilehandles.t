#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use IO::Handle;

use_ok 'Test::Builder2::CanDupFileHandles';

{
    package Some::Class;

    use Test::Builder2::Mouse;
    with 'Test::Builder2::CanDupFilehandles';
}

note "autoflush"; {
    my $foo = "stuff";
    open my $fh, "<", \$foo;

    ok !$fh->autoflush;
    Some::Class->autoflush($fh);
    ok $fh->autoflush,  "autoflush worked";
}


# Only seems to work on real filehandles, but that's good enough.
note "dup_filehandle"; {
    ok open my $write, ">", "t/tmpfile.$$";

    my $dup = Some::Class->dup_filehandle($write);
    ok $dup, "filehandle duplicated";

    print $dup    "stuff";
    print $write  " and things\n";

    close $dup;
    close $write;

    ok open my $read, "<", "t/tmpfile.$$";

    is <$read>, "stuff and things\n",     "dup works";

    unlink "t/tmpfile.$$";
}


done_testing;
