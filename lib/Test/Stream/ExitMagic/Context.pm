package Test::Stream::ExitMagic::Context;
use strict;
use warnings;

use base 'Test::Stream::Context';

use Test::Stream::ArrayBase;
BEGIN { Test::Stream::ArrayBase->cleanup }

sub init {
    $_[0]->[PID]      = $$;
    $_[0]->[ENCODING] = 'legacy';
}

sub snapshot { $_[0] }

1;
