#!/usr/bin/perl

# Demonstrate that is() can be written and the result can be changed
# by wrapper test functions before its formatted.

use strict;
use warnings;

use lib 't/lib';
use absINC;
BEGIN { require 't/test.pl'; }

# Consistent formatting
local $ENV{HARNESS_ACTIVE} = 0;

{
    package TB2::More;

    use Test::Builder2::Module;

    our @EXPORT = qw(is);

    install_test is => sub ($$;$) {
        my($have, $want, $name) = @_;
        my $ok = Builder->ok($have eq $want, $name);

        $ok->name( $ok->name . " from is" );

        $ok->diagnostic([
            have => $have,
            want => $want
        ]);

        return $ok;
    };
}

my $tb = TB2::More->Builder;

{
    package Local::Test;

    # Isolate the builder
    require Test::Builder2::Streamer::Debug;
    require Test::Builder2::History;
    $tb->event_coordinator->history(Test::Builder2::History->new);
    $tb->formatter->streamer( Test::Builder2::Streamer::Debug->new );

    TB2::More->import( tests => 1 );

#line 44
    is( 23, 42, "is 23 eq 42" );
}



is $tb->formatter->streamer->read_all, <<"END", "proper failure output from is()";
TAP version 13
1..1
not ok 1 - is 23 eq 42 from is
#   Failed test 'is 23 eq 42 from is'
#   at $0 line 44.
END

done_testing();
