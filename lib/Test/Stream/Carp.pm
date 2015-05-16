package Test::Stream::Carp;
use strict;
use warnings;

use Test::Stream::Exporter;

export croak   => sub { require Carp; goto &Carp::croak };
export confess => sub { require Carp; goto &Carp::confess };
export cluck   => sub { require Carp; goto &Carp::cluck };
export carp    => sub { require Carp; goto &Carp::carp };

no Test::Stream::Exporter;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Carp - Delayed Carp loader.

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

Use this package instead of L<Carp> to avoid loading L<Carp> until absolutely
necessary. This is used instead of Carp in L<Test::Stream> in order to avoid
loading modules that packages you test may need to load themselves.

=head1 SUPPORTED EXPORTS

See L<Carp> for details on each of these functions.

=over 4

=item croak

=item confess

=item cluck

=item carp

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

=item Kent Fredric E<lt>kentnl@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
