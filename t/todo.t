use Test::More tests => 5;

$Why = 'Just testing the todo interface.';

TODO: {
    local $TODO = $Why;

    fail("Expected failure");
    fail("Another expected failure");
}

pass("This is not todo");


TODO: {
    local $TODO = $Why;

    fail("Yet another failure");
}

pass("This is still not todo");
