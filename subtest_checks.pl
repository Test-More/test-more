#!/usr/bin/perl 

use strict;
use warnings;

use Test::More;

subtest passing => sub {
    pass;
};

subtest failing => sub {
    fail;
};

subtest 'todo okay' => sub {
    local $TODO = 'normal todo';
    fail;
};

subtest 'todo flagged as passing' => sub {
    local $TODO = 'normal todo';
    pass;
};

subtest 'failing' => sub {
    fail;

    local $TODO = 'normal todo';
    pass;
};

subtest 'todo flagged as passing' => sub {
    pass;

    local $TODO = 'normal todo';
    pass;
};

subtest 'todo ok' => sub {
    pass;

    local $TODO = 'normal todo';
    fail;
};

subtest 'embedded top is okay' => sub {
    subtest 'level 1' => sub {
        local $TODO = 'normal todo';
        fail;
    };
};

subtest 'embedded top is flagged' => sub {
    subtest 'level 1' => sub {
        local $TODO = 'normal todo';
        pass;
    };
};

subtest 'embedded top is flagged' => sub {
    local $TODO = 'normal todo';
    subtest 'level 1' => sub {
        local $TODO = 'normal todo';
        pass;
    };
};

done_testing;
