package Test2::EventFacet::Assert;
use strict;
use warnings;

our $VERSION = '1.302088';

BEGIN { require Test2::EventFacet; our @ISA = qw(Test2::EventFacet) }
use Test2::Util::HashBase qw{ -pass -no_debug };

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::EventFacet::Assert - Facet representing an assertion.

=head1 DESCRIPTION

The assertion facet is provided by any event representing an assertion that was
made.

=head1 FIELDS

=over 4

=item $string = $assert->{details}

=item $string = $assert->details()

Human readable description of the assertion.

=item $bool = $assert->{pass}

=item $bool = $assert->pass()

True if the assertion passed.

=item $bool = $assert->{no_debug}

=item $bool = $assert->no_debug()

Set this to true if you have provided custom diagnostics and do not want the
defaults to be displayed.

=back

=head1 SOURCE

The source code repository for Test2 can be found at
F<http://github.com/Test-More/test-more/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2016 Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
