package Test::Stream::Compare::Wildcard;
use strict;
use warnings;

use Test::Stream::Compare();
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/expect/],
);

use Carp qw/croak/;

sub init {
    my $self = shift;
    croak "'expect' is a require attribute"
        unless exists $self->{+EXPECT};
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Compare::Wildcard - Placeholder check.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

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
