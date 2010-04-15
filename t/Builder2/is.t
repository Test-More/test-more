#!/usr/bin/perl

# Demonstrate that is() can be written and the result can be changed
# by wrapper test functions before its formatted.

use strict;
use warnings;

{
    package TB2::More;

    use Test::Builder2::Module;

    our @EXPORT = qw(is);

    install_test is => sub ($$;$) {
        my($have, $want, $name) = @_;
        my $ok = $Builder->ok($have eq $want, $name);

        $ok->name( $ok->name . " from is" );

        $ok->diagnostic([
            have => $have,
            want => $want
        ]);

        return $ok;
    };
}

my $tb = TB2::More->builder;

{
    package Local::Test;

    $tb->formatter->streamer_class("Test::Builder2::Streamer::Debug");

    TB2::More->import( tests => 1 );
    is( 23, 42, "is 23 eq 42" );
}

use Test::More;

is $tb->formatter->streamer->read_all, <<'END';
TAP version 13
1..1
not ok 1 - is 23 eq 42 from is
END

done_testing();
