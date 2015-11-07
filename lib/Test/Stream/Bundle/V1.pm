package Test::Stream::Bundle::V1;
use strict;
use warnings;

use Test::Stream::Bundle;

sub plugins {
    return (
        sub { strict->import(); warnings->import() },
        qw{
            IPC
            TAP
            ExitSummary
            Core
            Context
            Exception
            Warnings
            Compare
            Mock
            UTF8
        },
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Bundle::V1 - Preferred bundle used by Test::Stream author.

=head1 DESCRIPTION

This bundle is the one used most in Test::Stream's own test suite. This bundle
ties together the most commonly used tools.

=head1 SYNOPSIS

B<Note:> On ly the most critical functions are listed here. Please see
individual plugins for their functions.

    use Test::Stream '-V1';

    ok(1, "This is a pass");
    ok(0, "This is a fail");

    is("x", "x", "These strings are the same");
    is($A, $B, "These 2 structures match exactly");

    like('x', qr/x/, "This string matches this pattern");
    like($A, $B, "These structures match where it counts");

    done_testing;

=head1 INCLUDED TOOLS

=over 4

=item strict

'strict' is turned on for you.

=item warnings

'warnings' are turned on for you.

=item Compare

This provides C<is()> and C<like()>. This can also provide other tools to make
deep comparisons easier, but they are not imported by default.

See L<Test::Stream::Plugin::Compare> for more details.

=item Context

This provides the C<context()> function which is useful in writing new tools,
or wrapping existing ones.

See L<Test::Stream::Plugin::Context> for more details.

=item Core

This provides essential tools such as C<ok()>, C<done_testing()>, as well as
others.

See L<Test::Stream::Plugin::Core> for more details.

=item Exception

This provides tools to help you intercept or check for the absence of
exceptions. This is very similar to L<Test::Fatal>, in fact L<Test::Fatal> is
probably better. If you can, use L<Test::Fatal>, if you cannot then this may
suffice. The functions exported do not conflict with the ones exported by
L<Test::Fatal> so both can be loaded together.

See L<Test::Stream::Plugin::Exception> for more details.

=item ExitSummary

This provides extra diagnostics at the end of failing tests.

See L<Test::Stream::Plugin::ExitSummary> for more details.

=item IPC

This loads IPC support so that threading and forking just work.

See L<Test::Stream::Plugin::IPC> for more details.

=item Mock

This provides the C<mock()> and C<mocked()> functions which can be used to do
nearly any kind of mocking you might need.

See L<Test::Stream::Plugin::Mock> for more details.

=item TAP

This sets TAP to be the default output format.

See L<Test::Stream::Plugin::TAP> for more details.

=item UTF8

This module turns on the utf8 pragma for your test file, it also sets STDERR,
STDOUT and the formatter output handles to use utf8.

See L<Test::Stream::Plugin::UTF8> for more details.

=item Warnings

This plugin provides tools to help intercept warnings.

See L<Test::Stream::Plugin::Warnings> for more details.

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

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
