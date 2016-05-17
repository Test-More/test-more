use strict;
use warnings;

use Test2::Util qw/CAN_THREAD/;
BEGIN {
    unless(CAN_THREAD) {
        require Test::More;
        Test::More->import(skip_all => "threads are not supported");
    }
}

use threads;

open(my $stderr, '>&', STDERR) or die "could not clone STDERR";
my $tmpdir;
END {
    return unless -d $tmpdir;

    print $stderr "The temporary directory '$tmpdir' was not cleaned up, setting exit value to 255.\n";

    $? = 255;
    exit 255;
}
use Test::More tests => 2;

ok(1);
$tmpdir = Test2::API::test2_ipc()->tempdir;

threads->create(sub { while (1) { sleep 1 } })->detach;

ok(1);

close(STDERR);
open(STDERR, '>&', STDOUT);
