#!perl -w

use strict;
use lib 't/lib';

require Test::Simple::Catch;
my($out, $err) = Test::Simple::Catch::caught();


# Can't use Test.pm, that's a 5.005 thing.
package My::Test;

print "1..2\n";

my $test_num = 1;
# Utility testing functions.
sub ok ($;$) {
    my($test, $name) = @_;
    my $ok = '';
    $ok .= "not " unless $test;
    $ok .= "ok $test_num";
    $ok .= " - $name" if defined $name;
    $ok .= "\n";
    print $ok;
    $test_num++;

    return $test;
}


package main;

require Test::More;
Test::More->import(tests => 15);

# Preserve the line numbers.
#line 38
ok( 0, 'failing' );

is( "foo", "bar", 'foo is bar?');
is( undef, '',    'undef is empty string?');
is( undef, 0,     'undef is 0?');
is( '',    0,     'empty string is 0?' );

isnt("foo", "foo", 'foo isnt foo?' );
isn't("foo", "foo",'foo isn\'t foo?' );

like( "foo", '/that/',  'is foo like that' );

fail('fail()');

can_ok('Mooble::Hooble::Yooble', qw(this that));
isa_ok(bless([], "Foo"), "Wibble");
isa_ok(42,    "Wibble", "My Wibble");
isa_ok(undef, "Wibble", "Another Wibble");

use_ok('Hooble::mooble::yooble');
require_ok('ALL::YOUR::BASE::ARE::BELONG::TO::US::wibble');

END {
    My::Test::ok($$out eq <<OUT, 'failing output');
1..15
not ok 1 - failing
not ok 2 - foo is bar?
not ok 3 - undef is empty string?
not ok 4 - undef is 0?
not ok 5 - empty string is 0?
not ok 6 - foo isnt foo?
not ok 7 - foo isn't foo?
not ok 8 - is foo like that
not ok 9 - fail()
not ok 10 - Mooble::Hooble::Yooble->can(...)
not ok 11 - The object isa Wibble
not ok 12 - My Wibble isa Wibble
not ok 13 - Another Wibble isa Wibble
not ok 14 - use Hooble::mooble::yooble;
not ok 15 - require ALL::YOUR::BASE::ARE::BELONG::TO::US::wibble;
OUT

    my $err_re = <<ERR;
#     Failed test ($0 at line 38)
#     Failed test ($0 at line 40)
#          got: 'foo'
#     expected: 'bar'
#     Failed test (t/fail-more.t at line 41)
#          got: undef
#     expected: ''
#     Failed test (t/fail-more.t at line 42)
#          got: undef
#     expected: '0'
#     Failed test (t/fail-more.t at line 43)
#          got: ''
#     expected: '0'
#     Failed test ($0 at line 45)
#     it should not be 'foo'
#     but it is.
#     Failed test ($0 at line 46)
#     it should not be 'foo'
#     but it is.
#     Failed test ($0 at line 48)
#                   'foo'
#     doesn't match '/that/'
#     Failed test ($0 at line 50)
#     Failed test ($0 at line 52)
#     Mooble::Hooble::Yooble->can('this') failed
#     Mooble::Hooble::Yooble->can('that') failed
#     Failed test ($0 at line 53)
#     The object isn't a 'Wibble'
#     Failed test ($0 at line 54)
#     My Wibble isn't a reference
#     Failed test ($0 at line 55)
#     Another Wibble isn't defined
ERR

   my $filename = quotemeta $0;
   my $more_err_re = <<ERR;
#     Failed test \\($filename at line 57\\)
#     Tried to use 'Hooble::mooble::yooble'.
#     Error:  Can't locate Hooble.* in \\\@INC .*
#     Failed test \\($filename at line 58\\)
#     Tried to require 'ALL::YOUR::BASE::ARE::BELONG::TO::US::wibble'.
#     Error:  Can't locate ALL.* in \\\@INC .*
# Looks like you failed 15 tests of 15.
ERR

    unless( My::Test::ok($$err =~ /^\Q$err_re\E$more_err_re$/, 
                         'failing errors') ) {
        print map "# $_", $$err;
    }

    exit(0);
}
