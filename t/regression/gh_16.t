my $foo;
BEGIN {
    $| = 1;
    print "\n1..0 # SKIP foo\n";

    close(STDERR);
    close(STDOUT);
    $foo = "";
    open(STDERR, '>', \$foo);
    open(STDOUT, '>', \$foo);
}

exit(0) unless $ENV{AUTHOR_TESTING};
require Test2::API;

local $? = 0;
END { $? = 0 } # Ceate this END before anything else so that $? gets set


sleep 1;
eval(' sub { die } ')->();
sleep 1;
END { local $? = 0; sub { my $ctx = Test2::API::context(); $ctx->release; }->() }
