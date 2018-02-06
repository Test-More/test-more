package Test2::Manual::Anatomy::Context;
use strict;
use warnings;

our $VERSION = '0.000099';

1;

__END__

=head1 NAME

Test2::Manual::Anatomy::Context - Internals documentation for the Context
objects.

=head1 DESCRIPTION

This document explains how the L<Test2::API::Context> object works.

=head1 WHAT IS THE CONTEXT OBJECT?

The context object is one of the key components of Test2, and makes many
features possible that would otherwise be impossible. Evey test tool starts by
getting a context, and ends by releasing the context. A test tool does all its
work between getting and releasing the context. The context instance is the
primary interface for sending events to the Test2 stack. Finally the context
system is responsible for tracking what file and line number a tool operates
on, which is critical for debugging.

=head1 TODO

The rest of this doc has yet to be written.

=head1 SEE ALSO

L<Test2::Manual> - Primary index of the manual.

=head1 SOURCE

The source code repository for Test2-Manual can be found at
F<https://github.com/Test-More/Test2-Suite/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2017 Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
