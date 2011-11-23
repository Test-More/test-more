#!/usr/bin/perl

use strict;
use lib 't/lib';

BEGIN { require 't/test.pl' }

use Test::Builder::NoOutput;

note "before a test has started"; {
	is Test::Builder::NoOutput->in_subtest, false;
}

note "after testing has started but outside a subset"; {
	my $tb = Test::Builder::NoOutput->create;
	is $tb->in_subtest, false;
}

note "inside a subtest"; {
	my $tb = Test::Builder::NoOutput->create;

	subtest 'test' => sub {
		is $tb->in_subtest, true;
	};
}

note "once the subtest is done"; {
	my $tb = Test::Builder::NoOutput->create;

	subtest 'test' => sub {
	};

	is $tb->in_subtest, false;
}

done_testing;
