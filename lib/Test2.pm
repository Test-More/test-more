package Test2;
use strict;
use warnings;

our $VERSION = '0.000010';

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2 - Framework for writing test tools that all work together.

=head1 EXPERIMENTAL RELEASE

This is an experimental release. Using this right now is not recommended.

=head1 DESCRIPTION

Test2 is a new testing framework produced by forking L<Test::Builder>,
completely refactoring it, adding many new features and capabilities.

=head1 GETTING STARTED

If you are interested in writing tests using new tools then you should look at
B<NOT YET DETERMINED>.

If you are interested in writing new tools you should take a look at
L<Test2::API> first.

=head1 SEE ALSO

L<Test2::API> - Primary API functions.

L<Test2::Context> - Detailed documentation of the context object.

L<Test2::Global> - Interface to global state. This is where to look if you need
a tool to produce a global effect.

L<Test2::IPC> - The IPC system used for threading/fork support.

L<Test2::Formatter> - Formatters such as TAP live here.

L<Test2::Event> - Events live in this namespace.

L<Test2::Hub> - All events eventually funnel through a hub. Custom hubs are how
C<intercept()> and C<run_subtest()> are implemented.

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
