#!/usr/bin/perl

use strict;
use Test::More;

if (!eval { require Module::Signature; 1 }) {
    plan skip_all => 
      "Next time around, consider installing Module::Signature, ".
      "so you can verify the integrity of this distribution.";
}
elsif (!eval { require Socket; Socket::inet_aton('pgp.mit.edu') }) {
    plan skip_all => "Cannot connect to the keyserver to check module ".
                     "signature";
}
else {
    plan tests => 1;
}
	
is(Module::Signature::verify(), Module::Signature::SIGNATURE_OK(), 
                                                         "Valid signature" );
