package Test::Stream::Plugin::DeepCheck;
use strict;
use warnings;

use Test::Stream::Plugin;

sub load_ts_plugin {
    my $class = shift;
    my $caller = shift;

    require Test::Stream::DeepCheck;

    Test::Stream::Exporter::export_from(
        'Test::Stream::DeepCheck',
        $caller->[0],
        [@_],
    );
}

1;
