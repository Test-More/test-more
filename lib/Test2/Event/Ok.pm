package Test2::Event::Ok;
use strict;
use warnings;

use base 'Test2::Event';
use Test2::Util::HashBase qw{
    pass effective_pass name diag allow_bad_name todo diag_todo
};

sub init {
    my $self = shift;

    # Do not store objects here, only true or false
    $self->{+PASS} = $self->{+PASS} ? 1 : 0;

    $self->{+EFFECTIVE_PASS} = ($self->{+PASS} || defined($self->{+TODO})) ? 1 : 0;

    return if $self->{+ALLOW_BAD_NAME};
    my $name = $self->{+NAME} || return;
    return unless index($name, '#') != -1 || index($name, "\n") != -1;
    $self->trace->throw("'$name' is not a valid name, names must not contain '#' or newlines.")
}

sub default_diag {
    my $self = shift;

    return if $self->{+PASS};

    my $name  = $self->{+NAME};
    my $trace = $self->{+TRACE};
    my $pass  = $self->{+PASS};
    my $todo  = defined($self->{+TODO});

    my $msg = $todo ? "Failed (TODO)" : "Failed";
    my $prefix = $ENV{HARNESS_ACTIVE} && !$ENV{HARNESS_IS_VERBOSE} ? "\n" : "";

    my $debug = $trace ? $trace->debug : "[No trace info available]";

    if (defined $name) {
        $msg = qq[$prefix$msg test '$name'\n$debug.];
    }
    else {
        $msg = qq[$prefix$msg test $debug.];
    }

    return $msg;
}

sub increments_count { 1 };

sub causes_fail { !$_[0]->{+EFFECTIVE_PASS} }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Event::Ok - Ok event type

=head1 EXPERIMENTAL RELEASE

This is an experimental release. Using this right now is not recommended.

=head1 DESCRIPTION

Ok events are generated whenever you run a test that produces a result.
Examples are C<ok()>, and C<is()>.

=head1 SYNOPSIS

    use Test2::API qw/context/;
    use Test2::Event::Ok;

    my $ctx = context();
    my $event = $ctx->ok($bool, $name, \@diag);

or:

    my $ctx   = context();
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

=back

=head1 SOURCE

The source code repository for Test2 can be found at
F<http://github.com/Test-More/Test2/>.

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
