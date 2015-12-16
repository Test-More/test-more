package Test2::Hub::Subtest;
use strict;
use warnings;

use base 'Test2::Hub';
use Test2::Util::HashBase qw/nested bailed_out exit_code/;

sub process {
    my $self = shift;
    my ($e) = @_;
    $e->set_nested($self->nested);
    $self->set_bailed_out($e) if $e->isa('Test2::Event::Bail');
    $self->SUPER::process($e);
}

sub terminate {
    my $self = shift;
    my ($code) = @_;
    $self->set_exit_code($code);
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
