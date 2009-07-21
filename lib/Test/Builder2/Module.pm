package Test::Builder2::Module;

use 5.008001;
use strict;

our $VERSION = '2.00_01';
our $CLASS = __PACKAGE__;

use Test::Builder2;
use base 'Exporter';

our @EXPORT = qw(install_test builder);

sub import {
    my $class = shift;
    my $caller = caller;

    $class->export_to_level(1, $class, @EXPORT);

    $caller->builder(Test::Builder2->new);

    no strict 'refs';

    # XXX Don't like doing this.  Haven't found a better way.
    unshift @{$caller .'::ISA'}, 'Exporter';

    # Give them the import() routine for modules.
    *{$caller .'::import'} = \&_module_import;
}


sub _module_import {
    my $class  = shift;
    my $caller = caller;

    $class->builder->plan(@_);

    $class->export_to_level(1, $class);
}


=head1 NAME

Test::Builder2::Module - Write a test module

=head1 SYNOPSIS

    use Test::Builder2::Module;
    our @EXPORT = qw(ok);

    # ok( 1 + 1 == 2 );
    sub ok {
        my $test = shift;
        return $Builder-ok($test);
    }

=head1 DESCRIPTION

A module to declare test functions to make writing a test library easier.

=head2 METHODS

=head3 builder

    my $builder = Your::Test->builder;
    Your::Test->builder($builder);

Gets/sets the Test::Builder2 for Your::Test.  Also changes C<$Builder> for Your::Test.

=cut

sub builder {
    my $proto = shift;
    my $class = ref $proto || $proto;

    no strict 'refs';
    if( @_ ) {
        my $builder = shift;
        *{$class . '::Builder'} = \$builder;
    }

    return ${$class . '::Builder'};
}

1;
