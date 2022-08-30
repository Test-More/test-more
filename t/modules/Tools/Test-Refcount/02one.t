#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Builder::Tester;

use Test::Refcount;

my $anon = [];

test_out( "ok 1 - anon ARRAY ref" );
is_oneref( $anon, 'anon ARRAY ref' );
test_test( "anon ARRAY ref succeeds" );

my $object = bless {}, "Some::Class";

test_out( "ok 1 - object" );
is_oneref( $object, 'object' );
test_test( "normal object succeeds" );

my $newref = $object;

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
is_oneref( $object, 'one ref' );
test_test( "two refs to object fails to be 1" );

END {
   # Clean up Devel::MAT dumpfile
   my $pmat = $0;
   $pmat =~ s/\.t$/-1.pmat/;
   unlink $pmat if -f $pmat;
}

done_testing;
