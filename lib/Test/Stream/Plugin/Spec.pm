package Test::Stream::Plugin::Spec;
use strict;
use warnings;

use Carp qw/confess croak/;
use Scalar::Util qw/weaken/;

use Test::Stream::Plugin;

use Test::Stream::Workflow(
    qw{
        unimport
        group_builder
        gen_unit_builder
    },
    group_builder => {-as => 'describe'},
    group_builder => {-as => 'cases'},
);

sub load_ts_plugin {
    my $class = shift;
    my $caller = shift;

    Test::Stream::Workflow::Meta->build(
        $caller->[0],
        $caller->[1],
        $caller->[2],
        'EOF',
    );

    Test::Stream::Exporter::export_from($class, $caller->[0], \@_);
}

use Test::Stream::Exporter qw/default_exports/;
default_exports qw{
    describe cases
    before_all after_all around_all

    tests it
    before_each after_each around_each

    case
    before_case after_case around_case
};
no Test::Stream::Exporter;

BEGIN {
    *tests       = gen_unit_builder('simple'    => 'primary');
    *it          = gen_unit_builder('simple'    => 'primary');
    *case        = gen_unit_builder('simple'    => 'modify');
    *before_all  = gen_unit_builder('simple'    => 'buildup');
    *after_all   = gen_unit_builder('simple'    => 'teardown');
    *around_all  = gen_unit_builder('simple'    => 'buildup', 'teardown');
    *before_case = gen_unit_builder('modifiers' => 'buildup');
    *after_case  = gen_unit_builder('modifiers' => 'teardown');
    *around_case = gen_unit_builder('modifiers' => 'buildup', 'teardown');
    *before_each = gen_unit_builder('primaries' => 'buildup');
    *after_each  = gen_unit_builder('primaries' => 'teardown');
    *around_each = gen_unit_builder('primaries' => 'buildup', 'teardown');
}

1;
