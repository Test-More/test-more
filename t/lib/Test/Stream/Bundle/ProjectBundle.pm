package Test::Stream::Bundle::ProjectBundle;
use strict;
use warnings;

use Test::Stream::Exporter qw/export export_to/;
export project_bundled => sub { 1 };
no Test::Stream::Exporter;

use Test::Stream::Bundle;

sub plugins {
    return (
        sub {
            my ($caller) = @_;
            __PACKAGE__->export_to($caller->[0], ['project_bundled']);
        },
    );
}


1;
