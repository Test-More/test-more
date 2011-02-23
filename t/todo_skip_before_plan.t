#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

TODO: {
    todo_skip "todo_skip one", 1;
}
pass("this is a pass");

done_testing(2);
