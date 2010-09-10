package TB2::DieOnFail;

use strict;
use warnings;


=head1 NAME

TB2::DieOnFail - Stop the test on the first failure

=head1 SYNOPSIS

    use TB2::DieOnFail;
    use Test::Simple tests => 3;

    ok(1);
    ok(0);  # here it will stop
    ok(1);

=head1 DESCRIPTION

A demonstration of using a method modifier on the assert_end action to
kill the test when an assert fails.

=cut

{
    package TB2::DieOnFail::Role;

    use Carp;
    use Test::Builder2::Mouse::Role;

    after assert_end => sub {
        my $self   = shift;
        my $result = shift;

        return if $result;

        return if $self->top_stack->in_assert;

        die "Assert failed.  Test stopped.\n";
    };
}

TB2::DieOnFail::Role->meta->apply( Test::Builder2->singleton );

1;
