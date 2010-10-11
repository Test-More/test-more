package TB2::DebugOnFail;

use strict;
use warnings;


=head1 NAME

TB2::DebugOnFail - Enter the debugger on failure

=head1 SYNOPSIS

    use TB2::DebugOnFail;
    use Test::Simple tests => 3;

    ok(1);
    ok(0);  # if run with -d you will enter the debugger
    ok(1);

=head1 DESCRIPTION

A demonstration of using a method modifier on the assert_end action to
drop you into the debugger when an assert fails.

=head1 CAVEATS

You have to run the test in the debugger.

You'll wind up at the end of the DebugOnFail assert_end wrapper.  You
can hit 'r' a few times to get back to your test, or examine the
$result object.  It would be nice if it could start the debugger just
after the assert was called instead.

=cut


{
    package TB2::DebugOnFail::Role;

    use Test::Builder2::Mouse::Role;

    after assert_end => sub {
        my $self   = shift;
        my $result = shift;

        return if $result;

        return if $self->top_stack->in_assert;

        $DB::single = 1;
        return;  # welcome to the debugger.  $result contains the result
    };
}

require Test::Builder2;
TB2::DebugOnFail::Role->meta->apply( Test::Builder2->singleton );

1;
