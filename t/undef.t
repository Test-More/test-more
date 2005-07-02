#!/usr/bin/perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;
use Test::More tests => 16;
use TieOut;

BEGIN { $^W = 1; }

my $warnings = '';
local $SIG{__WARN__} = sub { $warnings .= join '', @_ };

my $TB = Test::Builder->new;
sub no_warnings {
    $TB->is_eq($warnings, '', '  no warnings');
    $warnings = '';
}
   

is( undef, undef,           'undef is undef');
no_warnings;

isnt( undef, 'foo',         'undef isnt foo');
no_warnings;

isnt( undef, '',            'undef isnt an empty string' );
isnt( undef, 0,             'undef isnt zero' );

like( undef, '/.*/',        'undef is like anything' );
no_warnings;

eq_array( [undef, undef], [undef, 23] );
no_warnings;

eq_hash ( { foo => undef, bar => undef },
          { foo => undef, bar => 23 } );
no_warnings;

eq_set  ( [undef, undef, 12], [29, undef, undef] );
no_warnings;


eq_hash ( { foo => undef, bar => { baz => undef, moo => 23 } },
          { foo => undef, bar => { baz => undef, moo => 23 } } );
no_warnings


my $tb = Test::More->builder;

use TieOut;
my $caught = tie *CATCH, 'TieOut';
my $old_fail = $tb->failure_output;
$tb->failure_output(\*CATCH);
diag(undef);
$tb->failure_output($old_fail);

is( $caught->read, "# undef\n" );
no_warnings;


$tb->maybe_regex(undef);
is( $caught->read, '' );
no_warnings;
