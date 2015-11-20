package Test::Stream::Compare::Wildcard;
use strict;
use warnings;

use base 'Test::Stream::Compare';
use Test::Stream::HashBase accessors => [qw/expect/];

use Carp qw/croak/;

sub init {
    my $self = shift;
    croak "'expect' is a require attribute"
        unless exists $self->{+EXPECT};

    $self->SUPER::init();
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Compare::Wildcard - Placeholder check.

=head1 DESCRIPTION

This module is used as a temporary placeholder for values that still need to be
converted. This is necessary to carry-forward filename and line number which
would be lost in the conversion otherwise.

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

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
