package Test::Stream::Bundle::Classic;
use strict;
use warnings;

use Test::Stream::Bundle;

sub plugins {
    return (
        qw{
            IPC
            TAP
            ExitSummary
            Core
            Subtest
        },
        Classic => [qw/is is_deeply like unlike isnt/],
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Bundle::Classic - Bundle that emulates most of L<Test::More>. 

=head1 DESCRIPTION


=head1 SYNOPSIS

B<Note:> On ly the most critical functions are listed here. Please see
individual plugins for their functions.

    use Test::Stream '-Classic';

    ok(1, "This is a pass");
    ok(0, "This is a fail");

    is($foo, $bar, "These are the same using string comparison");

    like($foo, qr/x/, "This string matches this pattern");

    is_deeply({a => $foo}, {a => $foo}, "deep comparison");

    done_testing;

=head1 INCLUDED TOOLS

=over 4

=item Classic => ['is', 'isnt', like', 'unlike', 'is_deeply']

This provides the C<is()> and C<is_deeply()> functions. These versions of the
function behave much like the L<Test::Stream> implementations, but with more
diagnostics. These both use the C<eq> operator when comparing scalar values.

See L<Test::Stream::Plugin::Classic> for more details.

=item Compare => ['like']

This provides C<like()>. This can also provide other tools to make deep
comparisons easier, but they are not imported by default.

See L<Test::Stream::Plugin::Compare> for more details.

=item Core

This provides essential tools such as C<ok()>, C<done_testing()>, as well as
others.

See L<Test::Stream::Plugin::Core> for more details.

=item ExitSummary

This provides extra diagnostics at the end of failing tests.

See L<Test::Stream::Plugin::ExitSummary> for more details.

=item IPC

This loads IPC support so that threading and forking just work.

See L<Test::Stream::Plugin::IPC> for more details.

=item TAP

This sets TAP to be the default output format.

See L<Test::Stream::Plugin::TAP> for more details.

=item Subtest

This adds the C<subtest($name, sub { ... })> function. The output of this one
is a little different from L<Test::More> as it is buffered, that is doesn't gt
rendered until the subtest is done. This is important for concurrency support.

You can get the old style subtests this way:

    use Test::Stream -Classic, Subtest => ['streamed'];

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
