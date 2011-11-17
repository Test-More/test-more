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

A demonstration of writing an EventHandler using C<accept_result> to
kill the test when an assert fails.

=head1 CAVEATS

While this will work with Test::Builder based modules (for example,
Test::More still uses Test::Builder) it will kill the test B<before>
any diagnostics are output.  Test::Builder2 based modules (such as
Test::Simple) do not have this problem.

=head1 SEE ALSO

L<Test::Builder2::EventHandler>

=cut

{
    package TB2::DieOnFail::Watcher;

    use Test::Builder2::Mouse;
    with 'Test::Builder2::EventHandler';

    sub accept_result {
        my $self   = shift;
        my $result = shift;

        return if $result;

        my $name = $result->name;
        die sprintf "Test%s failed, aborting.\n", defined $name ? " $name" : "";
    };
}

require Test::Builder2;
Test::Builder2->default->test_state->add_late_watchers( TB2::DieOnFail::Watcher->new );

1;
