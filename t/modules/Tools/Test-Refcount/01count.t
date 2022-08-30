#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Builder::Tester;

use Test::Refcount;

my $anon = [];

test_out( "ok 1 - anon ARRAY ref" );
is_refcount( $anon, 1, 'anon ARRAY ref' );
test_test( "anon ARRAY ref succeeds" );

test_out( "not ok 1 - not ref" );
test_fail( +2 );
test_err( "#   expected a reference, was not given one" );
is_refcount( "hello", 1, 'not ref' );
test_test( "not ref fails" );

my $object = bless {}, "Some::Class";

test_out( "ok 1 - object" );
is_refcount( $object, 1, 'object' );
test_test( "normal object succeeds" );

my $newref = $object;

test_out( "ok 1 - two refs" );
is_refcount( $object, 2, 'two refs' );
test_test( "two refs to object succeeds" );

test_out( "not ok 1 - one ref" );
test_fail( +10 );
test_err( "#   expected 1 references, found 2" );
if( Test::Refcount::HAVE_DEVEL_MAT_DUMPER ) {
   test_err( qr/^# SV address is 0x[0-9a-f]+\n/ );
   test_err( qr/^# Writing heap dump to \S+\n/ );
}
if( Test::Refcount::HAVE_DEVEL_FINDREF ) {
   test_err( qr/^# Some::Class=HASH\(0x[0-9a-f]+\) (?:\[refcount 2\] )?is\n/ );
   test_err( qr/(?:^#.*\n){1,}/m ); # Don't be sensitive on what Devel::FindRef actually prints
}
is_refcount( $object, 1, 'one ref' );
test_test( "two refs to object fails to be 1" );

undef $newref;

$object->{self} = $object;

test_out( "ok 1 - circular" );
is_refcount( $object, 2, 'circular' );
test_test( "circular object succeeds" );

undef $object->{self};

my $otherobject = bless { firstobject => $object }, "Other::Class";

test_out( "ok 1 - other ref to object" );
is_refcount( $object, 2, 'other ref to object' );
test_test( "object with another reference succeeds" );

undef $otherobject;

test_out( "ok 1 - undefed other ref to object" );
is_refcount( $object, 1, 'undefed other ref to object' );
test_test( "object with another reference undefed succeeds" );

END {
   # Clean up Devel::MAT dumpfile
   my $pmat = $0;
   $pmat =~ s/\.t$/-1.pmat/;
   unlink $pmat if -f $pmat;
}

done_testing;
