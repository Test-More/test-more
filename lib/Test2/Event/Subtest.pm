package Test2::Event::Subtest;
use strict;
use warnings;

use base 'Test2::Event::Ok';
use Test2::Util::HashBase qw{subevents buffered};

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{+SUBEVENTS} ||= [];
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Event::Subtest - Event for subtest types

=head1 EXPERIMENTAL RELEASE

This is an experimental release. Using this right now is not recommended.

=head1 DESCRIPTION

This class represents a subtest. This class is a subclass of
L<Test2::Event::Ok>.

=head1 ACCESSORS

This class inherits from L<Test2::Event::Ok>.

=over 4

=item $arrayref = $e->subevents

Returns the arrayref containing all the events from the subtest

=item $bool = $e->buffered

True if the subtest is buffered, that is all subevents render at once. If this
is false it means all subevents render as they are produced.

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
