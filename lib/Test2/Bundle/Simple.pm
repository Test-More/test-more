package Test2::Bundle::Simple;
use strict;
use warnings;

our $VERSION = '0.000022';

use Test2::Plugin::ExitSummary;

use Test2::Tools::Basic qw/ok plan done_testing skip_all/;

our @EXPORT = qw/ok plan done_testing skip_all/;
use base 'Exporter';

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Bundle::Simple - Bundle that is ALMOST a drop-in replacement for
Test::Simple.

=head1 EXPERIMENTAL RELEASE

This is an experimental release. Using this right now is not recommended.

=head1 DESCRIPTION

This bundle is intended to be a (mostly) drop-in replacement for
L<Test::Simple>.

=head1 SYNOPSYS

    use Test2::Bundle::Simple;

    ok(1, "pass");

    done_testing;

=head1 PLUGINS

This loads L<Test2::Plugin::ExitSummary>.

=head1 TOOLS

These are all from L<Test2::Tools::Basic>.

=over 4

=item ok($bool, $name)

Run a test. If bool is true the test passes, if bool is false it fails.

=item plan($count)

Tell the system how many tests to expect.

=item skip_all($reason)

Tell the system to skip all the tests (this will exit the script)

=item done_testing();

Tell the system that all tests are complete. You can use this instead of
setting a plan.

=back

=head1 KEY DIFFERENCES FROM Test::Simple

=over 4

=item You cannot plan at import.

THIS WILL B<NOT> WORK:

    use Test2::Bundle::Simple tests => 5;

Instead you must plan in a seperate statement:

    use Test2::Bundle::Simple;
    plan 5;

=item You have 3 subs imported for use in planning

Use C<plan($count)>, C<skip_all($REASON)>, or C<done_testing()> for your
planning.

=back

=head1 SOURCE

The source code repository for Test2-Suite can be found at
F<http://github.com/Test-More/Test2-Suite/>.

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
