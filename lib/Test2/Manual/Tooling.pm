package Test2::Manual::Tooling;
use strict;
use warnings;

our $VERSION = '0.000092';

1;

__END__

=head1 NAME

Test2::Manual::Tooling - Manual page for tool authors.

=head1 DESCRIPTION

This section covers writing new tools, plugins, and other Test2 components.

=head1 TOOL TUTORIALS

=head2 FIRST TOOL

L<Test2::Manual::Tooling::FirstTool> - Introduction to writing tools by cloning
L<ok()>.

=head2 NESTING TOOLS

L<Test2::Manual::Tooling::Nesting> - How to call other tools from your tool.

=head2 TOOLS WITH SUBTESTS

L<Test2::Manual::Tooling::Subtest> - How write tools that make use of subtests.

=head2 TESTING YOUR TEST TOOLS

L<Test2::Manual::Tooling::Testing> - How to write tests for your test tools.

=head1 PLUGIN TUTORIALS

=head2 IMPLEMENTING SRAND

COMING SOON.

=head2 IMPLEMENTING DIE-ON-FAIL

COMING SOON.

=head2 TAKING ACTION AT THE END OF TESTING

COMING SOON.

=head2 TAKING ACTION JUST BEFORE EXIT

COMING SOON.

=head1 FORMATTER TUTORIALS

COMING SOON.

=head2 WRITING A SIMPLE JSON FORMATTER

COMING SOON.

=head1 CUSTOM EVENT TUTORIAL

COMING SOON.

=head1 WHERE TO FIND HOOKS AND APIS

=over 4

=item global API

L<Test2::API> is the global API. This is primarily used by plugins that provide
global behavior.

=item In hubs

L<Test2::Hub> is the base class for all hubs. This is where hooks for
manipulating events, or running things at the end of testing live.

=back

=head1 SEE ALSO

L<Test2::Manual> - Primary index of the manual.

=head1 SOURCE

The source code repository for Test2-Manual can be found at
F<http://github.com/Test-More/Test2-Manual/>.

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
