package Test::Stream::ExitMagic::Context;
use strict;
use warnings;

use Test::Stream::ArrayBase(
    base => 'Test::Stream::Context',
);

sub init {
    $_[0]->[PID]      = $$;
    $_[0]->[ENCODING] = 'legacy';
}

sub snapshot { $_[0] }

1;
