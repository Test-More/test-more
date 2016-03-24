use strict;
use warnings;

END { $? = 0 } # Ceate this END before anything else so that $? gets set

my $foo;
BEGIN {
    $| = 1;
    print "\n1..0 # SKIP foo\n";
    exit(0) unless $ENV{AUTHOR_TESTING};

    close(STDERR);
    close(STDOUT);
    $foo = "";
    open(STDERR, '>', \$foo);
    open(STDOUT, '>', \$foo);
}

require Test2::API;

eval(' sub { die } ')->();
END { local $? = 0; sub { my $ctx = Test2::API::context(); $ctx->release; }->() }
