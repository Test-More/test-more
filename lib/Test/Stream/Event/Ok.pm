package Test::Stream::Event::Ok;
use strict;
use warnings;

use Scalar::Util qw/blessed/;
use Carp qw/confess/;

use Test::Stream::Formatter::TAP qw/OUT_STD OUT_TODO OUT_ERR/;

use Test::Stream::Event::Diag();

use base 'Test::Stream::Event';
use Test::Stream::HashBase accessors => [qw/pass effective_pass name diag allow_bad_name/];

sub init {
    my $self = shift;

    confess("No debug info provided!") unless $self->{+DEBUG};

    # Do not store objects here, only true or false
    $self->{+PASS} = $self->{+PASS} ? 1 : 0;

    $self->{+EFFECTIVE_PASS} = $self->{+PASS} || $self->{+DEBUG}->no_fail || 0;

    return if $self->{+ALLOW_BAD_NAME};
    my $name = $self->{+NAME} || return;
    return unless index($name, '#') != -1 || index($name, "\n") != -1;
    $self->debug->throw("'$name' is not a valid name, names must not contain '#' or newlines.")
}

sub default_diag {
    my $self = shift;

    return if $self->{+PASS};

    my $name  = $self->{+NAME};
    my $dbg   = $self->{+DEBUG};
    my $pass  = $self->{+PASS};
    my $todo  = defined $dbg->todo;

    my $msg = $todo ? "Failed (TODO)" : "Failed";
    my $prefix = $ENV{HARNESS_ACTIVE} && !$ENV{HARNESS_IS_VERBOSE} ? "\n" : "";

    my $trace = $dbg->trace;

    if (defined $name) {
        $msg = qq[$prefix$msg test '$name'\n$trace.];
    }
    else {
        $msg = qq[$prefix$msg test $trace.];
    }

    return $msg;
}

sub update_state { $_[1]->bump($_[0]->{+EFFECTIVE_PASS}) }

sub causes_fail { !$_[0]->{+EFFECTIVE_PASS} }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Event::Ok - Ok event type

=head1 DESCRIPTION

Ok events are generated whenever you run a test that produces a result.
Examples are C<ok()>, and C<is()>.

=head1 SYNOPSIS

    use Test::Stream::Context qw/context/;
    use Test::Stream::Event::Ok;

    my $ctx = context();
    my $event = $ctx->ok($bool, $name, \@diag);

or:

    my $ctx   = debug();
    my $event = $ctx->send_event(
        'Ok',
        pass => $bool,
        name => $name,
        diag => \@diag
    );

=head1 ACCESSORS

=over 4

=item $rb = $e->pass

The original true/false value of whatever was passed into the event (but
reduced down to 1 or 0).

=item $name = $e->name

Name of the test.

=item $diag = $e->diag

An arrayref full of diagnostics strings to print in the event of a failure.

B<Note:> This does not have anything by default, the C<default_diag()> method
can be used to generate the basic diagnostics message which you may push into
this arrayref.

=item $b = $e->effective_pass

This is the true/false value of the test after TODO, SKIP, and similar
modifiers are taken into account.

=item $b = $e->allow_bad_name

This relaxes the test name checks such that they allow characters that can
confuse a TAP parser.

=back

=head1 METHODS

=over 4

=item $string = $e->default_diag()

This generates the default diagnostics string:

    # Failed test 'Some Test'
    # at t/foo.t line 42.

=item @sets = $e->to_tap()

=item @sets = $e->to_tap($num)

B<***DEPRECATED***> This will be removed in the near future. See
L<Test::Stream::Formatter::TAP> for TAP production.

Generate the tap stream for this object. C<@sets> containes 1 or more arrayrefs
that identify the IO handle to use, and the string that should be sent to it.

IO Handle identifiers are set to the value of the L<Test::Stream::Formatter::TAP> C<OUT_*>
constants.

Example:

    @sets = (
        [OUT_STD() => 'not ok 1 - foo'],
        [OUT_ERR() => '# Test 1 Failed ...' ],
        ...
    );

=back

=head1 SOURCE

The source code repository for Test::Stream can be found at
F<http://github.com/Test-More/Test-Stream/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
