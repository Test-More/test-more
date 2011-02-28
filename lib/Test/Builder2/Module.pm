package Test::Builder2::Module;

use 5.008001;
use Test::Builder2::Mouse;
with 'Test::Builder2::CanTry',
     'Test::Builder2::CanLoad';

our $VERSION = '2.00_07';
our $CLASS = __PACKAGE__;

use base 'Exporter';
our @EXPORT = qw(install_test builder);

sub import {
    my $class = shift;
    my $caller = caller;

    $class->export_to_level(1, $class, @EXPORT);

    $class->load('Test::Builder2');

    no strict 'refs';

    # XXX Don't like doing this.  Haven't found a better way.
    unshift @{$caller .'::ISA'}, 'Exporter';

    # Give them the import() routine for modules.
    *{$caller .'::import'} = \&_module_import;

    # And their own Builder convenience function
    *{$caller .'::Builder'} = sub () {
        return Test::Builder2->singleton;
    };
}


sub _module_import {
    my $class  = shift;
    my $caller = caller;

    my @input = @_;
    push @input, 1 if defined $input[0] and $input[0] eq 'no_plan';

    if( @input ) {
        $class->Builder->stream_start;
        $class->Builder->set_plan(@input);
    }

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

        my $result = Builder->ok($have eq $want, $name);
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
3. The C<< Builder >> object is available inside your $code which is just
   a shortcut for C<< Test::Builder2->singleton >>.

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
        $caller->Builder->assert_start();

        # Guard against an assert dying...
        my @args = @_;
        my($result, $error) = $CLASS->try( sub {
            return $test_code->(@args);
        });

        # ...because we have to pop the assert stack on matter what
        $caller->Builder->assert_end($result);

        # ...then rethrow the error
        die $error if $error;

        return $result;
    };
CODE

    die $@ unless $code;

    _install($caller, $name, $code);

    return $code;
}


# End the stream if it has been started (or if someone else started it)
END {
    my $builder = eval { Test::Builder2->singleton; };

    _do_ending($builder) if $builder;
}


sub _do_ending {
    my $builder = shift;

    my $history = $builder->history;

    # Really we should be asking history, but history doesn't have that
    # functionality yet
    $builder->stream_end if $history->stream_depth;
}

1;
