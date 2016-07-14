package Test2::Manual::Testing;
use strict;
use warnings;

1;

__END__

=head1 NAME

Test2::Manual::Testing - Hub for documentation about writing tests with Test2.

=head1 DESCRIPTION

This document outlines all the tutorials and POD that cover writing tests. This
section does not cover any Test2 internals, nor does it cover how to write new
tools, for that see L<Test2::Manual::Tooling>.

=head1 NAMESPACE MAP

When writing tests there are a couple namespaces to focus on:

=over 4

=item Test2::Tools::*

This is where toolsets can be found. A toolset exports functions that help you
make assertions about your code. Toolsets will only export functions, they
should not ever have extra/global effects.

=item Test2::Plugins::*

This is where plugins live. Plugins should not export anything, but instead
will introduce or alter behaviors for Test2 in general. These behaviors may be
lexically scoped, or they may be global.

=item Test2::Bundle::*

Bundles combine toolsets and plugins together to reduce your boilerplate. First
time test writers are encouraged to start with the L<Test2::Bundle::Extended>
bundle. If you find yourself loading several plugins and toolsets over and over
again you could benefit from writing your own bundle.

=item Test2::Require::*

This namespace contains modules that will cause a test to skip if specific
conditions are not met. Use this if you have tests that oly run on specific
perl versions, or require external libraries that may not always be available.

=back

=head1 TUTORIALS

=head2 SIMPLE/INTRODUCTION TUTORIAL

=head2 ADVANCED PLANNING

=head2 TODO TESTS

=head2 SUBTESTS

=head2 COMPARISONS

=head3 SIMPLE COMPARISONS

* Include refs

=head3 ADVANCED COMPARISONS

* Deep strucutres, DSL

=head2 TESTING EXPORTERS

=head2 TESTING CLASSES

=head2 TRAPPING

=head3 TRAPPING EXCEPTIONS

=head3 TRAPPING WARNINGS

=head2 DEFERRED TESTING

=head2 MANAGING ENCODINGS

=head2 AUTO-ABORT ON FAILURE

=head2 CONTROLLING RANDOM BEHAVIOR

=head2 WRITING YOUR OWN BUNDLE

=head2 TESTING YOUR TEST TOOLS

* Also covered in the Tooling section.

=head1 TOOLSET DOCUMENTATION

=head1 PLUGIN DOCUMENTATION

=head1 BUNDLE DOCUMENTATION

=head1 REQUIRE DOCUMENTAION

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

Copyright 2016 Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
