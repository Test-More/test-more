package Test2::Tools::Spec;
use strict;
use warnings;

use Carp qw/croak/;
use Test2::Workflow qw/parse_args build current_build root_build/;

use Test2::Workflow::Task::Action;

our @EXPORT = qw{
    describe cases
    tests it
    case
    before_all  around_all  after_all
    before_case around_case after_case
    before_each around_each after_each
};
use base 'Exporter';

{
    no warnings 'once';
    *cases = \&describe;
}
sub describe {
    my @caller = caller(0);
    my $build = build(args => \@_, caller => \@caller);

    return $build->compile if defined wantarray;

    my $current = current_build() || root_build($caller[0])
        or croak "No current workflow build!";

    $current->add_primary($build);
}

# Generate a bunch of subs that only have minor differences between them.
BEGIN {
    my %map = (
        case  => ['add_variant'],
        tests => ['add_primary'],
        it    => ['add_primary'],
    
        before_all => ['add_setup'],
        after_all  => ['add_teardown'],
        around_all => ['add_setup', 'add_teardown'],
    
        before_case => ['add_variant_setup'],
        after_case  => ['add_variant_teardown'],
        around_case => ['add_variant_setup', 'add_variant_teardown'],
    
        before_each => ['add_primary_setup'],
        after_each  => ['add_primary_teardown'],
        around_each => ['add_primary_setup', 'add_primary_teardown'],
    );

    my %no_scaffold = (
        tests => 1,
        it   => 1,
        case => 1,
    );

    my $run = "";
    for my $func (keys %map) {
        my $around   = $func =~ m/^around_/ ? ", around => 1"   : "";
        my $scaffold = $no_scaffold{$func}  ? "" : ", scaffold => 1";

        $run .= <<"        EOT";
#line ${ \(__LINE__ + 1) } "${ \__FILE__ }"
sub $func {
    my \@caller = caller(0);
    my \$args = parse_args(args => \\\@_, caller => \\\@caller);
    my \$action = Test2::Workflow::Task::Action->new(%\$args${around}${scaffold});

    return \$action if defined wantarray;

    my \$build = current_build() || root_build(\$caller[0])
        or croak "No current workflow build!";

    \$build->\$_(\$action) for \@{\$map{$func}};
}
        EOT
    }

    my ($ok, $err);
    {
        local $@;
        $ok = eval "$run\n1";
        $err = $@;
    }

    die $@ unless $ok;
}

1;
