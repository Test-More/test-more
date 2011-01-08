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

A demonstration of writing an EventWatcher using C<accept_result> to
drop you into the debugger when an assert fails.

=head1 CAVEATS

You have to run the test in the debugger.

You'll wind up at the end of the DebugOnFail assert_end wrapper.  You
can hit 'r' a few times to get back to your test, or examine the
$result object.  It would be nice if it could start the debugger just
after the assert was called instead.

=head1 SEE ALSO

L<Test::Builder2::EventWatcher>

=cut


{
    package TB2::DebugOnFail;

    use Test::Builder2::Mouse;
    with 'Test::Builder2::EventWatcher';

    sub accept_event {}

    sub accept_result {
        my $self   = shift;
        my $result = shift;

        return if $result;

        $DB::single = 1;
        return;  # welcome to the debugger.  $result contains the result
    };
}

# Yep, this is less than ideal.
require Test::Builder2;
Test::Builder2->singleton->event_coordinator->add_late_watchers( TB2::DebugOnFail->new );

1;
