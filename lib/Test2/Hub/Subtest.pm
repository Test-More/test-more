package Test2::Hub::Subtest;
use strict;
use warnings;

our $VERSION = '0.000038';

use base 'Test2::Hub';
use Test2::Util::HashBase qw/nested bailed_out exit_code manual_skip_all/;
use Test2::Util qw/get_tid/;

sub process {
    my $self = shift;
    my ($e) = @_;
    $e->set_nested($self->nested);
    $self->set_bailed_out($e) if $e->isa('Test2::Event::Bail');
    $self->SUPER::process($e);
}

sub send {
    my $self = shift;
    my ($e) = @_;

    my $out = $self->SUPER::send($e);

    return $out if $self->{+MANUAL_SKIP_ALL};
    return $out unless $e->isa('Test2::Event::Plan')
        && $e->directive eq 'SKIP'
        && ($e->trace->pid != $self->pid || $e->trace->tid != $self->tid);

    no warnings 'exiting';
    last T2_SUBTEST_WRAPPER;
}

sub terminate {
    my $self = shift;
    my ($code, $e) = @_;
    $self->set_exit_code($code);

    return if $self->{+MANUAL_SKIP_ALL};
    return if $e->isa('Test2::Event::Plan')
           && $e->directive eq 'SKIP'
           && ($e->trace->pid != $$ || $e->trace->tid != get_tid);

    no warnings 'exiting';
    last T2_SUBTEST_WRAPPER;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Hub::Subtest - Hub used by subtests

=head1 EXPERIMENTAL RELEASE

This is an experimental release. Using this right now is not recommended.

=head1 DESCRIPTION

Subtests make use of this hub to route events.

=head1 TOGGLES

=over 4

=item $bool = $hub->manual_skip_all

=item $hub->set_manual_skip_all($bool)

The default is false.

Normally a skip-all plan event will cause a subtest to stop executing. This is
accomplished via C<last LABEL> to a label inside the subtest code. Most of the
time this is perfectly fine. There are times however where this flow control
causes bad things to happen.

This toggle lets you turn off the abort logic for the hub. When this is toggled
to true B<you> are responsible for ensuring no additional events are generated.

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
