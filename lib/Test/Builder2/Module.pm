package Test::Builder2::Module;

use 5.006;
use strict;

our $VERSION = '2.00_01';
our $CLASS = __PACKAGE__;

use Test::Builder2;
use base 'Exporter';

our $Builder = Test::Builder2->new;
our @EXPORT = qw($Builder install_test import);

sub import {
    my $class = shift;
    my $caller = caller;

    return $class->export_to_level(1, $class, @EXPORT) if $class eq $CLASS;

    $Builder->plan(@_);
    _install($caller, "ok", $class->can("ok"));
}


=head1 NAME

Test::Builder2::Module - Write a test module

=head1 SYNOPSIS

    use Test::Builder2::Module;
    our @EXPORT = qw(ok);

    # ok( 1 + 1 == 2 );
    install-test( ok => sub {
        my $test = shift;
        return $Builder-ok($test);
    });

=head1 DESCRIPTION

A module to declare test functions to make writing a test library easier.

=head2 METHODS

=head3 install_test

  install_test( $name => $code );

Declares a new test function or method.  Similar to writing C<< sub
name { ... } >> with two differences.

1. Declaring the test in this manner enables pre and post test actions,
   such as aborting the test on failure.
2. The $Builder object is available inside your $code.

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

    my $code = sub {
        # Fire any before-test actions.
        $Builder->test_start();

        # Call the original routine, but retain context.
        my @ret;
        if( wantarray ) {
            @ret = $test_code->(@_);
        }
        elsif( defined wantarray ) {
            $ret[0] = $test_code->(@_);
        }
        else {
            $test_code->(@_);
        }

        # And after-test.
        $Builder->test_end(@ret);

        return wantarray ? @ret : $ret[0];
    };

    _install($caller, $name, $code);

    return $code;
}

1;
