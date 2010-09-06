package Test::Builder2::threads::shared::off;

use strict;

sub import {
    my $caller = caller;

    no strict;

    *{$caller . '::share'}        = sub { return $_[0] };
    *{$caller . '::shared_clone'} = sub { return $_[0] };
    *{$caller . '::lock'}         = sub { 0 };

    return;
}

1;
