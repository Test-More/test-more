#!/usr/bin/perl -w
use strict;
use warnings;
use Test::CanThread;
use threads;

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}

use strict;
use Test::Builder;

my $Test = Test::Builder->new;
$Test->exported_to('main');
$Test->plan(tests => 6);

for(1..5) {
	'threads'->create(sub { 
          $Test->ok(1,"Each of these should app the test number") 
    })->join;
}

$Test->is_num($Test->current_test(), 5,"Should be five");
