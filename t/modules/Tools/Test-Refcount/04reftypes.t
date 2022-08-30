#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Builder::Tester;

use Symbol qw( gensym );

use Test::Refcount;

my %refs = (
   SCALAR => do { my $var; \$var },
   ARRAY  => [],
   HASH   => +{},
   # This magic is to ensure the code ref is new, not shared. To be a new one
   # it has to contain a unique pad.
   CODE   => do { my $var; sub { $var } },
   GLOB   => gensym(),
   Regex  => qr/foo/,
);

foreach my $type (qw( SCALAR ARRAY HASH CODE GLOB Regex )) {
   SKIP: {
      if( $type eq "Regex" and $] >= 5.011 ) {
         # Perl v5.11 seems to have odd behaviour with Regexp references. They start
         # off with a refcount of 2. Not sure if this is a bug in Perl, or my
         # assumption. Until P5P have worked it out, we'll skip this. See also
         # similar skip logic in Devel-Refcount's tests
         skip "Bleadperl", 1;
      }

      test_out( "ok 1 - anon $type ref" );
      is_refcount( $refs{$type}, 1, "anon $type ref" );
      test_test( "anon $type ref succeeds" );
   }
}

done_testing;
