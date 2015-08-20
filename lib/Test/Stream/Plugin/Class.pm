package Test::Stream::Plugin::Class;
use strict;
use warnings;

use Test::Stream::Plugin;

use Test::Stream::Util qw/pkg_to_file/;

sub load_ts_plugin {
    my $class = shift;
    my ($caller, $load) = @_;

    die "No module specified for 'Class' plugin at $caller->[1] line $caller->[2].\n"
        unless $load;

    my $file = pkg_to_file($load);
    require $file;

    no strict 'refs';
    *{$caller->[0] . '::CLASS'} = \$load;
    *{$caller->[0] . '::CLASS'} = sub { $load };
}

1;
