#!/usr/bin/perl

use Test::Builder::Tester tests => 6;
use Test::More;
use strict;

########################################################################
# these tests tests the internals of Test::Builder::Tester::Tie
########################################################################

########################################################################
# check that strings next to each other are able to be grouped togeter

my $tbtt = "Test::Builder::Tester::Tie";

is_deeply(
	[
		$tbtt->_group_checks(
			"foo", "bar", "/wibble/",
			"bob", "bar", "/zang/",
			"/zing/", "fish"
		),
	],
	[
		"foobar","/wibble/","bobbar","/zang/","/zing/","fish"
	],
	"_group_checks",
);

########################################################################
# check that returns are added where they're supposed to be and array
# refs are removed

my $flat = 	[
		map { $tbtt->_flatten_and_add_return($_) }
		"foo",
		"bar",
		["foo","bar","/buzz/","wibble"],
		"/fred/",
		"barney",
];

is_deeply(
	$flat,
	[
		"foo\n",
		"bar\n",
		"foo",
		"bar",
		"/buzz/",
		"wibble",
		"/fred/",
		"barney\n",
	],
	"_flatten_and_add_return",
) or diag explain $flat;

########################################################################
# make sure that automatic translation of text that looks like
# a regular expression into

my $tr1 = [ $tbtt->_translate_Failed_check(
	"#     Failed blah test (foo at line 123)"
) ];

is_deeply $tr1, [
	'',
	'/#\s+Failed\ blah\ test.*?\n?.*?at\ foo line 123.*\n?/',
	'',
], "tfc without pre or post" or diag explain $tr1;

my $tr2 = [ $tbtt->_translate_Failed_check(
	"# foo\n#     Failed blah test (foo at line 123)"
) ];

is_deeply $tr2, [
	"# foo\n",
	'/#\s+Failed\ blah\ test.*?\n?.*?at\ foo line 123.*\n?/',
	'',
], "tfc with preamble" or diag explain $tr2;

my $tr3 = [ $tbtt->_translate_Failed_check(
	"#     Failed blah test (foo at line 123)\n# bar"
) ];

is_deeply $tr3, [
	'',
	'/#\s+Failed\ blah\ test.*?\n?.*?at\ foo line 123.*\n?/',
	'# bar',
], "tfc with postamble" or diag explain $tr3;

my $tr4 = [ $tbtt->_translate_Failed_check(
	"# foo\n".
	"#     Failed bingo test (zoop at line 124)\n".
	"#     Failed blah test (foo at line 123)\n".
	"# bar\n"
) ];

is_deeply $tr4, [
	"# foo\n",
	'/#\s+Failed\ bingo\ test.*?\n?.*?at\ zoop line 124.*\n?/',
	'',
	'/#\s+Failed\ blah\ test.*?\n?.*?at\ foo line 123.*\n?/',
	"# bar\n",
], "tfc with postamble" or diag explain $tr4;

########################################################################

