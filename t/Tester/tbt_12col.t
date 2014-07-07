#!/usr/bin/perl

use Test::Builder::Tester tests => 9;
use Test::More;
use strict;

# override the sense of color
Test::Builder::Tester::red_string("RED");
Test::Builder::Tester::green_string("GREEN");
Test::Builder::Tester::reset_string("RESET");

# check that without color, they're all still ""
is Test::Builder::Tester::red_string(), "", "nada for red";
is Test::Builder::Tester::green_string(), "", "nada for green";
is Test::Builder::Tester::reset_string(), "", "nada for reset";

# check that the colors are now on
Test::Builder::Tester::color(1);
is Test::Builder::Tester::red_string(), "RED","something for red";
is Test::Builder::Tester::green_string(), "GREEN","something for green";
is Test::Builder::Tester::reset_string(), "RESET", "nada for reset";

# check that the complaints are what we'd expect
{
	my $tbtt = bless { type => "" }, "Test::Builder::Tester::Tie";
	$tbtt->expect(["foo","bar","baz"]);
	$tbtt->PRINT("foobarbAz");
	is(
		$tbtt->complaint(),
		" is:\nGREENfoobarbRESETREDAzRESET\nnot:\nGREENfoobarbRESETREDazRESETREDRESET\nas expected",
		"plain old strings"
	);
}

{
	my $tbtt = bless { type => "" }, "Test::Builder::Tester::Tie";
	$tbtt->expect(["foo","/bar/","baz"]);
	$tbtt->PRINT("foobarbAz");
	is(
		$tbtt->complaint(),
		" is:\nGREENfooRESETGREENbarRESETGREENbRESETREDAzRESET\nnot:\nGREENfooRESETGREEN/bar/RESETGREENbRESETREDazRESETREDRESET\nas expected",
		"matching regex"
	);
}

{
	my $tbtt = bless { type => "" }, "Test::Builder::Tester::Tie";
	$tbtt->expect(["foo","/bar/","baz"]);
	$tbtt->PRINT("foobArbaz");
	is(
		$tbtt->complaint(),
		" is:\nGREENfooRESETREDbArbazRESET\nnot:\nGREENfooRESETRED/bar/RESETREDbazRESETREDRESET\nas expected",
		"failing regex"
	);
}
