package Test::Stream::ExitMagic::Context;
use strict;
use warnings;

use base 'Test::Stream::Context';

use Test::Stream::ArrayBase;
BEGIN {
    accessors qw/stream frame encoding in_todo todo depth pid skip/;
    Test::Stream::ArrayBase->cleanup;
}

sub init {
    $_[0]->[PID]      = $$;
    $_[0]->[ENCODING] = 'legacy';
    $_[0]->[DEPTH]    = 0;
}

1;
