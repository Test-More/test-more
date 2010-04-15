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

    $class->builder->stream_start(@_) if @_;

    $class->export_to_level(1, $class);
}


=head1 NAME

Test::Builder2::Module - Write a test module

=head1 SYNOPSIS

    use Test::Builder2::Module;
    our @EXPORT = qw(is);

    # is( $have, $want, $name );
    install_test( is => sub ($$;$) {
        my($have, $want, $name) = @_;

        my $result = $Builder->ok($have eq $want, $name);
        $result->diagnostic([
            have => $have,
            want => $want
        ]);

        return $result;
    });

=head1 DESCRIPTION

A module to declare test functions to make writing a test library easier.

=head2 FUNCTIONS

=head3 install_test

  install_test( $name => $code );

Declares a new test function (aka an "assert") or method.  Similar to
writing C<< sub name { ... } >> with two differences.

1. Declaring the test in this manner enables the assert_start and
   assert_end hooks, such as aborting the test on failure.
2. It takes care of displaying the test result for you.
3. The $Builder object is available inside your $code which is just a
   shortcut for C<< $class->builder >>

The prototype of the $code is honored.

$code must return a single Test::Builder2::Result::Base object,
usually the result from C<< Test::Builder2->ok() >> or any other test
function.

=cut

sub _install {
    my($package, $name, $code) = @_;

    no strict 'refs';
    *{$package . '::' . $name} = $code;

    return;
}


sub install_test {
    my($name, $test_code) = @_;
    my $caller = caller;

    my $proto = prototype($test_code);
    $proto = $proto ? "($proto)" : "";

    local($@, $!);
    my $code = eval sprintf <<'CODE', $proto;
    sub %s {
        # Fire any before-test actions.
        $caller->builder->assert_start();

        my $result = $test_code->(@_);

        # And after-test.
        $caller->builder->assert_end($result);

        return $result;
    };
CODE

    die $@ unless $code;

    _install($caller, $name, $code);

    return $code;
}


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
